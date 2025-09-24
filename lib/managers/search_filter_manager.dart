import '../models/product.dart';

/// 集中管理商品搜尋與篩選邏輯，讓 UI 更輕量、易於測試
class SearchFilterManager {
  static const List<String> locationGroup = ['東京', '上海', '香港'];
  static const List<String> characterGroup = [
    'Duffy',
    'Gelatoni',
    'OluMel',
    'ShellieMay',
    'StellaLou',
    'CookieAnn',
    'LinaBell',
    '其他角色',
  ];
  static const List<String> typeGroup = ['娃娃', '站姿', '坐姿', '其他吊飾'];

  /// 切換篩選標籤，並處理互斥群組
  List<String> toggleFilter(List<String> selected, String label) {
    final result = List<String>.from(selected);
    void toggleInGroup(List<String> group, String label) {
      result.removeWhere((f) => group.contains(f) && f != label);
      if (result.contains(label)) {
        result.remove(label);
      } else {
        result.add(label);
      }
    }

    if (locationGroup.contains(label)) {
      toggleInGroup(locationGroup, label);
    } else if (characterGroup.contains(label)) {
      toggleInGroup(characterGroup, label);
    } else if (typeGroup.contains(label)) {
      toggleInGroup(typeGroup, label);
    } else {
      // 其他（如 有庫存）為單獨切換
      if (result.contains(label)) {
        result.remove(label);
      } else {
        result.add(label);
      }
    }
    return result;
  }

  /// 純文字搜尋（空字串回傳空清單，與既有 UI 行為一致）
  List<Product> search(List<Product> products, String query) {
    final q = query.trim();
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    final matches = products.where((p) {
      final name = p.name.toLowerCase();
      final barcode = p.barcode.toLowerCase();
      return name.contains(lower) || barcode.contains(lower);
    }).toList();
    matches.sort(compareForSearchSort);
    return matches;
  }

  /// 套用篩選條件，可搭配文字搜尋（多關鍵字以空白切分，任一命中即通過）
  List<Product> filter(List<Product> products, List<String> selectedFilters,
      {String searchQuery = ''}) {
    final terms = searchQuery
        .toLowerCase()
        .split(' ')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    final filtered = products.where((p) {
      final name = p.name.toLowerCase();

      // 先處理文字搜尋（任一 term 命中名稱或條碼即可）
      if (terms.isNotEmpty) {
        final hit = terms.any((t) => name.contains(t) || p.barcode.contains(t));
        if (!hit) return false;
      }

      // 套用每個篩選條件（全部需滿足）
      for (final f in selectedFilters) {
        switch (f) {
          case '東京':
            if (!name.contains('東京disney限定') &&
                !name.contains('東京迪士尼限定') &&
                !name.contains('東京disney') &&
                !name.contains('東京迪士尼') &&
                !name.contains('tokyo')) {
              return false;
            }
            break;
          case '上海':
            if (!name.contains('上海disney限定') &&
                !name.contains('上海迪士尼限定') &&
                !name.contains('上海disney') &&
                !name.contains('上海迪士尼') &&
                !name.contains('shanghai')) {
              return false;
            }
            break;
          case '香港':
            final matchesHongKong =
                name.contains('香港disney限定') ||
                    name.contains('香港迪士尼限定') ||
                    name.contains('香港disney') ||
                    name.contains('香港迪士尼') ||
                    name.contains('hongkong') ||
                    name.contains('hk');
            if (!matchesHongKong) return false;
            break;
          case 'Duffy':
            if (!name.contains('duffy')) return false;
            break;
          case 'Gelatoni':
            if (!name.contains('gelatoni')) return false;
            break;
          case 'OluMel':
            if (!name.contains('olumel')) return false;
            break;
          case 'ShellieMay':
            if (!name.contains('shelliemay')) return false;
            break;
          case 'StellaLou':
            if (!name.contains('stellalou')) return false;
            break;
          case 'CookieAnn':
            if (!name.contains('cookieann')) return false;
            break;
          case 'LinaBell':
            if (!name.contains('linabell')) return false;
            break;
          case '其他角色':
            final isKnown = name.contains('duffy') ||
                name.contains('gelatoni') ||
                name.contains('olumel') ||
                name.contains('shelliemay') ||
                name.contains('stellalou') ||
                name.contains('cookieann') ||
                name.contains('linabell');
            if (isKnown) return false;
            break;
          case '娃娃':
            if (!name.contains('娃娃')) return false;
            break;
          case '站姿':
            if (!name.contains('站姿')) return false;
            break;
          case '坐姿':
            if (!name.contains('坐姿')) return false;
            break;
          case '其他吊飾':
            if (!name.contains('吊飾')) return false;
            if (name.contains('站姿') || name.contains('坐姿')) return false;
            break;
          case '有庫存':
            if (p.stock <= 0) return false;
            break;
        }
      }
      return true;
    }).toList();

    filtered.sort(compareForSearchSort);
    return filtered;
  }

  /// 搜尋/篩選的共同排序規則
  static int compareForSearchSort(Product a, Product b) {
    // 特殊商品永遠在最前
    if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
    if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

    // 兩者皆為特殊商品：預購在折扣前
    if (a.isSpecialProduct && b.isSpecialProduct) {
      if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
      if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
      return 0;
    }

    // 其他依名稱排序
    return a.name.compareTo(b.name);
  }
}
 
