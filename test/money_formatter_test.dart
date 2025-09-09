import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/utils/money_formatter.dart';

void main() {
  test('thousands formatting', () {
    expect(MoneyFormatter.thousands(0), '0');
    expect(MoneyFormatter.thousands(5), '5');
    expect(MoneyFormatter.thousands(123), '123');
    expect(MoneyFormatter.thousands(1234), '1,234');
    expect(MoneyFormatter.thousands(1234567), '1,234,567');
    expect(MoneyFormatter.thousands(-9876543), '-9,876,543');
  });

  test('symbol formatting', () {
    expect(MoneyFormatter.symbol(50), '💲 50');
    expect(MoneyFormatter.symbol(1000), '💲 1,000');
  });
}
