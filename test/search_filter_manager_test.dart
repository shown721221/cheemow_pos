import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/managers/search_filter_manager.dart';

void main() {
  group('SearchFilterManager', () {
    final manager = SearchFilterManager();

    final products = [
      Product(id: 'p1', barcode: '0001', name: '東京Disney限定 Duffy 娃娃 站姿', price: 100, stock: 3),
      Product(id: 'p2', barcode: '0002', name: '上海迪士尼限定 LinaBell 吊飾', price: 120, stock: 0),
      Product(id: 'p3', barcode: '0003', name: '香港 Disney CookieAnn 坐姿 娃娃', price: 150, stock: 2),
      Product(id: 'p4', barcode: '0004', name: '其他角色 可愛吊飾', price: 80, stock: 5),
      // 特殊商品（預購、折扣）也應在前
      Product(id: 'pre', barcode: '19920203', name: '預購 任何', price: 0, stock: 0),
      Product(id: 'disc', barcode: '88888888', name: '祝您有奇妙的一天 折扣', price: 0, stock: 0),
    ];

    test('search: empty query returns empty list; basic name/barcode matching', () {
      expect(manager.search(products, ''), isEmpty);
      expect(manager.search(products, '0001').map((p) => p.id), containsAll(['p1']));
      expect(manager.search(products, 'duffy').map((p) => p.id), containsAll(['p1']));
    });

    test('toggleFilter: mutual exclusive groups', () {
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
      selected = manager.toggleFilter(selected, '坐姿');
      expect(selected, contains('坐姿'));
      expect(selected, isNot(contains('娃娃')));
    });

  test('filter: combines text terms and filters; respects stock filter', () {
      // 文本搜尋 + 角色 + 類型 + 有庫存
      final selected = ['CookieAnn', '坐姿', '有庫存'];
  final result = manager.filter(products, selected, searchQuery: '香港');
  // 僅 p3 符合（香港 + CookieAnn + 坐姿 + 有庫存）
  expect(result.map((p) => p.id), ['p3']);
    });
  });
}
