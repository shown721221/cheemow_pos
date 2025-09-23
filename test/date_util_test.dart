import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/date_util.dart';

void main() {
  group('DateUtil', () {
    test('ymd formats with zero padding', () {
      final dt = DateTime(2025, 1, 9);
      expect(DateUtil.ymd(dt), '2025-01-09');
    });

    test('ymdCompact formats two-digit year', () {
      final dt = DateTime(2025, 12, 31);
      expect(DateUtil.ymdCompact(dt), '251231');
    });

    test('ymdCompact leading zeros', () {
      final dt = DateTime(2024, 3, 7);
      expect(DateUtil.ymdCompact(dt), '240307');
    });

    // 新增：閏年 2024-02-29
    test('ymd handles leap day 2024-02-29', () {
      final dt = DateTime(2024, 2, 29);
      expect(DateUtil.ymd(dt), '2024-02-29');
      expect(DateUtil.ymdCompact(dt), '240229');
    });

    // 新增：2100 不是閏年，確保 3/1 正常
    test('ymd handles non-leap century 2100-03-01', () {
      final dt = DateTime(2100, 3, 1);
      expect(DateUtil.ymd(dt), '2100-03-01');
      expect(DateUtil.ymdCompact(dt), '000301');
    });
  });
}
