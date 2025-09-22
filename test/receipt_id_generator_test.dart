import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/receipt_id_generator.dart';
import 'package:cheemeow_pos/repositories/receipt_repository.dart';
import 'package:cheemeow_pos/models/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

Receipt buildReceipt(String id, DateTime ts) => Receipt(
  id: id,
  timestamp: ts,
  items: const [],
  totalAmount: 0,
  totalQuantity: 0,
  paymentMethod: '現金',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('當日序號遞增與跨日重置', () async {
    SharedPreferences.setMockInitialValues({});
    await ReceiptRepository.instance.initialize();
    await ReceiptRepository.instance.clearAll();
    final gen = ReceiptIdGenerator.instance;

    final base = DateTime(2025, 9, 22, 10, 0);
    final id1 = await gen.generate('現金', now: base);
    expect(id1.endsWith('001'), true);
    // 模擬儲存出來
    await ReceiptRepository.instance.saveAll([buildReceipt(id1, base)]);

    final id2 = await gen.generate(
      '現金',
      now: base.add(const Duration(minutes: 5)),
    );
    expect(id2.endsWith('002'), true);

    // 跨日
    final nextDay = base.add(const Duration(days: 1));
    final id3 = await gen.generate('現金', now: nextDay);
    expect(id3.endsWith('001'), true);
  });
}
