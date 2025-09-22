import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/repositories/product_repository.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ProductRepository', () {
    test('CRUD 基本操作', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = ProductRepository.instance;
      await repo.initialize();
      // 初始可能有資料，先清空存入我們的
      await repo.saveAll([]);
      expect(await repo.getAll(), isEmpty);

      final p1 = Product(id: '1', barcode: 'b1', name: 'N1', price: 100);
      final p2 = Product(id: '2', barcode: 'b2', name: 'N2', price: 200);
      await repo.saveAll([p1, p2]);
      final all = await repo.getAll();
      expect(all.length, 2);

      final byBarcode = await repo.getByBarcode('b2');
      expect(byBarcode?.name, 'N2');

      await repo.updateStock('2', 55);
      final updated = await repo.getAll();
      expect(updated.firstWhere((e) => e.id == '2').stock, 55);
    });
  });
}
