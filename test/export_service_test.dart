import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/export_service.dart';

void main() {
  group('ExportService', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('export_service_test_');
      ExportService.testOverrideBaseDir =
          tempRoot.path; // 讓路徑可預測 & 不觸發 MediaStore
    });

    tearDown(() async {
      ExportService.testOverrideBaseDir = null;
      try {
        if (await tempRoot.exists()) {
          await tempRoot.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('saveCsvFiles success with BOM & multiple files', () async {
      final fixedDate = DateTime(2025, 9, 10);
      final res = await ExportService.instance.saveCsvFiles(
        files: {'a.csv': 'col1,col2\n1,2', 'b.csv': 'x,y\n3,4'},
        addBom: true,
        now: fixedDate,
      );
      expect(res.success, isTrue);
      expect(res.paths.length, 2);
      for (final p in res.paths) {
        final f = File(p);
        expect(await f.exists(), isTrue, reason: 'File should exist: $p');
        final bytes = await f.readAsBytes();
        // BOM 檢查
        expect(bytes.length, greaterThan(3));
        expect(bytes[0], 0xEF);
        expect(bytes[1], 0xBB);
        expect(bytes[2], 0xBF);
      }
      final dateFolder = '2025-09-10';
      for (final p in res.paths) {
        expect(p.contains(dateFolder), isTrue);
      }
    });

    test('saveCsvFiles failure when empty map', () async {
      final res = await ExportService.instance.saveCsvFiles(files: {});
      expect(res.success, isFalse);
      expect(res.failure, isNotNull);
      expect(res.failure!.message, contains('無檔案內容'));
    });

    test('savePng writes file and returns path', () async {
      final fixedDate = DateTime(2025, 9, 10, 12, 0, 0);
      // 最小 PNG (1x1 透明) header + IHDR + IDAT + IEND (可簡化，只要能寫出即可)
      final pngBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
        // 剩餘放一些 bytes 即可（測試不驗證結構，只驗證寫入）
        0x00, 0x00, 0x00, 0x00,
      ]);
      final res = await ExportService.instance.savePng(
        fileName: 'test.png',
        bytes: pngBytes,
        now: fixedDate,
      );
      expect(res.success, isTrue);
      expect(res.paths.length, 1);
      final path = res.paths.first;
      final f = File(path);
      expect(await f.exists(), isTrue);
      final saved = await f.readAsBytes();
      expect(saved, isNotEmpty);
      expect(path.contains('2025-09-10'), isTrue);
    });
  });
}
