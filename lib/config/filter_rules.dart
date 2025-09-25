import 'package:collection/collection.dart';

/// 集中管理搜尋/篩選所需的文字規則，降低硬編碼 switch。
/// 所有比對一律使用 toLowerCase() 處理後再 contains。
class FilterRules {
  FilterRules._();

  /// 地區 → 關鍵字列表（皆為小寫）
  static const Map<String, List<String>> location = {
    '東京': ['東京disney限定', '東京迪士尼限定', '東京disney', '東京迪士尼', 'tokyo'],
    '上海': ['上海disney限定', '上海迪士尼限定', '上海disney', '上海迪士尼', 'shanghai'],
    '香港': ['香港disney限定', '香港迪士尼限定', '香港disney', '香港迪士尼', 'hongkong', 'hk'],
  };

  /// 角色 → 關鍵字列表
  static const Map<String, List<String>> characters = {
    'Duffy': ['duffy'],
    'GelaToni': ['gelatoni'],
    'OluMel': ['olumel'],
    'ShellieMay': ['shelliemay'],
    'StellaLou': ['stellalou'],
    'CookieAnn': ['cookieann'],
    'LinaBell': ['linabell'],
  };

  /// 類型 → 關鍵字列表（特例："其他吊飾" 需要排除站姿/坐姿）
  static const Map<String, List<String>> types = {
    '娃娃': ['娃娃'],
    '站姿': ['站姿'],
    '坐姿': ['坐姿'],
    '其他吊飾': ['吊飾'],
  };

  /// 是否符合地區
  static bool matchLocation(String label, String nameLower) {
    final kws = location[label];
    if (kws == null) return false;
    return kws.any(nameLower.contains);
  }

  /// 是否符合角色
  static bool matchCharacter(String label, String nameLower) {
    final kws = characters[label];
    if (kws == null) return false;
    return kws.any(nameLower.contains);
  }

  /// 是否符合類型（含其他吊飾邏輯）
  static bool matchType(String label, String nameLower) {
    if (label == '其他吊飾') {
      // 必須包含吊飾，但不能包含 站姿 / 坐姿
      if (!nameLower.contains('吊飾')) return false;
      if (nameLower.contains('站姿') || nameLower.contains('坐姿')) return false;
      return true;
    }
    final kws = types[label];
    if (kws == null) return false;
    return kws.any(nameLower.contains);
  }

  /// 是否為角色分類標籤（含 "其他角色" 特例）
  static bool isCharacterLabel(String label) =>
      characters.keys.contains(label) || label == '其他角色';

  /// 是否為地區標籤
  static bool isLocationLabel(String label) => location.keys.contains(label);

  /// 是否為類型標籤
  static bool isTypeLabel(String label) => types.keys.contains(label);

  /// 是否為角色已知關鍵字（用於 "其他角色" 判斷）
  static bool isKnownCharacterName(String nameLower) {
    return characters.values.flattened.any((k) => nameLower.contains(k));
  }
}
