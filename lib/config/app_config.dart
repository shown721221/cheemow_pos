import 'package:flutter/services.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../services/bluetooth_scanner_service.dart';

class AppConfig {
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
  }
}
