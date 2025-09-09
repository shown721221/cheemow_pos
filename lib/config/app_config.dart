import 'package:flutter/services.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../services/bluetooth_scanner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // 匯入 CSV 的 PIN（集中設定，避免散落程式碼）
  static const String csvImportPin = '0203';
  static const String _pettyCashKey = 'petty_cash_amount';
  static const String _pettyCashDateKey = 'petty_cash_date'; // yyyymmdd 記錄設定日期
  static int _pettyCash = 0;

  static int get pettyCash => _pettyCash;
  static Future<void> setPettyCash(int value) async {
    _pettyCash = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pettyCashKey, value);
  final now = DateTime.now();
  final today = _fmtDate(now);
  await prefs.setString(_pettyCashDateKey, today);
  }

  static Future<void> initialize() async {
    // 設定螢幕方向為橫向，但允許兩個橫向方向
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 初始化本地資料庫
    await LocalDatabaseService.instance.initialize();

    // 初始化收據服務
    await ReceiptService.instance.initialize();

    // 初始化藍芽掃描器服務
    await BluetoothScannerService.instance.initialize();

    // 載入零用金
    try {
      final prefs = await SharedPreferences.getInstance();
      _pettyCash = prefs.getInt(_pettyCashKey) ?? 0;
      final storedDate = prefs.getString(_pettyCashDateKey);
      final today = _fmtDate(DateTime.now());
      if (storedDate != today) {
        // 跨日：重置零用金為 0（視為未設定）
        _pettyCash = 0;
        await prefs.setInt(_pettyCashKey, 0);
        await prefs.setString(_pettyCashDateKey, today);
      }
    } catch (_) {}
  }

  static Future<void> resetPettyCashIfNewDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_pettyCashDateKey);
      final today = _fmtDate(DateTime.now());
      if (storedDate != today) {
        _pettyCash = 0;
        await prefs.setInt(_pettyCashKey, 0);
        await prefs.setString(_pettyCashDateKey, today);
      }
    } catch (_) {}
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4,'0')}${dt.month.toString().padLeft(2,'0')}${dt.day.toString().padLeft(2,'0')}';
}
