import '../models/product.dart';
import '../config/filter_rules.dart';

/// 搜尋 / 篩選核心管理：
/// 規則摘要：
/// 1. 地區 (locationGroup)：互斥，只能選一個。
/// 2. 角色 (characterGroup)：互斥（含『其他角色』）。
/// 3. 類型 (typeGroup)：
///    - 『娃娃』 與 其餘吊飾（站姿/坐姿/其他）互斥。
///    - 『站姿吊飾』『坐姿吊飾』『其他吊飾』可多選，採 OR。
/// 4. 其他標籤：例如『有庫存』為獨立布林篩選，可與任何組合並存。
/// 5. 文字搜尋：以空白分詞，任一詞命中名稱或條碼即可。
class SearchFilterManager {
  // ---- 常數標籤 ----
  static const String dollLabel = '娃娃';
  static const String otherRoleLabel = '其他角色';

  // ---- 群組宣告 ----
  static const List<String> locationGroup = ['東京', '上海', '香港'];
  static const List<String> characterGroup = [
    'Duffy', 'ShellieMay', 'GelaToni', 'StellaLou', 'CookieAnn', 'OluMel', 'LinaBell', otherRoleLabel,
  ];
  static const List<String> typeGroup = [dollLabel, '站姿吊飾', '坐姿吊飾', '其他吊飾'];

  // 多選吊飾類型（使用 Set 提升查找效率 & 可讀性）
  static const Set<String> multiSelectableTypes = {'站姿吊飾', '坐姿吊飾', '其他吊飾'};

  /// 切換篩選標籤入口
  List<String> toggleFilter(List<String> selected, String label) {
    if (locationGroup.contains(label)) {
      return _toggleExclusive(selected, locationGroup, label);
    }
    if (characterGroup.contains(label)) {
      return _toggleExclusive(selected, characterGroup, label);
    }
    if (typeGroup.contains(label)) {
      return _toggleType(selected, label);
    }
    // 其他（如 有庫存）=> 簡單切換
    return _toggleSingle(selected, label);
  }

  // --- 私有：互斥群組通用切換 ---
  List<String> _toggleExclusive(List<String> selected, List<String> group, String label) {
    final next = <String>[];
    for (final f in selected) {
      if (!group.contains(f)) next.add(f); // 移除同群組其它
    }
    if (!selected.contains(label)) {
      next.add(label);
    } // 若原本有則等於取消
    return next;
  }

  // --- 私有：單純 toggling ---
  List<String> _toggleSingle(List<String> selected, String label) {
    final next = List<String>.from(selected);
    if (next.contains(label)) {
      next.remove(label);
    } else {
      next.add(label);
    }
    return next;
  }

  // --- 私有：類型切換（娃娃互斥 + 多選 OR）---
  List<String> _toggleType(List<String> selected, String label) {
    final hasLabel = selected.contains(label);
    final next = <String>[];

    // 先保留非 typeGroup 的東西
    for (final f in selected) {
      if (!typeGroup.contains(f)) next.add(f);
    }

    if (label == dollLabel) {
      // 點『娃娃』：清空所有多選類型；若未選則加入，若已選則不加入（等於取消）
      if (!hasLabel) {
        next.add(dollLabel);
      }
      return next;
    }

    // 多選吊飾：移除娃娃，其餘按 toggle
    // 先回填現有已勾選的多選（除了目前點擊項若為取消）
    for (final f in selected) {
      if (multiSelectableTypes.contains(f) && f != label) {
        next.add(f);
      }
    }
    if (!hasLabel) {
      // 新增此次點擊
      next.add(label);
    } // 有的話代表取消 -> 不加回

    return next;
  }

  /// 純文字搜尋（空字串回傳空清單，與既有 UI 行為一致）
  List<Product> search(List<Product> products, String query) {
    final q = query.trim();
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    final matches = products.where((p) {
      final nameLower = p.name.toLowerCase();
      final barcodeLower = p.barcode.toLowerCase();
      return nameLower.contains(lower) || barcodeLower.contains(lower);
    }).toList();
    matches.sort(compareForSearchSort);
    return matches;
  }

  /// 套用篩選條件（AND 組合），其中多選吊飾屬 OR。
  List<Product> filter(
    List<Product> products,
    List<String> selectedFilters, {
    String searchQuery = '',
  }) {
    // --- 預處理：分詞 ---
    final terms = searchQuery
        .toLowerCase()
        .split(' ')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    // --- 預分類選擇 ---
    String? selectedLocation;
    String? selectedCharacter; // 若為 otherRoleLabel 則用 isKnownCharacterName 反判斷
    bool selectOtherRole = false;
    bool requireStock = false;
    bool dollSelected = false;
    final Set<String> multiTypeSelected = {};

    for (final f in selectedFilters) {
      if (locationGroup.contains(f)) {
        selectedLocation = f; // 互斥只會有一個
      } else if (characterGroup.contains(f)) {
        if (f == otherRoleLabel) {
          selectOtherRole = true;
        } else {
          selectedCharacter = f;
        }
      } else if (f == dollLabel) {
        dollSelected = true;
      } else if (multiSelectableTypes.contains(f)) {
        multiTypeSelected.add(f);
      } else if (f == '有庫存') {
        requireStock = true;
      }
    }

    final filtered = products.where((p) {
      final nameLower = p.name.toLowerCase();
      final barcodeLower = p.barcode.toLowerCase();

      // 文字搜尋 (任一詞命中名稱或條碼)
      if (terms.isNotEmpty) {
        final hit = terms.any((t) => nameLower.contains(t) || barcodeLower.contains(t));
        if (!hit) return false;
      }

      // 地區
      if (selectedLocation != null && !FilterRules.matchLocation(selectedLocation, nameLower)) {
        return false;
      }

      // 角色
      if (selectedCharacter != null) {
        if (!FilterRules.matchCharacter(selectedCharacter, nameLower)) return false;
      } else if (selectOtherRole) {
        if (FilterRules.isKnownCharacterName(nameLower)) return false; // 其它角色 => 不得包含已知角色關鍵字
      }

      // 庫存
      if (requireStock && p.stock <= 0) return false;

      // 類型
      if (!_matchTypes(nameLower, dollSelected, multiTypeSelected)) return false;

      return true;
    }).toList();

    filtered.sort(compareForSearchSort);
    return filtered;
  }

  /// 類型判斷：
  /// - 選了娃娃 => 必須是娃娃
  /// - 未選娃娃且有多選吊飾 => 任一匹配
  /// - 若完全沒選類型 => 不限制
  bool _matchTypes(String nameLower, bool dollSelected, Set<String> multiTypes) {
    if (dollSelected) {
      return FilterRules.matchType(dollLabel, nameLower);
    }
    if (multiTypes.isNotEmpty) {
      for (final t in multiTypes) {
        if (FilterRules.matchType(t, nameLower)) return true;
      }
      return false;
    }
    return true; // 未選任何類型
  }

  /// 搜尋/篩選的共同排序規則
  static int compareForSearchSort(Product a, Product b) {
    if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
    if (b.isSpecialProduct && !a.isSpecialProduct) return 1;
    if (a.isSpecialProduct && b.isSpecialProduct) {
      if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
      if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
      return 0;
    }
    return a.name.compareTo(b.name);
  }
}
