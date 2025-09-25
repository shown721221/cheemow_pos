import '../models/product.dart';
import '../config/filter_rules.dart';

/// 集中管理商品搜尋與篩選邏輯，讓 UI 更輕量、易於測試
class SearchFilterManager {
  static const List<String> locationGroup = ['東京', '上海', '香港'];
  static const List<String> characterGroup = [
    'Duffy',
    'ShellieMay',
    'GelaToni',
    'StellaLou',
    'CookieAnn',
    'OluMel',
    'LinaBell',
    '其他角色',
  ];
  static const List<String> typeGroup = ['娃娃', '站姿吊飾', '坐姿吊飾', '其他吊飾'];
  static const List<String> multiSelectableTypes = ['站姿吊飾', '坐姿吊飾', '其他吊飾'];

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
      if (label == '娃娃') {
        // 選娃娃時移除所有 multiSelectableTypes
        result.removeWhere((f) => multiSelectableTypes.contains(f));
        if (result.contains(label)) {
          result.remove(label);
        } else {
          result.add(label);
        }
      } else if (multiSelectableTypes.contains(label)) {
        // 選多選吊飾類型時取消娃娃
        result.remove('娃娃');
        if (result.contains(label)) {
          result.remove(label);
        } else {
          result.add(label);
        }
      } else {
        toggleInGroup(typeGroup, label);
      }
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
  List<Product> filter(
    List<Product> products,
    List<String> selectedFilters, {
    String searchQuery = '',
  }) {
    final terms = searchQuery
        .toLowerCase()
        .split(' ')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    final selectedTypeSingles = <String>[]; // 僅會有 '娃娃' 或空
    final selectedTypeMulti = <String>[]; // 站姿吊飾 / 坐姿吊飾 / 其他吊飾 可多個

    for (final f in selectedFilters) {
      if (FilterRules.isTypeLabel(f)) {
        if (f == '娃娃') {
          selectedTypeSingles.add(f);
        } else if (multiSelectableTypes.contains(f)) {
          selectedTypeMulti.add(f);
        }
      }
    }

    final filtered = products.where((p) {
      final nameLower = p.name.toLowerCase();

      if (terms.isNotEmpty) {
        final hit = terms.any((t) => nameLower.contains(t) || p.barcode.contains(t));
        if (!hit) return false;
      }

      for (final f in selectedFilters) {
        if (FilterRules.isLocationLabel(f)) {
          if (!FilterRules.matchLocation(f, nameLower)) return false;
          continue;
        }
        if (FilterRules.isCharacterLabel(f)) {
          if (f == '其他角色') {
            if (FilterRules.isKnownCharacterName(nameLower)) return false;
          } else if (!FilterRules.matchCharacter(f, nameLower)) {
            return false;
          }
          continue;
        }
        if (f == '有庫存') {
          if (p.stock <= 0) return false;
          continue;
        }
      }

      // 類型邏輯：
      // 若選了 '娃娃' => 必須符合娃娃
      if (selectedTypeSingles.isNotEmpty) {
        if (!FilterRules.matchType('娃娃', nameLower)) return false;
        return true; // 選娃娃時忽略 multiSelectableTypes（互斥）
      }

      // 未選娃娃，若 multiSelectableTypes 有任一被選 => OR
      if (selectedTypeMulti.isNotEmpty) {
        final anyMatch = selectedTypeMulti.any((t) => FilterRules.matchType(t, nameLower));
        if (!anyMatch) return false;
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
