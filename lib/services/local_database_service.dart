import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/product.dart';

/// 本地資料庫服務（使用 SharedPreferences）
class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static LocalDatabaseService get instance =>
      _instance ??= LocalDatabaseService._();

  LocalDatabaseService._();

  SharedPreferences? _prefs;

  /// 初始化本地資料庫
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // 如果是第一次啟動，建立範例商品資料
    if (_prefs != null && !_prefs!.containsKey('products_initialized')) {
      await _createSampleProducts();
      await _prefs!.setBool('products_initialized', true);
    }
  }

  /// 建立範例商品資料
  Future<void> _createSampleProducts() async {
    final sampleProducts = [
      Product(
        id: '1',
        barcode: '19920203',
        name: '預約奇妙',
        price: 0,
        category: '特殊商品',
        stock: 99,
      ),
      Product(
        id: '2',
        barcode: '88888888',
        name: '祝您有奇妙的一天',
        price: 0,
        category: '特殊商品',
        stock: 99,
      ),
    ];

    await saveProducts(sampleProducts);
  }

  /// 確保特殊商品存在
  Future<void> ensureSpecialProducts() async {
    final products = await getProducts();
    final updatedProducts = List<Product>.from(products);
    bool needsUpdate = false;

    // 檢查預約商品是否存在
    final hasPreOrder = products.any((p) => p.barcode == '19920203');
    if (!hasPreOrder) {
      final preOrderProduct = Product(
        id: 'special_001',
        barcode: '19920203',
        name: '預約奇妙',
        price: 0,
        category: '特殊商品',
        stock: 99,
      );
      updatedProducts.add(preOrderProduct);
      needsUpdate = true;
    }

    // 檢查折扣商品是否存在
    final hasDiscount = products.any((p) => p.barcode == '88888888');
    if (!hasDiscount) {
      final discountProduct = Product(
        id: 'special_002',
        barcode: '88888888',
        name: '祝您有奇妙的一天',
        price: 0,
        category: '特殊商品',
        stock: 99,
      );
      updatedProducts.add(discountProduct);
      needsUpdate = true;
    }

    if (needsUpdate) {
      await saveProducts(updatedProducts);
    }
  }

  /// 儲存商品清單
  Future<void> saveProducts(List<Product> products) async {
    if (_prefs == null) return;
    final productsJson = products.map((p) => p.toJson()).toList();
    await _prefs!.setString('products', jsonEncode(productsJson));
  }

  /// 合併匯入的商品（用於CSV匯入）
  /// 相同ID的商品會被更新，新ID的商品會被新增
  Future<void> mergeImportedProducts(List<Product> importedProducts) async {
    final existingProducts = await getProducts();
    final Map<String, Product> productMap = {};

    // 將現有商品加入Map（以ID為key）
    for (final product in existingProducts) {
      productMap[product.id] = product;
    }

    // 合併或新增匯入的商品
    for (final importedProduct in importedProducts) {
      productMap[importedProduct.id] = importedProduct; // 相同ID會覆蓋
    }

    // 儲存合併後的商品列表
    final mergedProducts = productMap.values.toList();
    await saveProducts(mergedProducts);
  }

  /// 取得所有商品
  Future<List<Product>> getProducts() async {
    if (_prefs == null) return [];
    final productsString = _prefs!.getString('products');
    if (productsString == null) return [];

    final productsList = jsonDecode(productsString) as List;
    return productsList.map((json) => Product.fromJson(json)).toList();
  }

  /// 依條碼查詢商品
  Future<Product?> getProductByBarcode(String barcode) async {
    final products = await getProducts();
    try {
      return products.firstWhere((product) => product.barcode == barcode);
    } catch (e) {
      return null; // 找不到商品
    }
  }

  /// 更新商品庫存
  Future<void> updateProductStock(String productId, int newStock) async {
    final products = await getProducts();
    final productIndex = products.indexWhere((p) => p.id == productId);

    if (productIndex != -1) {
      // 建立新的商品物件（因為 Product 是 immutable）
      final updatedProduct = Product(
        id: products[productIndex].id,
        barcode: products[productIndex].barcode,
        name: products[productIndex].name,
        price: products[productIndex].price,
        category: products[productIndex].category,
        stock: newStock,
        isActive: products[productIndex].isActive,
      );

      products[productIndex] = updatedProduct;
      await saveProducts(products);
    }
  }
}
