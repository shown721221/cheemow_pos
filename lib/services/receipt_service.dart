import 'dart:convert';
import '../models/receipt.dart';
import 'time_service.dart';
// 移除未使用的 constants import
import '../repositories/receipt_repository.dart';
import 'receipt_id_generator.dart';
import '../utils/app_logger.dart';

/// 收據資料服務 - 負責收據的儲存和讀取
class ReceiptService {
  static ReceiptService? _instance;
  static ReceiptService get instance => _instance ??= ReceiptService._();

  ReceiptService._();

  /// 初始化服務
  Future<void> initialize() async {
    await ReceiptRepository.instance.initialize();
  }

  /// 儲存單筆收據
  Future<bool> saveReceipt(Receipt receipt) async {
    try {
      final receipts = await getReceipts();
      receipts.insert(0, receipt);
      // 優化：限制記憶體中保留200筆收據，平衡效能與歷史資料需求
      if (receipts.length > 200) receipts.removeRange(200, receipts.length);
      await ReceiptRepository.instance.saveAll(receipts);

      AppLogger.i('收據已儲存: ${receipt.id}, 時間: ${receipt.formattedDateTime}');
      return true;
    } catch (e) {
      AppLogger.w('儲存收據失敗', e);
      return false;
    }
  }

  /// 取得所有收據（按時間降序排列）
  Future<List<Receipt>> getReceipts() async {
    try {
      return ReceiptRepository.instance.getAll();
    } catch (e) {
      AppLogger.w('讀取收據失敗', e);
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
    final now = TimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    return getReceiptsByDateRange(today, tomorrow);
  }

  /// 取得本月收據
  Future<List<Receipt>> getThisMonthReceipts() async {
    final now = TimeService.now();
    final firstDay = DateTime(now.year, now.month, 1);
    // 以半開區間 [firstDay, nextMonthFirstDay)
    final nextMonthFirstDay = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    return getReceiptsByDateRange(firstDay, nextMonthFirstDay);
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
    return ReceiptIdGenerator.instance.generate(paymentMethod, now: now);
  }

  /// 取得收據統計資訊
  Future<Map<String, dynamic>> getReceiptStatistics() async {
    final allReceipts = await getReceipts();
    final todayReceipts = await getTodayReceipts();
    final monthReceipts = await getThisMonthReceipts();
    final totalRevenue = await getTotalRevenue();
    final todayRevenue = await getTodayRevenue();
    final monthRevenue = await getThisMonthRevenue();

    return {
      'totalReceipts': allReceipts.length,
      'todayReceipts': todayReceipts.length,
      'monthReceipts': monthReceipts.length,
      'totalRevenue': totalRevenue,
      'todayRevenue': todayRevenue,
      'monthRevenue': monthRevenue,
    };
  }

  /// 刪除特定收據
  Future<bool> deleteReceipt(String receiptId) async {
    try {
      final receipts = await getReceipts();
      receipts.removeWhere((r) => r.id == receiptId);
      await ReceiptRepository.instance.saveAll(receipts);

      AppLogger.i('收據已刪除: $receiptId');
      return true;
    } catch (e) {
      AppLogger.w('刪除收據失敗', e);
      return false;
    }
  }

  /// 更新既有收據（依 ID 取代）
  Future<bool> updateReceipt(Receipt updated) async {
    try {
      final receipts = await getReceipts();
      final idx = receipts.indexWhere((r) => r.id == updated.id);
      if (idx < 0) return false;
      receipts[idx] = updated;
      await ReceiptRepository.instance.saveAll(receipts);
      AppLogger.i('收據已更新: ${updated.id}');
      return true;
    } catch (e) {
      AppLogger.w('更新收據失敗', e);
      return false;
    }
  }

  /// 清空所有收據（謹慎使用）
  Future<bool> clearAllReceipts() async {
    try {
      await ReceiptRepository.instance.clearAll();
      AppLogger.i('所有收據已清空');
      return true;
    } catch (e) {
      AppLogger.w('清空收據失敗', e);
      return false;
    }
  }

  /// 資料備份 - 匯出所有收據為 JSON 字串
  Future<String?> exportReceiptsToJson() async {
    try {
      final receipts = await getReceipts();
      return jsonEncode({
        'exportTime': TimeService.now().toIso8601String(),
        'receiptsCount': receipts.length,
        'receipts': receipts.map((r) => r.toJson()).toList(),
      });
    } catch (e) {
      AppLogger.w('匯出收據失敗', e);
      return null;
    }
  }
}
