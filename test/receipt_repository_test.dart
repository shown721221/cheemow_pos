import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/repositories/receipt_repository.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

Receipt build(String id) => Receipt(
  id: id,
  timestamp: DateTime(2025, 1, 1, 10, 0),
  items: const [],
  totalAmount: 100,
  totalQuantity: 1,
  paymentMethod: '現金',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('ReceiptRepository saveAll/getAll/clearAll', () async {
    SharedPreferences.setMockInitialValues({});
    await ReceiptRepository.instance.initialize();
    await ReceiptRepository.instance.clearAll();
    expect(await ReceiptRepository.instance.getAll(), isEmpty);

    final r1 = build('1-001');
    final r2 = build('1-002');
    await ReceiptRepository.instance.saveAll([r1, r2]);

    final all = await ReceiptRepository.instance.getAll();
    expect(all.length, 2);
    expect(all.first.id, '1-001');

    await ReceiptRepository.instance.clearAll();
    expect(await ReceiptRepository.instance.getAll(), isEmpty);
  });
}
