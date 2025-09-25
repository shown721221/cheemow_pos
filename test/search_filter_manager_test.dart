import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/managers/search_filter_manager.dart';

void main() {
  group('SearchFilterManager', () {
    final manager = SearchFilterManager();

    final products = [
      Product(id: 'p1', barcode: '0001', name: '東京Disney限定 Duffy 娃娃 站姿', price: 100, stock: 3),
      Product(id: 'p2', barcode: '0002', name: '上海迪士尼限定 LinaBell 站姿吊飾', price: 120, stock: 0),
      Product(id: 'p3', barcode: '0003', name: '香港 Disney CookieAnn 坐姿 娃娃', price: 150, stock: 2),
      Product(id: 'p4', barcode: '0004', name: '其他角色 可愛吊飾', price: 80, stock: 5),
      Product(id: 'p5', barcode: '0005', name: '限量 OluMel 坐姿吊飾', price: 90, stock: 1),
      Product(id: 'pre', barcode: '19920203', name: '預購 任何', price: 0, stock: 0),
      Product(id: 'disc', barcode: '88888888', name: '祝您有奇妙的一天 折扣', price: 0, stock: 0),
    ];

    test('search: empty query returns empty list; basic name/barcode matching', () {
      expect(manager.search(products, ''), isEmpty);
      expect(manager.search(products, '0001').map((p) => p.id), containsAll(['p1']));
      expect(manager.search(products, 'duffy').map((p) => p.id), containsAll(['p1']));
    });

    test('toggleFilter: mutual exclusive groups (with multi types)', () {
      var selected = <String>[];
      selected = manager.toggleFilter(selected, '東京');
      selected = manager.toggleFilter(selected, '上海');
      expect(selected, contains('上海'));
      expect(selected, isNot(contains('東京')));

      selected = manager.toggleFilter(selected, 'Duffy');
      selected = manager.toggleFilter(selected, 'LinaBell');
      expect(selected, contains('LinaBell'));
      expect(selected, isNot(contains('Duffy')));

      selected = manager.toggleFilter(selected, '娃娃');
      selected = manager.toggleFilter(selected, '坐姿吊飾');
      expect(selected, contains('坐姿吊飾'));
      expect(selected, isNot(contains('娃娃')));

      // 多選類型
      selected = manager.toggleFilter(selected, '站姿吊飾');
      expect(selected, containsAll(['站姿吊飾', '坐姿吊飾']));
      selected = manager.toggleFilter(selected, '其他吊飾');
      expect(selected, containsAll(['站姿吊飾', '坐姿吊飾', '其他吊飾']));
      // 再次點擊移除
      selected = manager.toggleFilter(selected, '站姿吊飾');
      expect(selected, isNot(contains('站姿吊飾')));
    });

    test('filter: combines text terms and filters; respects stock filter', () {
      final selected = ['CookieAnn', '坐姿吊飾', '有庫存'];
      final result = manager.filter(products, selected, searchQuery: '香港');
      expect(result.map((p) => p.id), ['p3']);
    });

    test('multi selectable types OR logic', () {
      final selected = ['站姿吊飾', '其他吊飾'];
      final result = manager.filter(products, selected);
      // 應包含：p2(站姿吊飾) p4(吊飾) p5(坐姿吊飾不在選擇中) → 不含 p5
      expect(result.map((p) => p.id).toSet(), containsAll({'p2', 'p4'}));
      expect(result.map((p) => p.id), isNot(contains('p5')));

      final selected2 = ['站姿吊飾', '坐姿吊飾'];
      final result2 = manager.filter(products, selected2);
      // 應包含：p2(站姿吊飾), p5(坐姿吊飾); p4(僅吊飾未選其他吊飾) 不應出現
      expect(result2.map((p) => p.id).toSet(), containsAll({'p2', 'p5'}));
      expect(result2.map((p) => p.id), isNot(contains('p4')));
    });
  });
}
