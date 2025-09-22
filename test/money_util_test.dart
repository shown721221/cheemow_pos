import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/money_util.dart';

void main() {
  group('MoneyUtil.suggestCashOptions', () {
    test('basic rounding cases', () {
      expect(MoneyUtil.suggestCashOptions(0), []);
      expect(MoneyUtil.suggestCashOptions(1), [50, 100, 500]);
      expect(MoneyUtil.suggestCashOptions(49), [50, 100, 500]);
      expect(MoneyUtil.suggestCashOptions(50), [100, 500, 1000]);
      expect(MoneyUtil.suggestCashOptions(999), [1000]);
    });

    test('mid range 1234 gives 1300,1500,2000', () {
      final list = MoneyUtil.suggestCashOptions(1234);
      expect(list.length, 3);
      expect(list, [1300, 1500, 2000]);
    });

    test('1150 gives 1200,1500,2000', () {
      expect(MoneyUtil.suggestCashOptions(1150), [1200, 1500, 2000]);
    });

    test('1499 gives 1500,2000 only (no 3000)', () {
      expect(MoneyUtil.suggestCashOptions(1499), [1500, 2000]);
    });

    test('gives 3200, 3500, 4000 when total=3160', () {
      expect(MoneyUtil.suggestCashOptions(3160), [3200, 3500, 4000]);
    });

    test('stops at thousand step and returns only two when total=2690', () {
      final list = MoneyUtil.suggestCashOptions(2690);
      expect(list, [2700, 3000]);
      expect(list.length, 2);
    });

    test('2500 only shows 3000 (no 2500 itself)', () {
      expect(MoneyUtil.suggestCashOptions(2500), [3000]);
    });

    test('under 1000 prefers 50/100/500 till first 1000', () {
      expect(MoneyUtil.suggestCashOptions(920), [950, 1000]);
      expect(MoneyUtil.suggestCashOptions(999), [1000]);
    });

    test('thousand multiples have no quick options', () {
      expect(MoneyUtil.suggestCashOptions(1000), []);
      expect(MoneyUtil.suggestCashOptions(2000), []);
      expect(MoneyUtil.suggestCashOptions(3000), []);
    });
  });
}
