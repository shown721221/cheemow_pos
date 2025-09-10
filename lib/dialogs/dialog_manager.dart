import 'package:flutter/material.dart';
import '../services/csv_import_service.dart';
import '../config/app_messages.dart';

/// 統一的對話框管理器
/// 負責管理所有對話框的顯示邏輯
class DialogManager {
  /// 顯示商品未找到對話框
  static void showProductNotFound(BuildContext context, String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppMessages.productNotFoundTitle),
        content: Text(AppMessages.productNotFoundMessage(barcode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppMessages.confirm),
          ),
        ],
      ),
    );
  }

  /// 顯示錯誤對話框
  static void showError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppMessages.confirm),
          ),
        ],
      ),
    );
  }

  /// 顯示 CSV 匯入結果對話框
  static void showImportResult(BuildContext context, CsvImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.success
              ? AppMessages.importSuccessTitle
              : AppMessages.importFailed,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.cancelled) ...[
              Text(AppMessages.importCancelled),
            ] else if (result.success) ...[
              Text(
                AppMessages.importSuccessSummary(
                  result.importedCount,
                  result.totalRows,
                ),
              ),
              if (result.hasErrors)
                Text(AppMessages.importHasErrors(result.errors.length)),
            ] else ...[
              Text(result.errorMessage ?? AppMessages.unknownError),
            ],
            if (result.errors.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                AppMessages.errorDetails,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...result.errors.take(5).map((error) => Text('• $error')),
              if (result.errors.length > 5)
                Text(AppMessages.moreErrors(result.errors.length - 5)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppMessages.confirm),
          ),
        ],
      ),
    );
  }

  /// 顯示 CSV 格式說明對話框
  static void showCsvFormatHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppMessages.csvHelpTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppMessages.csvHelpMustContain),
              SizedBox(height: 8),
              Text(AppMessages.csvHelpRequiredFields),
              Text('   • id: 商品唯一識別碼'),
              Text('   • name: 商品名稱'),
              Text('   • barcode: 商品條碼'),
              Text('   • price: 價格（整數，單位：台幣元）'),
              Text('   • category: 商品分類'),
              Text('   • stock: 庫存數量（整數）'),
              SizedBox(height: 16),
              Text(
                AppMessages.csvHelpSample,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'id,name,barcode,price,category,stock\n'
                  '1,達菲娃娃,1234567890,800,娃娃,10\n'
                  '2,雪莉梅站姿,0987654321,1200,站姿,5',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.pink[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppMessages.csvHelpSpecialTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(AppMessages.csvHelpSpecialLine1),
                    Text(AppMessages.csvHelpSpecialLine2),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                AppMessages.csvHelpEncoding,
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppMessages.ok),
          ),
        ],
      ),
    );
  }

  /// 顯示即將推出功能對話框
  static void showComingSoon(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('即將推出'),
        content: Text('$featureName 功能正在開發中，敬請期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppMessages.confirm),
          ),
        ],
      ),
    );
  }

  /// 顯示確認對話框
  static Future<bool> showConfirmation(
    BuildContext context,
    String title,
    String message, {
    String confirmText = AppMessages.confirm,
    String cancelText = AppMessages.cancel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顯示載入對話框
  static void showLoading(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text(message ?? AppMessages.processing),
          ],
        ),
      ),
    );
  }

  /// 關閉載入對話框
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}
