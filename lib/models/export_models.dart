/// 匯出功能統一結果 / 失敗描述模型
/// 目的：集中錯誤分類，讓呼叫端用 code 分支而非字串對比
enum ExportFailureCode {
  ioError,
  permissionDenied,
  noStorageDirectory,
  encodeFailed,
  emptyInput,
  unknown,
}

class ExportFailure {
  final ExportFailureCode code;
  final String message; // 已本地化的簡短描述即可
  final Object? error; // 原始錯誤
  final StackTrace? stackTrace;
  const ExportFailure({
    required this.code,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() =>
      'ExportFailure(code=$code, message=$message, error=$error)';
}

class UnifiedExportResult {
  final bool success;
  final List<String> paths; // 實際寫入路徑（可能為空）
  final ExportFailure? failure;

  const UnifiedExportResult._({
    required this.success,
    required this.paths,
    this.failure,
  });

  factory UnifiedExportResult.success(List<String> paths) =>
      UnifiedExportResult._(success: true, paths: paths);

  factory UnifiedExportResult.failure(ExportFailure failure) =>
      UnifiedExportResult._(success: false, paths: const [], failure: failure);
}
