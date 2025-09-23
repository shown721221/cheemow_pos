import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/export_service.dart';

void main() {
  group('ExportService error conditions', () {
    test(
      'failure on empty files map already covered - duplicate guard',
      () async {
        final res = await ExportService.instance.saveCsvFiles(files: {});
        expect(res.success, isFalse);
      },
    );
  });
}
