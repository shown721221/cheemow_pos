import '../models/product.dart';

/// 搜尋和篩選管理器
/// 負責處理商品搜尋、篩選邏輯
class SearchFilterManager {
  // 篩選分組定義
  static const List<String> _locationFilters = ['東京', '上海', '香港'];
  static const List<String> _characterFilters = [
    'Duffy', 'Gelatoni', 'OluMel', 'ShellieMay', 
    'StellaLou', 'CookieAnn', 'LinaBell', '其他角色'
  ];
  static const List<String> _productTypeFilters = ['娃娃', '站姿', '坐姿', '其他吊飾'];
  
  // 角色中英文對照
  static const Map<String, List<String>> _characterKeywords = {
    'Duffy': ['Duffy', '達菲', '達飛'],
    'Gelatoni': ['Gelatoni', '畫家貓', '傑拉托尼'],
    'OluMel': ['OluMel', '奧樂美'],
    'ShellieMay': ['ShellieMay', '雪莉梅', '雪莉美'],
    'StellaLou': ['StellaLou', '史黛拉', '史黛拉兔'],
    'CookieAnn': ['CookieAnn', '曲奇安', '餅乾狗'],
    'LinaBell': ['LinaBell', '玲娜貝兒', '狐狸'],
    '其他角色': ['其他', 'other'],
  };

  List<String> _selectedFilters = [];
  String _currentSearchQuery = '';

  // Getters
  List<String> get selectedFilters => List.unmodifiable(_selectedFilters);
  String get currentSearchQuery => _currentSearchQuery;
  bool get hasActiveFilters => _selectedFilters.isNotEmpty || _currentSearchQuery.isNotEmpty;

  /// 設置搜尋查詢
  void setSearchQuery(String query) {
    _currentSearchQuery = query.trim();
  }

  /// 切換篩選條件
  void toggleFilter(String filter) {
    if (_selectedFilters.contains(filter)) {
      _selectedFilters.remove(filter);
    } else {
      // 處理互斥邏輯
      _handleMutualExclusiveSelection(filter);
      _selectedFilters.add(filter);
    }
  }

  /// 處理互斥群組選擇
  void _handleMutualExclusiveSelection(String selectedFilter) {
    // 檢查是否屬於互斥群組，如果是則移除同群組的其他選項
    if (_locationFilters.contains(selectedFilter)) {
      _selectedFilters.removeWhere((filter) => _locationFilters.contains(filter));
    } else if (_characterFilters.contains(selectedFilter)) {
      _selectedFilters.removeWhere((filter) => _characterFilters.contains(filter));
    } else if (_productTypeFilters.contains(selectedFilter)) {
      _selectedFilters.removeWhere((filter) => _productTypeFilters.contains(filter));
    }
  }

  /// 清除所有篩選條件
  void clearAllFilters() {
    _selectedFilters.clear();
    _currentSearchQuery = '';
  }

  /// 執行搜尋和篩選
  List<Product> searchAndFilter(List<Product> allProducts) {
    List<Product> results = List.from(allProducts);

    // 先執行文字搜尋
    if (_currentSearchQuery.isNotEmpty) {
      results = _performTextSearch(results, _currentSearchQuery);
    }

    // 再執行篩選
    if (_selectedFilters.isNotEmpty) {
      results = _applyFilters(results, _selectedFilters);
    }

    return results;
  }

  /// 執行文字搜尋
  List<Product> _performTextSearch(List<Product> products, String query) {
    final queryLower = query.toLowerCase();
    
    return products.where((product) {
      final nameLower = product.name.toLowerCase();
      final barcodeLower = product.barcode.toLowerCase();
      
      return nameLower.contains(queryLower) || 
             barcodeLower.contains(queryLower);
    }).toList();
  }

  /// 應用篩選條件
  List<Product> _applyFilters(List<Product> products, List<String> filters) {
    return products.where((product) {
      return filters.every((filter) => _matchesFilter(product, filter));
    }).toList();
  }

  /// 檢查商品是否符合篩選條件
  bool _matchesFilter(Product product, String filter) {
    final productName = product.name.toLowerCase();

    switch (filter) {
      // 地區篩選
      case '東京':
        return productName.contains('東京') || productName.contains('tokyo');
      case '上海':
        return productName.contains('上海') || productName.contains('shanghai');
      case '香港':
        return productName.contains('香港') || productName.contains('hong kong');

      // 角色篩選
      case 'Duffy':
      case 'Gelatoni':
      case 'OluMel':
      case 'ShellieMay':
      case 'StellaLou':
      case 'CookieAnn':
      case 'LinaBell':
      case '其他角色':
        return _matchesCharacter(productName, filter);

      // 商品類型篩選
      case '娃娃':
        return productName.contains('娃娃') || productName.contains('doll');
      case '站姿':
        return productName.contains('站姿') || productName.contains('standing');
      case '坐姿':
        return productName.contains('坐姿') || productName.contains('sitting');
      case '其他吊飾':
        return productName.contains('吊飾') && 
               !productName.contains('站姿') && 
               !productName.contains('坐姿');

      // 特殊篩選
      case '有庫存':
        return product.stock > 0;

      default:
        return true;
    }
  }

  /// 檢查角色篩選匹配
  bool _matchesCharacter(String productName, String characterFilter) {
    final keywords = _characterKeywords[characterFilter] ?? [characterFilter];
    
    return keywords.any((keyword) => 
      productName.contains(keyword.toLowerCase())
    );
  }

  /// 獲取所有可用的篩選選項
  static Map<String, List<String>> getAllFilterOptions() {
    return {
      '地區': _locationFilters,
      '角色': _characterFilters,
      '類型': _productTypeFilters,
      '其他': ['有庫存'],
    };
  }

  /// 獲取篩選結果統計
  Map<String, int> getFilterStats(List<Product> allProducts) {
    final stats = <String, int>{};
    
    // 計算各篩選條件的商品數量
    for (final category in getAllFilterOptions().entries) {
      for (final filter in category.value) {
        final count = allProducts.where((product) => 
          _matchesFilter(product, filter)
        ).length;
        stats[filter] = count;
      }
    }
    
    return stats;
  }
}
