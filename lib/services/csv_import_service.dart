import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'local_database_service.dart';

class CsvImportService {
  /// 選擇並匯入CSV檔案
  static Future<CsvImportResult> importFromFile() async {
    try {
      // 選擇檔案
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
        withData: true, // 確保載入檔案資料
      );

      if (result == null || result.files.isEmpty) {
        return CsvImportResult.cancelled();
      }

      final file = result.files.first;

      // 嘗試多種方式獲取檔案內容
      Uint8List? fileBytes;

      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        // 如果bytes為null，嘗試從路徑讀取
        try {
          final fileContent = await File(file.path!).readAsBytes();
          fileBytes = fileContent;
        } catch (e) {
          debugPrint('從路徑讀取檔案失敗: $e');
        }
      }

      if (fileBytes == null) {
        return CsvImportResult.error('無法讀取檔案內容，請確認檔案格式正確');
      }

      // 解析CSV
      return await _parseAndImportCsv(fileBytes, file.name);
    } catch (e) {
      debugPrint('檔案選擇失敗: $e');
      return CsvImportResult.error('檔案選擇失敗: ${e.toString()}');
    }
  }

  /// 解析並匯入CSV資料
  static Future<CsvImportResult> _parseAndImportCsv(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      // 將bytes轉換為字串
      String csvString = utf8.decode(bytes);

      // 檢測分隔符並解析CSV
      String delimiter = ',';
      // 檢查是否使用Tab分隔
      if (csvString.contains('\t') && !csvString.split('\n')[0].contains(',')) {
        delimiter = '\t';
      }

      List<List<dynamic>> csvData = CsvToListConverter(
        fieldDelimiter: delimiter,
      ).convert(csvString);

      if (csvData.isEmpty) {
        return CsvImportResult.error('CSV檔案是空的');
      }

      // 檢查標頭
      List<String> headers = csvData[0]
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      List<String> expectedFields = [
        'id',
        'barcode',
        'name',
        'price',
        'category',
        'stock',
      ];

  debugPrint('期望欄位: $expectedFields');
  debugPrint('實際欄位: $headers');
  debugPrint('欄位數量 - 期望: ${expectedFields.length}, 實際: ${headers.length}');
  debugPrint('使用的分隔符: ${delimiter == '\t' ? 'Tab' : '逗號'}');

      if (headers.length != expectedFields.length) {
        return CsvImportResult.error(
          'CSV欄位數量錯誤\n'
          '期望 ${expectedFields.length} 個欄位: ${expectedFields.join(', ')}\n'
          '實際 ${headers.length} 個欄位: ${headers.join(', ')}',
        );
      }

      // 檢查每個欄位是否匹配
      for (int i = 0; i < expectedFields.length; i++) {
        if (headers[i] != expectedFields[i]) {
          return CsvImportResult.error(
            'CSV欄位名稱錯誤\n'
            '第 ${i + 1} 個欄位期望: ${expectedFields[i]}\n'
            '第 ${i + 1} 個欄位實際: ${headers[i]}',
          );
        }
      }

      // 解析商品資料
      List<Product> products = [];
      List<String> errors = [];

      for (int i = 1; i < csvData.length; i++) {
        try {
          List<dynamic> row = csvData[i];
          if (row.length < 6) {
            errors.add('第${i + 1}行：欄位數量不足');
            continue;
          }

          String id = row[0].toString().trim();
          String barcode = row[1].toString().trim();
          String name = row[2].toString().trim();
          String priceStr = row[3].toString().trim();
          String category = row[4].toString().trim();
          String stockStr = row[5].toString().trim();

          // 驗證必填欄位（ID保持原始格式，包含前導0）
          if (id.isEmpty || barcode.isEmpty || name.isEmpty) {
            errors.add('第${i + 1}行：ID、條碼或商品名稱不能為空');
            continue;
          }

          // 解析價格
          int? price = int.tryParse(priceStr);
          if (price == null) {
            errors.add('第${i + 1}行：價格格式錯誤 ($priceStr)');
            continue;
          }

          // 解析庫存
          int? stock = int.tryParse(stockStr);
          if (stock == null) {
            errors.add('第${i + 1}行：庫存格式錯誤 ($stockStr)');
            continue;
          }

          products.add(
            Product(
              id: id, // 保持原始ID格式（包含前導0）
              barcode: barcode,
              name: name,
              price: price,
              category: category, // 允許為空字串
              stock: stock,
              isActive: true,
            ),
          );
        } catch (e) {
          errors.add('第${i + 1}行：解析錯誤 - ${e.toString()}');
        }
      }

      if (products.isEmpty) {
        return CsvImportResult.error('沒有有效的商品資料');
      }

      // 檢查重複的ID和條碼
      Set<String> ids = {};
      Set<String> barcodes = {};
      List<String> duplicateErrors = [];

      for (int i = 0; i < products.length; i++) {
        Product product = products[i];

        if (ids.contains(product.id)) {
          duplicateErrors.add('ID重複: ${product.id}');
        } else {
          ids.add(product.id);
        }

        if (barcodes.contains(product.barcode)) {
          duplicateErrors.add('條碼重複: ${product.barcode}');
        } else {
          barcodes.add(product.barcode);
        }
      }

      if (duplicateErrors.isNotEmpty) {
        errors.addAll(duplicateErrors);
      }

      // 儲存商品資料（使用智慧合併）
      await LocalDatabaseService.instance.mergeImportedProducts(products);

      return CsvImportResult.success(
        importedCount: products.length,
        totalRows: csvData.length - 1,
        errors: errors,
        fileName: fileName,
      );
    } catch (e) {
      return CsvImportResult.error('CSV解析失敗: ${e.toString()}');
    }
  }

  /// 產生範例CSV檔案內容
  static String generateSampleCsv() {
    List<List<String>> csvData = [
      ['id', 'barcode', 'name', 'price', 'category', 'stock'],
      ['001', '1234567890123', '可口可樂', '25', '飲料', '100'],
      ['002', '2345678901234', '洋芋片', '35', '零食', '50'],
      ['003', '3456789012345', '礦泉水', '15', '飲料', '200'],
      ['004', '4567890123456', '巧克力', '45', '', '30'],
      ['0005', '5678901234567', '咖啡', '55', '飲料', '80'],
    ];

    return const ListToCsvConverter().convert(csvData);
  }
}

/// CSV匯入結果
class CsvImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final int importedCount;
  final int totalRows;
  final List<String> errors;
  final String fileName;

  CsvImportResult._({
    required this.success,
    required this.cancelled,
    this.errorMessage,
    this.importedCount = 0,
    this.totalRows = 0,
    this.errors = const [],
    this.fileName = '',
  });

  factory CsvImportResult.success({
    required int importedCount,
    required int totalRows,
    required List<String> errors,
    required String fileName,
  }) {
    return CsvImportResult._(
      success: true,
      cancelled: false,
      importedCount: importedCount,
      totalRows: totalRows,
      errors: errors,
      fileName: fileName,
    );
  }

  factory CsvImportResult.error(String message) {
    return CsvImportResult._(
      success: false,
      cancelled: false,
      errorMessage: message,
    );
  }

  factory CsvImportResult.cancelled() {
    return CsvImportResult._(success: false, cancelled: true);
  }

  bool get hasErrors => errors.isNotEmpty;

  String get statusMessage {
    if (cancelled) return '匯入已取消';
    if (!success) return errorMessage ?? '匯入失敗';

    String result = '成功匯入 $importedCount/$totalRows 筆商品';
    if (hasErrors) {
      result += '\n發現 ${errors.length} 個問題';
    }
    return result;
  }
}
