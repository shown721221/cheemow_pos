import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/product.dart';
import 'local_database_service.dart';

class CsvImportService {
  static const String _expectedHeader = 'id,barcode,name,price,category,stock';
  
  /// 選擇並匯入CSV檔案
  static Future<CsvImportResult> importFromFile() async {
    try {
      // 選擇檔案
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return CsvImportResult.cancelled();
      }

      final file = result.files.first;
      if (file.bytes == null) {
        return CsvImportResult.error('無法讀取檔案內容');
      }

      // 解析CSV
      return await _parseAndImportCsv(file.bytes!, file.name);
    } catch (e) {
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
      
      // 解析CSV
      List<List<dynamic>> csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty) {
        return CsvImportResult.error('CSV檔案是空的');
      }

      // 檢查標頭
      List<String> headers = csvData[0].map((e) => e.toString().trim()).toList();
      String actualHeader = headers.join(',');
      
      if (actualHeader != _expectedHeader) {
        return CsvImportResult.error(
          'CSV格式錯誤\n'
          '期望格式: $_expectedHeader\n'
          '實際格式: $actualHeader'
        );
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

          // 驗證必填欄位
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

          products.add(Product(
            id: id,
            barcode: barcode,
            name: name,
            price: price,
            category: category.isEmpty ? '一般商品' : category,
            stock: stock,
            isActive: true,
          ));
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
      ['1', '1234567890123', '可口可樂', '25', '飲料', '100'],
      ['2', '2345678901234', '洋芋片', '35', '零食', '50'],
      ['3', '3456789012345', '礦泉水', '15', '飲料', '200'],
      ['4', '4567890123456', '巧克力', '45', '零食', '30'],
      ['5', '5678901234567', '咖啡', '55', '飲料', '80'],
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
    return CsvImportResult._(
      success: false,
      cancelled: true,
    );
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
