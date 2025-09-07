import '../models/product.dart';

/// CSV 資料驗證器
class CsvValidator {
  
  /// 驗證商品清單
  static ValidationResult validateProducts(List<Product> products) {
    if (products.isEmpty) {
      return ValidationResult.error('沒有找到有效的商品資料');
    }

    final errors = <String>[];
    final warnings = <String>[];
    final duplicateIds = <String>[];
    final duplicateBarcodes = <String>[];
    
    final seenIds = <String>{};
    final seenBarcodes = <String>{};

    for (int i = 0; i < products.length; i++) {
      final product = products[i];
      final rowNum = i + 2; // CSV 中的行號（從2開始，因為第1行是標頭）

      // 驗證必填欄位
      if (product.id.isEmpty) {
  errors.add('第$rowNum行: 商品ID不能為空');
      }

      if (product.barcode.isEmpty) {
  errors.add('第$rowNum行: 商品條碼不能為空');
      }

      if (product.name.isEmpty) {
  errors.add('第$rowNum行: 商品名稱不能為空');
      }

      // 驗證數值範圍
      if (product.price < 0) {
  errors.add('第$rowNum行: 價格不能為負數');
      }

      if (product.stock < 0) {
  warnings.add('第$rowNum行: 庫存為負數 (${product.stock})');
      }

      // 檢查重複的ID
      if (product.id.isNotEmpty) {
        if (seenIds.contains(product.id)) {
          duplicateIds.add(product.id);
        } else {
          seenIds.add(product.id);
        }
      }

      // 檢查重複的條碼
      if (product.barcode.isNotEmpty) {
        if (seenBarcodes.contains(product.barcode)) {
          duplicateBarcodes.add(product.barcode);
        } else {
          seenBarcodes.add(product.barcode);
        }
      }

      // 驗證ID格式（只能包含字母、數字、底線、連字號）
      if (product.id.isNotEmpty && !_isValidId(product.id)) {
  errors.add('第$rowNum行: 商品ID格式無效 (${product.id})');
      }

      // 驗證條碼格式（只能包含數字）
      if (product.barcode.isNotEmpty && !_isValidBarcode(product.barcode)) {
  warnings.add('第$rowNum行: 條碼格式建議只包含數字 (${product.barcode})');
      }

      // 檢查價格是否合理
      if (product.price > 1000000) {
  warnings.add('第$rowNum行: 價格似乎過高 (${product.price})');
      }

      // 檢查庫存是否合理
      if (product.stock > 10000) {
  warnings.add('第$rowNum行: 庫存數量似乎過高 (${product.stock})');
      }
    }

    // 添加重複項目的錯誤訊息
    if (duplicateIds.isNotEmpty) {
      errors.add('發現重複的商品ID: ${duplicateIds.join(', ')}');
    }

    if (duplicateBarcodes.isNotEmpty) {
      errors.add('發現重複的商品條碼: ${duplicateBarcodes.join(', ')}');
    }

    // 生成驗證結果
    if (errors.isNotEmpty) {
      return ValidationResult.error(
        '發現 ${errors.length} 個錯誤:\n${errors.join('\n')}',
        warnings: warnings,
      );
    }

    if (warnings.isNotEmpty) {
      return ValidationResult.warning(
        '發現 ${warnings.length} 個警告:\n${warnings.join('\n')}',
        validCount: products.length,
      );
    }

    return ValidationResult.success(products.length);
  }

  /// 驗證ID格式
  static bool _isValidId(String id) {
    // 只允許字母、數字、底線、連字號
    final regex = RegExp(r'^[a-zA-Z0-9_-]+$');
    return regex.hasMatch(id);
  }

  /// 驗證條碼格式
  static bool _isValidBarcode(String barcode) {
    // 建議只包含數字
    final regex = RegExp(r'^\d+$');
    return regex.hasMatch(barcode);
  }

  /// 過濾有效的商品
  static List<Product> filterValidProducts(List<Product> products) {
    return products.where((product) {
      return product.id.isNotEmpty &&
             product.barcode.isNotEmpty &&
             product.name.isNotEmpty &&
             product.price >= 0;
    }).toList();
  }
}

/// 驗證結果
class ValidationResult {
  final bool isSuccess;
  final bool hasWarnings;
  final String? message;
  final List<String>? warnings;
  final int? validCount;

  ValidationResult._({
    required this.isSuccess,
    required this.hasWarnings,
    this.message,
    this.warnings,
    this.validCount,
  });

  factory ValidationResult.success(int validCount) {
    return ValidationResult._(
      isSuccess: true,
      hasWarnings: false,
      validCount: validCount,
    );
  }

  factory ValidationResult.warning(String message, {required int validCount}) {
    return ValidationResult._(
      isSuccess: true,
      hasWarnings: true,
      message: message,
      validCount: validCount,
    );
  }

  factory ValidationResult.error(String message, {List<String>? warnings}) {
    return ValidationResult._(
      isSuccess: false,
      hasWarnings: warnings?.isNotEmpty ?? false,
      message: message,
      warnings: warnings,
    );
  }
}
