import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/services/csv_import_service.dart';

void main() {
  group('CsvImportService.parseForTest', () {
    test('header mismatch reports error', () async {
      const badHeader = 'foo,bar,baz\n1,2,3';
      final res = await CsvImportService.parseForTest(badHeader);
      expect(res.success, isFalse);
      expect(res.errorMessage, contains('CSV'));
    });

    test('duplicate id and barcode are reported', () async {
      const csv =
          'id,barcode,name,price,category,stock\n'
          'A,111,n1,10,c,1\n'
          'A,111,n2,20,c,2';
      final res = await CsvImportService.parseForTest(csv);
      expect(res.success, isTrue);
      expect(res.errors.join('\n'), contains('ID'));
      expect(res.errors.join('\n'), contains('條碼'));
    });

    test('empty file is error', () async {
      final res = await CsvImportService.parseForTest('');
      expect(res.success, isFalse);
    });
  });
}
