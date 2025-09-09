import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/receipt.dart';

/// 收據資料服務 - 負責收據的儲存和讀取
class ReceiptService {
  static ReceiptService? _instance;
  static ReceiptService get instance => _instance ??= ReceiptService._();

  ReceiptService._();

  SharedPreferences? _prefs;

  /// 初始化服務
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 儲存單筆收據
  Future<bool> saveReceipt(Receipt receipt) async {
    try {
      if (_prefs == null) return false;

      // 取得現有收據列表
      final receipts = await getReceipts();

      // 加入新收據到列表開頭（最新的在前面）
      receipts.insert(0, receipt);

      // 限制收據數量（防止資料過多）
      if (receipts.length > 1000) {
        receipts.removeRange(1000, receipts.length);
      }

      // 儲存更新後的收據列表
      final receiptsJson = receipts.map((r) => r.toJson()).toList();
      await _prefs!.setString('receipts', jsonEncode(receiptsJson));

      debugPrint('收據已儲存: ${receipt.id}, 時間: ${receipt.formattedDateTime}');
      return true;
    } catch (e) {
      debugPrint('儲存收據失敗: $e');
      return false;
    }
  }

  /// 取得所有收據（按時間降序排列）
  Future<List<Receipt>> getReceipts() async {
    try {
      if (_prefs == null) return [];

      final receiptsString = _prefs!.getString('receipts');
      if (receiptsString == null) return [];

      final receiptsList = jsonDecode(receiptsString) as List;
      return receiptsList.map((json) => Receipt.fromJson(json)).toList();
    } catch (e) {
      debugPrint('讀取收據失敗: $e');
      return [];
    }
  }

  /// 依據日期範圍取得收據
  Future<List<Receipt>> getReceiptsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final allReceipts = await getReceipts();

    // 區間為 [startDate, endDate)（含起不含迄）
    return allReceipts.where((receipt) {
      final t = receipt.timestamp;
      final afterOrEqualStart = !t.isBefore(startDate);
      final beforeEnd = t.isBefore(endDate);
      return afterOrEqualStart && beforeEnd;
    }).toList();
  }

  /// 取得今日收據
  Future<List<Receipt>> getTodayReceipts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    return getReceiptsByDateRange(today, tomorrow);
  }

  /// 取得本月收據
  Future<List<Receipt>> getThisMonthReceipts() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    return getReceiptsByDateRange(firstDay, lastDay);
  }

  /// 計算總營收
  Future<int> getTotalRevenue() async {
    final receipts = await getReceipts();
    return receipts.fold<int>(0, (sum, receipt) => sum + receipt.totalAmount);
  }

  /// 計算今日營收
  Future<int> getTodayRevenue() async {
    final todayReceipts = await getTodayReceipts();
    return todayReceipts.fold<int>(
      0,
      (sum, receipt) => sum + receipt.totalAmount,
    );
  }

  /// 計算本月營收
  Future<int> getThisMonthRevenue() async {
    final monthReceipts = await getThisMonthReceipts();
    return monthReceipts.fold<int>(
      0,
      (sum, receipt) => sum + receipt.totalAmount,
    );
  }

  /// 產生收據編號：methodCode-NNN（每日從 001 起，跨付款方式共用序號）
  Future<String> generateReceiptId(
    String paymentMethod, {
    DateTime? now,
  }) async {
    final DateTime t = now ?? DateTime.now();
    final DateTime dayStart = DateTime(t.year, t.month, t.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final todays = await getReceiptsByDateRange(dayStart, dayEnd);
    final nextSeq = todays.length + 1; // 當日整體序號（跨付款方式）
    final seqStr = nextSeq.toString().padLeft(3, '0');
    final methodCode = _methodCode(paymentMethod);
    return '$methodCode-$seqStr';
  }

  String _methodCode(String method) {
    switch (method) {
      case '現金':
        return '1';
      case '轉帳':
        return '2';
      case 'LinePay':
        return '3';
      default:
        return '9';
    }
  }

  /// 取得收據統計資訊
  Future<Map<String, dynamic>> getReceiptStatistics() async {
    final allReceipts = await getReceipts();
    final todayReceipts = await getTodayReceipts();
    final monthReceipts = await getThisMonthReceipts();

    return {
      'totalReceipts': allReceipts.length,
      'todayReceipts': todayReceipts.length,
      'monthReceipts': monthReceipts.length,
      'totalRevenue': getTotalRevenue(),
      'todayRevenue': getTodayRevenue(),
      'monthRevenue': getThisMonthRevenue(),
    };
  }

  /// 刪除特定收據
  Future<bool> deleteReceipt(String receiptId) async {
    try {
      if (_prefs == null) return false;

      final receipts = await getReceipts();
      receipts.removeWhere((receipt) => receipt.id == receiptId);

      final receiptsJson = receipts.map((r) => r.toJson()).toList();
      await _prefs!.setString('receipts', jsonEncode(receiptsJson));

      debugPrint('收據已刪除: $receiptId');
      return true;
    } catch (e) {
      debugPrint('刪除收據失敗: $e');
      return false;
    }
  }

  /// 更新既有收據（依 ID 取代）
  Future<bool> updateReceipt(Receipt updated) async {
    try {
      if (_prefs == null) return false;

      final receipts = await getReceipts();
      final idx = receipts.indexWhere((r) => r.id == updated.id);
      if (idx < 0) return false;

      receipts[idx] = updated;
      final receiptsJson = receipts.map((r) => r.toJson()).toList();
      await _prefs!.setString('receipts', jsonEncode(receiptsJson));
      debugPrint('收據已更新: ${updated.id}');
      return true;
    } catch (e) {
      debugPrint('更新收據失敗: $e');
      return false;
    }
  }

  /// 清空所有收據（謹慎使用）
  Future<bool> clearAllReceipts() async {
    try {
      if (_prefs == null) return false;

      await _prefs!.remove('receipts');
      debugPrint('所有收據已清空');
      return true;
    } catch (e) {
      debugPrint('清空收據失敗: $e');
      return false;
    }
  }

  /// 資料備份 - 匯出所有收據為 JSON 字串
  Future<String?> exportReceiptsToJson() async {
    try {
      final receipts = await getReceipts();
      final backupData = {
        'exportTime': DateTime.now().toIso8601String(),
        'receiptsCount': receipts.length,
        'receipts': receipts.map((r) => r.toJson()).toList(),
      };

      return jsonEncode(backupData);
    } catch (e) {
      debugPrint('匯出收據失敗: $e');
      return null;
    }
  }
}
