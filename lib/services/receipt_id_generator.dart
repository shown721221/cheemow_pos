import 'time_service.dart';
import '../config/constants.dart';
import '../repositories/receipt_repository.dart';
import '../models/payment_method.dart';

class ReceiptIdGenerator {
  ReceiptIdGenerator._();
  static final instance = ReceiptIdGenerator._();

  Future<String> generate(String paymentMethod, {DateTime? now}) async {
    final DateTime t = now ?? TimeService.now();
    final dayStart = DateTime(t.year, t.month, t.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todays = (await ReceiptRepository.instance.getAll()).where((r) {
      final ts = r.timestamp;
      return !ts.isBefore(dayStart) && ts.isBefore(dayEnd);
    }).toList();
    final seq = todays.length + 1;
    final code = _methodCode(paymentMethod);
    return '$code-${seq.toString().padLeft(3, '0')}';
  }

  Future<String> generateFor(PaymentMethod method, {DateTime? now}) {
    return generate(method.label, now: now);
  }

  String _methodCode(String method) {
    switch (method) {
      case PaymentMethods.cash:
        return '1';
      case '轉帳':
        return '2';
      case 'LinePay':
        return '3';
      default:
        throw ArgumentError('未支援的付款方式: $method');
    }
  }
}
