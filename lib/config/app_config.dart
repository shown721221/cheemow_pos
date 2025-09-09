import 'package:flutter/services.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../services/bluetooth_scanner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // 匯入 CSV 的 PIN（集中設定，避免散落程式碼）
  static const String csvImportPin = '0203';
  static const String _pettyCashKey = 'petty_cash_amount';
  static int _pettyCash = 0;

  static int get pettyCash => _pettyCash;
  static Future<void> setPettyCash(int value) async {
    _pettyCash = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pettyCashKey, value);
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
    } catch (_) {}
  }
}
