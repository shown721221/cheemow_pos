import 'package:flutter/material.dart';
import '../dialogs/dialog_manager.dart';
import '../utils/revenue_export_helper.dart';
import '../config/app_messages.dart';
import '../services/receipt_service.dart';
import '../config/app_strings.dart';

/// 將與主畫面 AppBar 功能相關的跨功能操作集中，方便重用與測試。
class PosActionsService {
  PosActionsService._();
  static final instance = PosActionsService._();

  Future<void> exportTodayRevenueImage(BuildContext context) async {
    final ok = await RevenueExportHelper.exportTodayRevenueImage(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppMessages.autoExportRevenueSuccess
              : AppMessages.autoExportRevenueFailure,
        ),
      ),
    );
  }

  Future<void> showReceiptStatistics(BuildContext context) async {
    final stats = await ReceiptService.instance.getReceiptStatistics();
    if (!context.mounted) return;
    DialogManager.showInfo(
      context,
      AppStrings.receiptStatisticsTitle,
      'Total: ${stats['totalReceipts']}, Today: ${stats['todayReceipts']}, Month: ${stats['monthReceipts']}',
    );
  }
}
