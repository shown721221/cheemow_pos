import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/receipt.dart';
import '../utils/app_logger.dart';

class ReceiptRepository {
  ReceiptRepository._();
  static final instance = ReceiptRepository._();
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<Receipt>> getAll() async {
    if (_prefs == null) return [];
    final raw = _prefs!.getString('receipts');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Receipt.fromJson(e)).toList();
    } catch (e) {
      AppLogger.w('讀取收據失敗', e);
      return [];
    }
  }

  Future<void> saveAll(List<Receipt> receipts) async {
    if (_prefs == null) return;
    final data = receipts.map((r) => r.toJson()).toList();
    await _prefs!.setString('receipts', jsonEncode(data));
  }

  Future<void> clearAll() async {
    if (_prefs == null) return;
    await _prefs!.remove('receipts');
  }
}
