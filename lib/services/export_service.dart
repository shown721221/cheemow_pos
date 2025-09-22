import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cheemeow_pos/utils/app_logger.dart';
import 'package:cheemeow_pos/models/export_models.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

// 舊 ExportResult 已被 UnifiedExportResult 取代

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static String? testOverrideBaseDir; // 測試覆寫

  String _dateFolder(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  Future<UnifiedExportResult> savePng({
    required String fileName,
    required Uint8List bytes,
    DateTime? now,
  }) async {
    try {
      final n = now ?? DateTime.now();
      final folder = _dateFolder(n);
      final root = await _resolveBaseDirectory(folder);
      if (root == null) {
        return UnifiedExportResult.failure(
          const ExportFailure(
            code: ExportFailureCode.noStorageDirectory,
            message: '無法取得儲存目錄',
          ),
        );
      }
      if (Platform.isAndroid && testOverrideBaseDir == null) {
        final tmp = await _writeTemp(fileName, bytes);
        try {
          await MediaStore.ensureInitialized();
          MediaStore.appFolder = 'cheemeow_pos';
          final mediaStore = MediaStore();
          final save = await mediaStore.saveFile(
            tempFilePath: tmp.path,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: folder,
          );
          String? path = save?.uri.toString();
          if (path != null) {
            final real = await mediaStore.getFilePathFromUri(uriString: path);
            if (real != null) path = real;
          }
          if (path != null) {
            return UnifiedExportResult.success([path]);
          }
          return UnifiedExportResult.failure(
            const ExportFailure(
              code: ExportFailureCode.unknown,
              message: '檔案儲存失敗 (未知原因)',
            ),
          );
        } finally {
          try {
            await tmp.delete();
          } catch (_) {}
        }
      } else {
        final dir = Directory(root);
        if (!await dir.exists()) await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        await file.writeAsBytes(bytes, flush: true);
        return UnifiedExportResult.success([file.path]);
      }
    } catch (e, st) {
      final failure = _mapError('[savePng]', e, st);
      return UnifiedExportResult.failure(failure);
    }
  }

  Future<UnifiedExportResult> saveCsvFiles({
    required Map<String, String> files,
    bool addBom = true,
    DateTime? now,
  }) async {
    if (files.isEmpty) {
      return UnifiedExportResult.failure(
        const ExportFailure(
          code: ExportFailureCode.emptyInput,
          message: '無檔案內容',
        ),
      );
    }
    try {
      final n = now ?? DateTime.now();
      final folder = _dateFolder(n);
      final root = await _resolveBaseDirectory(folder);
      if (root == null) {
        return UnifiedExportResult.failure(
          const ExportFailure(
            code: ExportFailureCode.noStorageDirectory,
            message: '無法取得儲存目錄',
          ),
        );
      }
      final savedPaths = <String>[];
      if (Platform.isAndroid && testOverrideBaseDir == null) {
        await MediaStore.ensureInitialized();
        MediaStore.appFolder = 'cheemeow_pos';
        final mediaStore = MediaStore();
        for (final e in files.entries) {
          final content = e.value;
          final enc = utf8.encode(content);
          final bytes = addBom ? [0xEF, 0xBB, 0xBF, ...enc] : enc;
          final tmp = await _writeTemp(e.key, bytes);
          try {
            final save = await mediaStore.saveFile(
              tempFilePath: tmp.path,
              dirType: DirType.download,
              dirName: DirName.download,
              relativePath: folder,
            );
            String? path = save?.uri.toString();
            if (path != null) {
              final real = await mediaStore.getFilePathFromUri(uriString: path);
              if (real != null) path = real;
              savedPaths.add(path);
            }
          } finally {
            try {
              await tmp.delete();
            } catch (_) {}
          }
        }
        if (savedPaths.isNotEmpty) {
          return UnifiedExportResult.success(savedPaths);
        }
        return UnifiedExportResult.failure(
          const ExportFailure(
            code: ExportFailureCode.unknown,
            message: 'CSV 檔案全部儲存失敗',
          ),
        );
      } else {
        final dir = Directory(root);
        if (!await dir.exists()) await dir.create(recursive: true);
        for (final e in files.entries) {
          final file = File('${dir.path}/${e.key}');
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {}
          }
          final enc = utf8.encode(e.value);
          final data = addBom ? [0xEF, 0xBB, 0xBF, ...enc] : enc;
          await file.writeAsBytes(data, flush: true);
          savedPaths.add(file.path);
        }
        if (savedPaths.isNotEmpty) {
          return UnifiedExportResult.success(savedPaths);
        }
        return UnifiedExportResult.failure(
          const ExportFailure(
            code: ExportFailureCode.unknown,
            message: 'CSV 檔案未成功寫入',
          ),
        );
      }
    } catch (e, st) {
      final failure = _mapError('[saveCsvFiles]', e, st);
      return UnifiedExportResult.failure(failure);
    }
  }

  Future<File> _writeTemp(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<String?> _resolveBaseDirectory(String dateFolder) async {
    if (testOverrideBaseDir != null) {
      return '${testOverrideBaseDir!}/$dateFolder';
    }
    if (Platform.isAndroid) {
      // MediaStore 真正控制，但仍回報一個推測路徑
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          return '${downloads.path}/cheemeow_pos/$dateFolder';
        }
      } catch (_) {}
      return '/storage/emulated/0/Download/cheemeow_pos/$dateFolder';
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return '${downloads.path}/cheemeow_pos/$dateFolder';
      }
    } catch (_) {}
    try {
      final docs = await getApplicationDocumentsDirectory();
      return '${docs.path}/cheemeow_pos/$dateFolder';
    } catch (_) {}
    return null;
  }

  ExportFailure _mapError(String action, Object e, StackTrace st) {
    AppLogger.e('[ExportService] $action error', e, st);
    if (e is FileSystemException) {
      final osError = e.osError?.errorCode;
      if (osError == 13) {
        return ExportFailure(
          code: ExportFailureCode.permissionDenied,
          message: '沒有存取權限',
          error: e,
          stackTrace: st,
        );
      }
      return ExportFailure(
        code: ExportFailureCode.ioError,
        message: '檔案系統錯誤: ${e.message}',
        error: e,
        stackTrace: st,
      );
    }
    return ExportFailure(
      code: ExportFailureCode.unknown,
      message: '未知錯誤: $e',
      error: e,
      stackTrace: st,
    );
  }
}
