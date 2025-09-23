import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/payment_compute.dart';
import 'package:cheemeow_pos/config/constants.dart';

void main() {
  group('PaymentCompute.evaluate', () {
    test('cash empty input = exact total, change 0, canConfirm true', () {
      final r = PaymentCompute.evaluate(
        method: PaymentMethods.cash,
        totalAmount: 500,
        rawInput: '',
      );
      expect(r.effectivePaid, 500);
      expect(r.change, 0);
      expect(r.canConfirm, true);
    });

    test('cash insufficient input -> negative change & cannot confirm', () {
      final r = PaymentCompute.evaluate(
        method: PaymentMethods.cash,
        totalAmount: 500,
        rawInput: '300',
      );
      expect(r.effectivePaid, 300);
      expect(r.change, -200);
      expect(r.canConfirm, false);
    });

    test('cash exact input -> change 0 confirm ok', () {
      final r = PaymentCompute.evaluate(
        method: PaymentMethods.cash,
        totalAmount: 500,
        rawInput: '500',
      );
      expect(r.effectivePaid, 500);
      expect(r.change, 0);
      expect(r.canConfirm, true);
    });

    test('cash over input -> positive change confirm ok', () {
      final r = PaymentCompute.evaluate(
        method: PaymentMethods.cash,
        totalAmount: 500,
        rawInput: '800',
      );
      expect(r.effectivePaid, 800);
      expect(r.change, 300);
      expect(r.canConfirm, true);
    });

    test(
      'non-cash ignores rawInput empty => effectivePaid = 0, change 0, canConfirm true',
      () {
        final r = PaymentCompute.evaluate(
          method: PaymentMethods.transfer,
          totalAmount: 500,
          rawInput: '',
        );
        expect(r.effectivePaid, 0);
        expect(r.change, 0);
        expect(r.canConfirm, true);
      },
    );
  });
}
