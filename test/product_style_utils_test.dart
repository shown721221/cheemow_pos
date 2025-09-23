import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_style_utils.dart';
import 'package:cheemeow_pos/models/product.dart';
import 'package:cheemeow_pos/config/constants.dart';

Product _p({
  bool preorder = false,
  bool discount = false,
  int stock = 5,
}) {
  final barcode = preorder
      ? AppConstants.barcodePreOrder
      : discount
          ? AppConstants.barcodeDiscount
          : 'NORMAL_${preorder ? 'P' : discount ? 'D' : 'N'}';
  return Product(
    id: 'id_$barcode',
    barcode: barcode,
    name: 'N',
    price: discount ? -10 : 100,
    category: 'c',
    stock: stock,
    lastCheckoutTime: null,
  );
}

void main() {
  group('ProductStyleUtils', () {
    test('getProductNameColor preorder/discount distinct', () {
      final preColor = ProductStyleUtils.getProductNameColor(_p(preorder: true));
      final discColor = ProductStyleUtils.getProductNameColor(_p(discount: true));
      expect(preColor != discColor, true);
    });

    test('stock color positive/zero/negative', () {
      final pos = ProductStyleUtils.getStockColor(3);
      final zero = ProductStyleUtils.getStockColor(0);
      final neg = ProductStyleUtils.getStockColor(-2);
      expect(pos != zero && zero != neg && pos != neg, true);
    });
  });
}
