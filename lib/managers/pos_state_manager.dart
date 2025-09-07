import 'package:flutter/foundation.dart';

/// POS 系統的狀態管理器
/// 負責管理全域狀態和狀態變更通知
class PosStateManager extends ChangeNotifier {
  static final PosStateManager _instance = PosStateManager._internal();
  factory PosStateManager() => _instance;
  PosStateManager._internal();

  // 載入狀態
  bool _isLoading = false;
  String _loadingMessage = '';

  // 掃描狀態
  bool _isScannerActive = false;

  // 搜尋狀態
  String _searchText = '';
  
  // 錯誤狀態
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  String get loadingMessage => _loadingMessage;
  bool get isScannerActive => _isScannerActive;
  String get searchText => _searchText;
  String? get errorMessage => _errorMessage;

  /// 設定載入狀態
  void setLoading(bool loading, {String message = ''}) {
    if (_isLoading != loading || _loadingMessage != message) {
      _isLoading = loading;
      _loadingMessage = message;
      notifyListeners();
    }
  }

  /// 設定掃描器狀態
  void setScannerActive(bool active) {
    if (_isScannerActive != active) {
      _isScannerActive = active;
      notifyListeners();
    }
  }

  /// 設定搜尋文字
  void setSearchText(String text) {
    if (_searchText != text) {
      _searchText = text;
      notifyListeners();
    }
  }

  /// 設定錯誤訊息
  void setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }

  /// 清除錯誤訊息
  void clearError() {
    setError(null);
  }

  /// 重置所有狀態
  void reset() {
    _isLoading = false;
    _loadingMessage = '';
    _isScannerActive = false;
    _searchText = '';
    _errorMessage = null;
    notifyListeners();
  }
}
