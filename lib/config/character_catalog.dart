import 'package:flutter/material.dart';

/// 角色清單與顏色集中管理，避免多處重複維護。
class CharacterCatalog {
  CharacterCatalog._();

  static const List<String> ordered = [
    'Duffy',
    'ShellieMay',
    'GelaToni',
    'StellaLou',
    'CookieAnn',
    'OluMel',
    'LinaBell',
  ];

  static final Map<String, Color> colors = {
    'Duffy': Colors.brown[400]!,
    'ShellieMay': Colors.pink[300]!,
    'GelaToni': Colors.teal[400]!,
    'StellaLou': Colors.purple[300]!,
    'CookieAnn': Colors.amber[400]!,
    'OluMel': Colors.green[300]!,
    'LinaBell': Colors.pink[200]!,
    '其他角色': Colors.blueGrey[300]!,
  };
}
