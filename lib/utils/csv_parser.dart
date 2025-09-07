import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import '../models/product.dart';

/// CSV 解析器
class CsvParser {
  
  /// 檢測並解析 CSV 資料
  static CsvParseResult parseBytes(Uint8List bytes, String fileName) {
    try {
      // 將 bytes 轉換為字串
      String csvString = utf8.decode(bytes);

      // 檢測分隔符
      String delimiter = _detectDelimiter(csvString);

      // 解析 CSV
      List<List<dynamic>> csvData = CsvToListConverter(
        fieldDelimiter: delimiter,
      ).convert(csvString);

      if (csvData.isEmpty) {
        return CsvParseResult.error('CSV檔案是空的');
      }

      // 驗證標頭
      final headerValidation = _validateHeaders(csvData[0]);
      if (!headerValidation.isValid) {
        return CsvParseResult.error(headerValidation.errorMessage!);
      }

      // 移除標頭行
      final dataRows = csvData.skip(1).toList();

      return CsvParseResult.success(dataRows, delimiter);
    } catch (e) {
      return CsvParseResult.error('解析CSV失敗: ${e.toString()}');
    }
  }

  /// 檢測分隔符
  static String _detectDelimiter(String csvString) {
    // 檢查第一行是否包含Tab且不包含逗號
    final firstLine = csvString.split('\n')[0];
    if (firstLine.contains('\t') && !firstLine.contains(',')) {
      return '\t';
    }
    return ',';
  }

  /// 驗證CSV標頭
  static HeaderValidationResult _validateHeaders(List<dynamic> headerRow) {
    final headers = headerRow
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    final expectedFields = [
      'id',
      'barcode', 
      'name',
      'price',
      'category',
      'stock',
    ];

    if (headers.length != expectedFields.length) {
      return HeaderValidationResult.invalid(
        'CSV欄位數量錯誤\n'
        '期望 ${expectedFields.length} 個欄位: ${expectedFields.join(', ')}\n'
        '實際 ${headers.length} 個欄位: ${headers.join(', ')}'
      );
    }

    // 檢查每個欄位是否存在
    for (int i = 0; i < expectedFields.length; i++) {
      if (!headers[i].contains(expectedFields[i])) {
        return HeaderValidationResult.invalid(
          '第 ${i + 1} 個欄位錯誤\n'
          '期望: ${expectedFields[i]}\n'
          '實際: ${headers[i]}'
        );
      }
    }

    return HeaderValidationResult.valid();
  }

  /// 將資料行轉換為商品物件
  static List<Product> convertToProducts(List<List<dynamic>> dataRows) {
    final products = <Product>[];
    
    for (int i = 0; i < dataRows.length; i++) {
      try {
        final row = dataRows[i];
        if (row.length >= 6) {
          final product = Product(
            id: row[0].toString().trim(),
            barcode: row[1].toString().trim(),
            name: row[2].toString().trim(),
            price: _parsePrice(row[3]),
            stock: _parseStock(row[5]),
          );
          products.add(product);
        }
      } catch (e) {
        // 跳過無效的行，繼續處理下一行
        continue;
      }
    }
    
    return products;
  }

  /// 解析價格
  static int _parsePrice(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    
    final str = value.toString().trim();
    return int.tryParse(str) ?? 0;
  }

  /// 解析庫存
  static int _parseStock(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    
    final str = value.toString().trim();
    return int.tryParse(str) ?? 0;
  }
}

/// CSV 解析結果
class CsvParseResult {
  final bool success;
  final List<List<dynamic>>? data;
  final String? delimiter;
  final String? errorMessage;

  CsvParseResult._({
    required this.success,
    this.data,
    this.delimiter,
    this.errorMessage,
  });

  factory CsvParseResult.success(List<List<dynamic>> data, String delimiter) {
    return CsvParseResult._(
      success: true,
      data: data,
      delimiter: delimiter,
    );
  }

  factory CsvParseResult.error(String message) {
    return CsvParseResult._(
      success: false,
      errorMessage: message,
    );
  }
}

/// 標頭驗證結果
class HeaderValidationResult {
  final bool isValid;
  final String? errorMessage;

  HeaderValidationResult._({
    required this.isValid,
    this.errorMessage,
  });

  factory HeaderValidationResult.valid() {
    return HeaderValidationResult._(isValid: true);
  }

  factory HeaderValidationResult.invalid(String message) {
    return HeaderValidationResult._(
      isValid: false,
      errorMessage: message,
    );
  }
}
