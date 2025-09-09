import 'package:flutter_test/flutter_test.dart';
import 'package:cheemow_pos/controllers/pos_cart_controller.dart';
import 'package:cheemow_pos/models/product.dart';
import 'package:cheemow_pos/models/cart_item.dart';

void main() {
  group('PosCartController', () {
    late List<CartItem> items;
    late PosCartController controller;
    late Product base;

    setUp(() {
      items = [];
      controller = PosCartController(items);
      base = Product(
        id: 'p1',
        barcode: '123',
        name: '商品A',
        price: 100,
        stock: 10,
      );
    });

    test('新增第一個商品', () {
      controller.addProduct(base, 100);
      expect(items.length, 1);
      expect(items.first.quantity, 1);
      expect(controller.totalAmount, 100);
    });

    test('同價同商品數量累加並移到頂部', () {
      controller.addProduct(base, 100);
      controller.addProduct(base, 100);
      expect(items.length, 1);
      expect(items.first.quantity, 2);
    });

    test('不同價格同商品視為不同項', () {
      controller.addProduct(base, 100);
      controller.addProduct(base, 120);
      expect(items.length, 2);
      expect(items[0].product.price, 120); // 新的在頂部
      expect(items[1].product.price, 100);
    });

    test('折扣商品（負金額）可以被加入並計算總額', () {
      controller.addProduct(base, -30);
      expect(controller.totalAmount, -30);
      expect(items.first.product.price, -30);
    });
  });
}
