import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import '../services/local_database_service.dart';
import '../utils/csv_parser.dart';
import '../utils/csv_validator.dart';
import '../utils/data_import_handler.dart';

/// CSV 匯入服務（重構版本）
class CsvImportService {
  static CsvImportService? _instance;
  static CsvImportService get instance => _instance ??= CsvImportService._();
  
  CsvImportService._();

  late final DataImportHandler _importHandler;

  /// 初始化服務
  void initialize() {
    _importHandler = DataImportHandler(LocalDatabaseService.instance);
  }

  /// 選擇並匯入 CSV 檔案
  static Future<CsvImportResult> importFromFile() async {
    try {
      // 選擇檔案
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return CsvImportResult.cancelled();
      }

      final file = result.files.first;

      // 獲取檔案內容
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        return CsvImportResult.error('無法讀取檔案內容，請確認檔案格式正確');
      }

      // 解析並匯入 CSV
      return await instance._parseAndImportCsv(fileBytes, file.name);
    } catch (e) {
      return CsvImportResult.error('檔案選擇失敗: ${e.toString()}');
    }
  }

  /// 處理 CSV 檔案匯入（從 UI 調用）
  Future<void> importCsv(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // 顯示處理中對話框
      _showProgressDialog(context, '正在解析 CSV 檔案...');

      // 1. 解析 CSV 檔案
      final parseResult = CsvParser.parseBytes(bytes, fileName);
      if (!parseResult.success) {
        Navigator.of(context).pop(); // 關閉進度對話框
        _showErrorDialog(context, parseResult.errorMessage!);
        return;
      }

      // 2. 轉換為商品物件
      final products = CsvParser.convertToProducts(parseResult.data!);
      
      // 3. 驗證商品資料
      final validationResult = CsvValidator.validateProducts(products);
      
      Navigator.of(context).pop(); // 關閉進度對話框

      // 4. 處理驗證結果
      if (!validationResult.isSuccess) {
        _showErrorDialog(context, validationResult.message!);
        return;
      }

      if (validationResult.hasWarnings) {
        final shouldContinue = await _showWarningDialog(
          context, 
          validationResult.message!,
          validationResult.validCount!,
        );
        if (!shouldContinue) return;
      }

      // 5. 確認匯入
      final shouldImport = await _showImportConfirmationDialog(
        context,
        validationResult.validCount!,
      );
      if (!shouldImport) return;

      // 6. 執行匯入
      await _performImport(context, products);

    } catch (e) {
      Navigator.of(context).pop(); // 確保關閉任何開啟的對話框
      _showErrorDialog(context, '匯入過程中發生錯誤: ${e.toString()}');
    }
  }

  /// 解析並匯入 CSV 資料（內部方法）
  Future<CsvImportResult> _parseAndImportCsv(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // 1. 解析 CSV 檔案
      final parseResult = CsvParser.parseBytes(bytes, fileName);
      if (!parseResult.success) {
        return CsvImportResult.error(parseResult.errorMessage!);
      }

      // 2. 轉換為商品物件
      final products = CsvParser.convertToProducts(parseResult.data!);
      
      // 3. 驗證商品資料
      final validationResult = CsvValidator.validateProducts(products);
      if (!validationResult.isSuccess) {
        return CsvImportResult.error(validationResult.message!);
      }

      // 4. 過濾有效的商品
      final validProducts = CsvValidator.filterValidProducts(products);

      // 5. 執行匯入
      final importResult = await _importHandler.batchImportProducts(validProducts);
      
      if (importResult.success) {
        return CsvImportResult.success(
          totalCount: importResult.totalCount,
          successCount: importResult.successCount,
          updateCount: importResult.updateCount,
          message: importResult.getSummaryMessage(),
        );
      } else {
        return CsvImportResult.error(importResult.errorMessage!);
      }

    } catch (e) {
      return CsvImportResult.error('解析或匯入失敗: ${e.toString()}');
    }
  }

  /// 執行實際的匯入操作
  Future<void> _performImport(BuildContext context, List<Product> products) async {
    try {
      // 顯示匯入進度
      _showProgressDialog(context, '正在匯入商品資料...');

      // 執行匯入
      final importResult = await _importHandler.batchImportProducts(products);

      Navigator.of(context).pop(); // 關閉進度對話框

      if (importResult.success) {
        _showSuccessDialog(context, importResult.getSummaryMessage());
        
        // 如果有錯誤，顯示詳細資訊
        if (importResult.errors.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 2));
          _showErrorDialog(context, importResult.getDetailedErrorMessage());
        }
      } else {
        _showErrorDialog(context, importResult.errorMessage!);
      }
    } catch (e) {
      Navigator.of(context).pop(); // 確保關閉進度對話框
      _showErrorDialog(context, '匯入失敗: ${e.toString()}');
    }
  }

  /// 顯示進度對話框
  void _showProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// 顯示錯誤對話框
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('錯誤'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  /// 顯示成功對話框
  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('匯入成功'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  /// 顯示警告對話框
  Future<bool> _showWarningDialog(
    BuildContext context, 
    String message, 
    int validCount,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('警告'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text('發現 $validCount 個有效商品，是否繼續匯入？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('繼續'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顯示匯入確認對話框
  Future<bool> _showImportConfirmationDialog(
    BuildContext context,
    int productCount,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認匯入'),
        content: Text('即將匯入 $productCount 個商品，是否繼續？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// CSV 匯入結果
class CsvImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? message;
  final int totalCount;
  final int successCount;
  final int updateCount;

  CsvImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.message,
    this.totalCount = 0,
    this.successCount = 0,
    this.updateCount = 0,
  });

  factory CsvImportResult.success({
    required int totalCount,
    required int successCount,
    required int updateCount,
    required String message,
  }) {
    return CsvImportResult._(
      success: true,
      totalCount: totalCount,
      successCount: successCount,
      updateCount: updateCount,
      message: message,
    );
  }

  factory CsvImportResult.error(String message) {
    return CsvImportResult._(
      success: false,
      errorMessage: message,
    );
  }

  factory CsvImportResult.cancelled() {
    return CsvImportResult._(
      success: false,
      cancelled: true,
    );
  }
}
