import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/utils/money_util.dart';

void main() {
  group('MoneyUtil.suggestCashOptions', () {
    test('basic rounding cases', () {
      expect(MoneyUtil.suggestCashOptions(0), []);
      expect(MoneyUtil.suggestCashOptions(1), [50, 100, 500]);
      expect(MoneyUtil.suggestCashOptions(49), [50, 100, 500]);
      expect(MoneyUtil.suggestCashOptions(50), [100, 500, 1000]);
      expect(MoneyUtil.suggestCashOptions(999), [1000, 1500, 2000]);
    });

    test('returns last three unique values greater than total', () {
      final list = MoneyUtil.suggestCashOptions(1234);
      expect(list.length, 3);
      expect(list, [1500, 2000, 3000]);
    });
  });
}
