import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../managers/search_filter_manager.dart';
import '../config/app_messages.dart';

/// 專責搜尋 + 篩選狀態/邏輯，減少 `PosMainScreen` State 體積
class PosSearchController extends ChangeNotifier {
  final SearchFilterManager _filterManager;
  final List<Product> _allProducts; // 來源商品（外部更新時需呼叫 refreshProducts）

  PosSearchController({
    required List<Product> products,
    SearchFilterManager? manager,
  }) : _allProducts = products,
       _filterManager = manager ?? SearchFilterManager();

  // 目前搜尋字串 / 結果 / 篩選條件
  // _typedQuery: 使用者實際輸入的文字（不會被篩選摘要覆蓋）
  // _query: 對外顯示用（若有 filters 會顯示摘要標籤）
  String _typedQuery = '';
  String _query = '';
  List<Product> _results = [];
  final List<String> _selectedFilters = [];
  
  // 防抖機制：避免快速輸入時的頻繁重建
  Timer? _debounceTimer;

  String get query => _query;
  List<Product> get results => _results;
  List<String> get selectedFilters => List.unmodifiable(_selectedFilters);
  bool get hasActiveFilters => _selectedFilters.isNotEmpty;
  bool get hasQuery => _query.isNotEmpty;

  /// 外部若商品列表有更新（例如重新載入），需刷新內部參考並重新套用條件
  void refreshProducts(List<Product> newProducts) {
    // 若傳入與內部來源是同一個 List 物件（identical），代表外部已就地修改內容，
    // 這時不能直接 clear 再 addAll (會因同一參考被清空後再加入自己 -> 仍為空)。
    if (identical(_allProducts, newProducts)) {
      _recompute();
      return;
    }
    _allProducts
      ..clear()
      ..addAll(newProducts);
    _recompute();
  }

  void updateQuery(String q) {
    final trimmed = q.trim();
    if (trimmed == _typedQuery) return;
    _typedQuery = trimmed;
    // 只有在沒有篩選條件時才直接顯示輸入文字
    if (_selectedFilters.isEmpty) {
      _query = _typedQuery;
    }
    _recompute();
  }

  void clearQuery() {
    if (_typedQuery.isEmpty && _query.isEmpty) return;
    _typedQuery = '';
    _query = '';
    _recompute();
  }

  void toggleFilter(String label) {
    final updated = _filterManager.toggleFilter(_selectedFilters, label);
    _selectedFilters
      ..clear()
      ..addAll(updated);
    _recompute();
  }

  void clearFilters({bool notify = true}) {
    if (_selectedFilters.isEmpty) return;
    _selectedFilters.clear();
    if (notify) _recompute();
  }

  /// 確保在某些 UI 操作（例如切換頁面）後，若有篩選條件但結果被外部清空，重新計算。
  void ensureResults() {
    if (_selectedFilters.isNotEmpty && _results.isEmpty) {
      _recompute();
    }
  }

  /// 重新計算結果並通知 listener（使用防抖機制）
  void _recompute() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performRecompute();
    });
  }

  /// 實際執行重新計算的邏輯
  void _performRecompute() {
    // 若同時有 filters，結果以 filter 為主（可包含 query 作為多詞條件）
    if (_selectedFilters.isNotEmpty) {
      _results = _filterManager.filter(
        _allProducts,
        _selectedFilters,
        searchQuery: _typedQuery,
      );
      // 顯示摘要（不改動 _typedQuery）
      _query = AppMessages.filterResultLabel(_selectedFilters);
    } else if (_typedQuery.isNotEmpty) {
      _results = _filterManager.search(_allProducts, _typedQuery);
      _query = _typedQuery; // 保持同步顯示使用者輸入
    } else {
      _results = [];
      // 沒有任何搜尋條件，顯示文字也應清空，避免殘留上一段摘要被視為 hasQuery
      if (_query.isNotEmpty) {
        _query = '';
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
