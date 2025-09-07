import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/local_database_service.dart';
import '../services/csv_import_service.dart';

/// 統一的產品管理器
/// 負責所有與產品相關的操作：搜尋、載入、匯入等
class ProductManager extends ChangeNotifier {
  static final ProductManager _instance = ProductManager._internal();
  factory ProductManager() => _instance;
  ProductManager._internal();

  final LocalDatabaseService _databaseService = LocalDatabaseService.instance;

  // 產品資料
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Map<String, Product> _productBarcodeMap = {};
  Map<String, Product> _productIdMap = {};

  // 載入狀態
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Product> get allProducts => List.unmodifiable(_allProducts);
  List<Product> get filteredProducts => List.unmodifiable(_filteredProducts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalProductCount => _allProducts.length;

  /// 初始化產品管理器
  Future<void> initialize() async {
    await loadProducts();
  }

  /// 載入所有產品
  Future<void> loadProducts() async {
    _setLoading(true);
    _clearError();

    try {
      _allProducts = await _databaseService.getProducts();
      _buildMaps();
      _filteredProducts = List.from(_allProducts);
      notifyListeners();
    } catch (e) {
      _setError('載入產品失敗: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// 建立快速查詢對應表
  void _buildMaps() {
    _productBarcodeMap.clear();
    _productIdMap.clear();
    
    for (Product product in _allProducts) {
      _productBarcodeMap[product.barcode] = product;
      _productIdMap[product.id] = product;
    }
  }

  /// 根據條碼查找產品
  Product? getProductByBarcode(String barcode) {
    return _productBarcodeMap[barcode];
  }

  /// 根據ID查找產品
  Product? getProductById(String id) {
    return _productIdMap[id];
  }

  /// 搜尋產品
  /// [query] 搜尋關鍵字
  /// [category] 分類篩選，null表示不篩選
  void searchProducts(String query, {String? category}) {
    if (query.isEmpty && category == null) {
      _filteredProducts = List.from(_allProducts);
    } else {
      _filteredProducts = _allProducts.where((product) {
        // 分類篩選
        if (category != null && product.category != category) {
          return false;
        }

        // 關鍵字搜尋
        if (query.isNotEmpty) {
          final searchLower = query.toLowerCase();
          return product.name.toLowerCase().contains(searchLower) ||
                 product.barcode.contains(query) ||
                 product.id.toLowerCase().contains(searchLower) ||
                 product.category.toLowerCase().contains(searchLower);
        }

        return true;
      }).toList();
    }

    notifyListeners();
  }

  /// 根據分類篩選產品
  void filterByCategory(String? category) {
    searchProducts('', category: category);
  }

  /// 清除篩選，顯示所有產品
  void clearFilter() {
    _filteredProducts = List.from(_allProducts);
    notifyListeners();
  }

  /// 獲取所有分類
  List<String> getAllCategories() {
    Set<String> categories = {};
    for (Product product in _allProducts) {
      if (product.category.isNotEmpty) {
        categories.add(product.category);
      }
    }
    return categories.toList()..sort();
  }

  /// 新增產品
  Future<bool> addProduct(Product product) async {
    _setLoading(true);
    _clearError();

    try {
      // 檢查重複
      if (_productBarcodeMap.containsKey(product.barcode)) {
        _setError('條碼已存在: ${product.barcode}');
        return false;
      }
      if (_productIdMap.containsKey(product.id)) {
        _setError('產品ID已存在: ${product.id}');
        return false;
      }

      // 將產品加入本地列表
      _allProducts.add(product);
      // 保存所有產品
      await _databaseService.saveProducts(_allProducts);
      _buildMaps();
      
      // 更新篩選結果
      _filteredProducts = List.from(_allProducts);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('新增產品失敗: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 更新產品
  Future<bool> updateProduct(Product product) async {
    _setLoading(true);
    _clearError();

    try {
      // 更新本地資料
      int index = _allProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _allProducts[index] = product;
        // 保存所有產品
        await _databaseService.saveProducts(_allProducts);
        _buildMaps();
        
        // 更新篩選結果
        index = _filteredProducts.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _filteredProducts[index] = product;
        }
        
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError('更新產品失敗: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 刪除產品
  Future<bool> deleteProduct(String productId) async {
    _setLoading(true);
    _clearError();

    try {
      // 更新本地資料
      _allProducts.removeWhere((p) => p.id == productId);
      _filteredProducts.removeWhere((p) => p.id == productId);
      // 保存所有產品
      await _databaseService.saveProducts(_allProducts);
      _buildMaps();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('刪除產品失敗: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 匯入 CSV 檔案
  Future<CsvImportResult> importFromCsv() async {
    _setLoading(true);
    _clearError();

    try {
      final result = await CsvImportService.importFromFile();
      
      if (result.success) {
        // 重新載入產品資料
        await loadProducts();
      }
      
      return result;
    } catch (e) {
      _setError('CSV 匯入失敗: ${e.toString()}');
      return CsvImportResult.error('CSV 匯入失敗: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// 更新產品庫存
  Future<bool> updateStock(String productId, int newStock) async {
    try {
      await _databaseService.updateProductStock(productId, newStock);
      
      // 更新本地資料
      Product? product = getProductById(productId);
      if (product != null) {
        Product updatedProduct = Product(
          id: product.id,
          barcode: product.barcode,
          name: product.name,
          price: product.price,
          category: product.category,
          stock: newStock,
          isActive: product.isActive,
        );

        int index = _allProducts.indexWhere((p) => p.id == productId);
        if (index != -1) {
          _allProducts[index] = updatedProduct;
          _buildMaps();
          
          // 更新篩選結果
          index = _filteredProducts.indexWhere((p) => p.id == productId);
          if (index != -1) {
            _filteredProducts[index] = updatedProduct;
          }
          
          notifyListeners();
        }
      }
      
      return true;
    } catch (e) {
      _setError('更新庫存失敗: ${e.toString()}');
      return false;
    }
  }

  /// 減少產品庫存（用於銷售）
  Future<bool> decreaseStock(String productId, int quantity) async {
    Product? product = getProductById(productId);
    if (product == null) return false;

    int newStock = product.stock - quantity;
    if (newStock < 0) {
      _setError('庫存不足');
      return false;
    }

    return await updateStock(productId, newStock);
  }

  /// 檢查產品是否有足夠庫存
  bool hasEnoughStock(String productId, int requiredQuantity) {
    Product? product = getProductById(productId);
    if (product == null) return false;
    return product.stock >= requiredQuantity;
  }

  /// 獲取低庫存產品（庫存 <= 5）
  List<Product> getLowStockProducts() {
    return _allProducts.where((product) => product.stock <= 5).toList();
  }

  /// 設定載入狀態
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 設定錯誤訊息
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// 清除錯誤訊息
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// 重新整理產品資料
  Future<void> refresh() async {
    await loadProducts();
  }
}
