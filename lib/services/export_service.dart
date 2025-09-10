import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

class ExportResult {
  final bool success;
  final List<String> paths;
  final String? error;
  ExportResult({required this.success, this.paths = const [], this.error});
  factory ExportResult.failure(String msg) =>
      ExportResult(success: false, error: msg);
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static String? testOverrideBaseDir; // 測試覆寫

  String _dateFolder(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  Future<ExportResult> savePng({
    required String fileName,
    required Uint8List bytes,
    DateTime? now,
  }) async {
    try {
      final n = now ?? DateTime.now();
      final folder = _dateFolder(n);
      final root = await _resolveBaseDirectory(folder);
      if (root == null) return ExportResult.failure('無法取得儲存目錄');
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
          return ExportResult(
            success: path != null,
            paths: path != null ? [path] : const [],
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
        return ExportResult(success: true, paths: [file.path]);
      }
    } catch (e, st) {
      debugPrint('[ExportService][savePng] error: $e\n$st');
      return ExportResult.failure(e.toString());
    }
  }

  Future<ExportResult> saveCsvFiles({
    required Map<String, String> files,
    bool addBom = true,
    DateTime? now,
  }) async {
    if (files.isEmpty) return ExportResult.failure('無檔案內容');
    try {
      final n = now ?? DateTime.now();
      final folder = _dateFolder(n);
      final root = await _resolveBaseDirectory(folder);
      if (root == null) return ExportResult.failure('無法取得儲存目錄');
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
        return ExportResult(success: savedPaths.isNotEmpty, paths: savedPaths);
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
        return ExportResult(success: savedPaths.isNotEmpty, paths: savedPaths);
      }
    } catch (e, st) {
      debugPrint('[ExportService][saveCsvFiles] error: $e\n$st');
      return ExportResult.failure(e.toString());
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
}
