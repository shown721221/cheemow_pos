import 'package:flutter/material.dart';
import '../config/app_messages.dart';
import '../dialogs/petty_cash_dialog.dart';
import '../utils/revenue_export_helper.dart';
import '../utils/popularity_export_helper.dart';
import '../services/sales_export_service.dart';
import '../screens/receipt_list_screen.dart';
import '../services/export_service.dart';
import '../services/receipt_service.dart';

class PosMoreMenu extends StatelessWidget {
  final Future<void> Function() onImport;
  final Future<void> Function() onReloadProducts;
  const PosMoreMenu({
    super.key,
    required this.onImport,
    required this.onReloadProducts,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: AppMessages.menuTooltip,
      onSelected: (value) async {
        switch (value) {
          case 'import':
            await onImport();
            break;
          case 'receipts':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptListScreen()),
            ).then((_) => onReloadProducts());
            break;
          case 'revenue':
            await RevenueExportHelper.exportTodayRevenueImage(context);
            break;
          case 'popularity':
            await PopularityExportHelper.exportTodayPopularityImage(context);
            break;
          case 'pettycash':
            await PettyCashDialog.show(context);
            break;
          case 'sales_export':
            await _exportSalesData(context);
            break;
        }
      },
      itemBuilder: (ctx) => [
        _item('import', '🧸', AppMessages.menuImport),
        _item('sales_export', '📊', AppMessages.menuSalesExport),
        _item('receipts', '🧾', AppMessages.menuReceipts),
        _item('revenue', '🌤️', AppMessages.menuRevenue),
        _item('popularity', '📈', AppMessages.menuPopularity),
        _item('pettycash', '💰', AppMessages.menuPettyCash),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, String emoji, String text) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      );

  Future<void> _exportSalesData(BuildContext context) async {
    try {
      await ReceiptService.instance.initialize();
      final receipts = await ReceiptService.instance.getTodayReceipts();
      if (receipts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppMessages.salesExportNoData)),
          );
        }
        return;
      }
      final bundle = SalesExportService.instance.buildCsvsForReceipts(receipts);
      final now = DateTime.now();
      final dateSuffix =
          '${(now.year % 100).toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final res = await ExportService.instance.saveCsvFiles(
        files: {
          '銷售_$dateSuffix.csv': bundle.salesCsv,
          '特殊商品_$dateSuffix.csv': bundle.specialCsv,
        },
        addBom: true,
      );
      if (!context.mounted) return;
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppMessages.salesExportSuccess(res.paths))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppMessages.salesExportFailure(res.failure?.message ?? '未知錯誤'),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppMessages.salesExportFailure(e.toString()))),
        );
      }
    }
  }
}
