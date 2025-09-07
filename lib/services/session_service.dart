import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionMeta {
  final String id;
  final String name;
  final DateTime createdAt;

  SessionMeta({required this.id, required this.name, required this.createdAt});

  factory SessionMeta.fromJson(Map<String, dynamic> json) => SessionMeta(
        id: json['id'],
        name: json['name'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 場次服務：管理市集「場次」與目前選擇的場次
class SessionService {
  static SessionService? _instance;
  static SessionService get instance => _instance ??= SessionService._();
  SessionService._();

  SharedPreferences? _prefs;

  static const _kSessions = 'sessions';
  static const _kCurrentSessionId = 'current_session_id';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_prefs == null) return;

    // 建立預設場次
    if (!_prefs!.containsKey(_kCurrentSessionId)) {
      final defaultMeta = SessionMeta(
        id: 'default',
        name: '預設場次',
        createdAt: DateTime.now(),
      );
      await _saveSessions([defaultMeta]);
      await _prefs!.setString(_kCurrentSessionId, defaultMeta.id);
    } else {
      // 確保 sessions 清單存在
      final sessions = await listSessions();
      if (sessions.isEmpty) {
        final defaultMeta = SessionMeta(
          id: 'default',
          name: '預設場次',
          createdAt: DateTime.now(),
        );
        await _saveSessions([defaultMeta]);
      }
    }

    // 舊資料遷移：將 legacy 'products' / 'receipts' 搬到 default 場次
    final hasLegacyProducts = _prefs!.containsKey('products');
    final hasLegacyReceipts = _prefs!.containsKey('receipts');
    if (hasLegacyProducts || hasLegacyReceipts) {
      // 僅在 default 場次尚未有對應資料時遷移
      if (hasLegacyProducts && !_prefs!.containsKey('products_default')) {
        final val = _prefs!.getString('products');
        if (val != null) {
          await _prefs!.setString('products_default', val);
        }
        await _prefs!.remove('products');
      }
      if (hasLegacyReceipts && !_prefs!.containsKey('receipts_default')) {
        final val = _prefs!.getString('receipts');
        if (val != null) {
          await _prefs!.setString('receipts_default', val);
        }
        await _prefs!.remove('receipts');
      }
    }
  }

  Future<String> getCurrentSessionId() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!.getString(_kCurrentSessionId) ?? 'default';
  }

  Future<List<SessionMeta>> listSessions() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    final raw = _prefs!.getString(_kSessions);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => SessionMeta.fromJson(e))
        .toList();
    return list;
  }

  Future<bool> setCurrentSessionId(String id) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    return _prefs!.setString(_kCurrentSessionId, id);
  }

  Future<SessionMeta> createSession(String name) async {
    final id = 'sess_${DateTime.now().millisecondsSinceEpoch}';
    final meta = SessionMeta(id: id, name: name, createdAt: DateTime.now());
    final sessions = await listSessions();
    sessions.add(meta);
    await _saveSessions(sessions);
    await setCurrentSessionId(id);
    return meta;
  }

  Future<void> _saveSessions(List<SessionMeta> sessions) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    final arr = sessions.map((e) => e.toJson()).toList();
    await _prefs!.setString(_kSessions, jsonEncode(arr));
  }
}
