import '../models/product.dart';
import '../services/local_database_service.dart';

/// 資料匯入處理器
class DataImportHandler {
  final LocalDatabaseService _databaseService;

  DataImportHandler(this._databaseService);

  /// 匯入商品資料
  Future<ImportResult> importProducts(List<Product> products) async {
    try {
      // 使用 mergeImportedProducts 方法來處理匯入
      await _databaseService.mergeImportedProducts(products);
      
      // 計算結果統計
      int successCount = 0;
      int updateCount = 0;
      
      // 檢查每個產品是否是新增或更新
      final existingProducts = await _databaseService.getProducts();
      final existingIds = existingProducts.map((p) => p.id).toSet();
      
      for (final product in products) {
        if (existingIds.contains(product.id)) {
          updateCount++;
        } else {
          successCount++;
        }
      }

      return ImportResult(
        success: true,
        totalCount: products.length,
        successCount: successCount,
        updateCount: updateCount,
        skipCount: 0,
        errors: [],
      );
    } catch (e) {
      return ImportResult(
        success: false,
        totalCount: products.length,
        errorMessage: '匯入失敗: ${e.toString()}',
      );
    }
  }

  /// 批次匯入商品（分批處理以提高效能）
  Future<ImportResult> batchImportProducts(List<Product> products, {int batchSize = 50}) async {
    try {
      int totalSuccessCount = 0;
      int totalUpdateCount = 0;
      int totalSkipCount = 0;
      final allErrors = <String>[];

      // 分批處理
      for (int i = 0; i < products.length; i += batchSize) {
        final batch = products.skip(i).take(batchSize).toList();
        final result = await importProducts(batch);

        totalSuccessCount += result.successCount;
        totalUpdateCount += result.updateCount;
        totalSkipCount += result.skipCount;
        allErrors.addAll(result.errors);

        if (!result.success) {
          return ImportResult(
            success: false,
            totalCount: products.length,
            errorMessage: result.errorMessage,
          );
        }
      }

      return ImportResult(
        success: true,
        totalCount: products.length,
        successCount: totalSuccessCount,
        updateCount: totalUpdateCount,
        skipCount: totalSkipCount,
        errors: allErrors,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        totalCount: products.length,
        errorMessage: '批次匯入失敗: ${e.toString()}',
      );
    }
  }

  /// 清除所有商品資料（危險操作）
  Future<bool> clearAllProducts() async {
    try {
      // 使用空列表來清除所有商品
      await _databaseService.saveProducts([]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 備份現有商品資料
  Future<List<Product>> backupProducts() async {
    try {
      return await _databaseService.getProducts();
    } catch (e) {
      return [];
    }
  }

  /// 還原商品資料
  Future<bool> restoreProducts(List<Product> products) async {
    try {
      // 直接儲存備份的商品資料（會覆蓋現有資料）
      await _databaseService.saveProducts(products);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 匯入結果
class ImportResult {
  final bool success;
  final int totalCount;
  final int successCount;
  final int updateCount;
  final int skipCount;
  final List<String> errors;
  final String? errorMessage;

  ImportResult({
    required this.success,
    required this.totalCount,
    this.successCount = 0,
    this.updateCount = 0,
    this.skipCount = 0,
    this.errors = const [],
    this.errorMessage,
  });

  /// 取得結果摘要訊息
  String getSummaryMessage() {
    if (!success) {
      return errorMessage ?? '匯入失敗';
    }

    final messages = <String>[];
    
    if (successCount > 0) {
      messages.add('新增 $successCount 個商品');
    }
    
    if (updateCount > 0) {
      messages.add('更新 $updateCount 個商品');
    }
    
    if (skipCount > 0) {
      messages.add('跳過 $skipCount 個商品');
    }

    if (messages.isEmpty) {
      return '沒有匯入任何商品';
    }

    String summary = messages.join('，');
    
    if (errors.isNotEmpty) {
      summary += '\n發生 ${errors.length} 個錯誤';
    }

    return summary;
  }

  /// 取得詳細錯誤訊息
  String getDetailedErrorMessage() {
    if (errors.isEmpty) return '';
    
    return '錯誤詳情：\n${errors.join('\n')}';
  }
}
