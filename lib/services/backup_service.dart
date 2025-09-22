import 'dart:convert';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import 'time_service.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData; // 可選剪貼簿支援

/// 提供一鍵備份當前產品與收據資料的 JSON 字串。
class BackupService {
  BackupService._();
  static final instance = BackupService._();

  Future<String> buildBackupJson() async {
    // 確保底層初始化（容錯：忽略例外並繼續，盡量輸出已能取得的資料）
    try {
      await LocalDatabaseService.instance.initialize();
    } catch (_) {}
    try {
      await ReceiptService.instance.initialize();
    } catch (_) {}

    List<Product> products = [];
    List<Receipt> receipts = [];
    try {
      products = await LocalDatabaseService.instance.getProducts();
    } catch (_) {}
    try {
      receipts = await ReceiptService.instance.getReceipts();
    } catch (_) {}

    final now = TimeService.now();
    final map = {
      'backupVersion': 1,
      'generatedAt': now.toIso8601String(),
      'productsCount': products.length,
      'receiptsCount': receipts.length,
      'products': products.map((p) => p.toJson()).toList(),
      'receipts': receipts.map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// 輸出備份並複製至剪貼簿
  Future<bool> copyBackupToClipboard() async {
    try {
      final json = await buildBackupJson();
      await Clipboard.setData(ClipboardData(text: json));
      return true;
    } catch (_) {
      return false;
    }
  }
}
