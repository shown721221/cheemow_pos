import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/product.dart';

/// 專責 Product CRUD 的儲存層，與特殊商品補強/匯入流程分離。
class ProductRepository {
  ProductRepository._();
  static final instance = ProductRepository._();

  SharedPreferences? _prefs;
  List<Product>? _cachedProducts;
  Map<String, Product>? _barcodeIndex;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Product>> getAll() async {
    if (_prefs == null) return [];
    final raw = _prefs!.getString('products');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Product.fromJson(e)).toList();
  }

  Future<void> saveAll(List<Product> products) async {
    if (_prefs == null) return;
    final data = products.map((e) => e.toJson()).toList();
    await _prefs!.setString('products', jsonEncode(data));
    // 清除快取，下次存取時重建索引
    _invalidateCache();
  }

  Future<Product?> getByBarcode(String barcode) async {
    // 優化：使用快取索引進行 O(1) 查詢
    if (_barcodeIndex == null) {
      await _buildIndex();
    }
    return _barcodeIndex![barcode];
  }

  Future<void> updateStock(String id, int newStock) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = all[idx];
    all[idx] = Product(
      id: p.id,
      barcode: p.barcode,
      name: p.name,
      price: p.price,
      category: p.category,
      stock: newStock,
      isActive: p.isActive,
      lastCheckoutTime: p.lastCheckoutTime,
    );
    await saveAll(all);
  }

  /// 建立條碼索引快取，提升查詢效能
  Future<void> _buildIndex() async {
    _cachedProducts ??= await getAll();
    _barcodeIndex = {
      for (final p in _cachedProducts!) p.barcode: p
    };
  }

  /// 清除快取，在資料更新後呼叫
  void _invalidateCache() {
    _cachedProducts = null;
    _barcodeIndex = null;
  }
}
