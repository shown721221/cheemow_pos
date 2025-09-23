import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/export_service.dart';

void main() {
  group('ExportService advanced', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('export_service_adv_');
      ExportService.testOverrideBaseDir = tempRoot.path;
    });

    tearDown(() async {
      ExportService.testOverrideBaseDir = null;
      try {
        await tempRoot.delete(recursive: true);
      } catch (_) {}
    });

    test('saveCsvFiles without BOM', () async {
      final fixed = DateTime(2025, 9, 11);
      final res = await ExportService.instance.saveCsvFiles(
        files: {'c.csv': 'a,b\n1,2'},
        addBom: false,
        now: fixed,
      );
      expect(res.success, isTrue);
      final p = res.paths.single;
      final bytes = await File(p).readAsBytes();
      // 不應該有 BOM
      expect(bytes.length, greaterThan(4));
      expect(bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF, isFalse);
      expect(p.contains('2025-09-11'), isTrue);
    });

    test('savePng overwrite existing file', () async {
      final fixed = DateTime(2025, 9, 12, 10, 0, 0);
      final bytes1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final bytes2 = Uint8List.fromList([9, 8, 7]);
      final name = 'x.png';
      final r1 = await ExportService.instance.savePng(
        fileName: name,
        bytes: bytes1,
        now: fixed,
      );
      expect(r1.success, isTrue);
      final path = r1.paths.single;
      final f = File(path);
      expect(await f.readAsBytes(), bytes1);
      final r2 = await ExportService.instance.savePng(
        fileName: name,
        bytes: bytes2,
        now: fixed,
      );
      expect(r2.success, isTrue);
      expect(await f.readAsBytes(), bytes2, reason: 'Should be overwritten');
      expect(path.contains('2025-09-12'), isTrue);
    });

    test(
      'saveCsvFiles multiple ensures date folder present for each path',
      () async {
        final fixed = DateTime(2025, 9, 13);
        final res = await ExportService.instance.saveCsvFiles(
          files: {'a.csv': 'h1,h2\n1,2', 'b.csv': 'x,y\n3,4'},
          now: fixed,
        );
        expect(res.success, isTrue);
        for (final p in res.paths) {
          expect(
            p.contains('2025-09-13'),
            isTrue,
            reason: 'Each file path should include date folder',
          );
          expect(await File(p).exists(), isTrue);
        }
      },
    );
  });
}
