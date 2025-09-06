import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/price_display.dart';
import '../widgets/product_list_widget.dart';
import '../widgets/shopping_cart_widget.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/local_database_service.dart';
import '../services/bluetooth_scanner_service.dart';

class PosMainScreen extends StatefulWidget {
  @override
  _PosMainScreenState createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> {
  List<Product> products = [];
  List<CartItem> cartItems = [];
  String lastScannedBarcode = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToBarcodeScanner();
    // 讓畫面可以接收鍵盤輸入（條碼掃描器）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final loadedProducts = await LocalDatabaseService.instance.getProducts();
    setState(() {
      products = loadedProducts;
    });
  }

  void _listenToBarcodeScanner() {
    BluetoothScannerService.instance.barcodeStream.listen((barcode) {
      _onBarcodeScanned(barcode);
    });
  }

  void _onBarcodeScanned(String barcode) async {
    final product = await LocalDatabaseService.instance.getProductByBarcode(
      barcode,
    );
    if (product != null) {
      _addToCart(product);
      setState(() {
        lastScannedBarcode = barcode;
      });
    } else {
      _showProductNotFoundDialog(barcode);
    }
  }

  void _addToCart(Product product) {
    final existingItemIndex = cartItems.indexWhere(
      (item) => item.product.id == product.id,
    );

    setState(() {
      if (existingItemIndex >= 0) {
        cartItems[existingItemIndex].increaseQuantity();
      } else {
        cartItems.add(CartItem(product: product));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      cartItems.removeAt(index);
    });
  }

  void _increaseQuantity(int index) {
    setState(() {
      cartItems[index].increaseQuantity();
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (cartItems[index].quantity > 1) {
        cartItems[index].decreaseQuantity();
      } else {
        cartItems.removeAt(index);
      }
    });
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('找不到商品'),
        content: Text('條碼 $barcode 對應的商品不存在'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
        ],
      ),
    );
  }



  int get totalAmount {
    return cartItems.fold(0, (total, item) => total + item.subtotal);
  }

  int get totalQuantity {
    return cartItems.fold(0, (total, item) => total + item.quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cheemow POS'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: () {
              // TODO: 實作CSV匯入功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('CSV匯入功能開發中')));
            },
            tooltip: '匯入CSV商品資料',
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          // 處理條碼掃描器輸入（通常以Enter結尾）
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            // 這裡可以處理掃描器輸入
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            // 左側：商品列表（60%）
            Expanded(
              flex: 6,
              child: ProductListWidget(
                products: products,
                onProductTap: _addToCart,
              ),
            ),

            // 分隔線
            Container(width: 1, color: Colors.grey[300]),

            // 右側：購物車（40%）
            Expanded(
              flex: 4,
              child: ShoppingCartWidget(
                cartItems: cartItems,
                onRemoveItem: _removeFromCart,
                onIncreaseQuantity: _increaseQuantity,
                onDecreaseQuantity: _decreaseQuantity,
                onClearCart: () {
                  setState(() {
                    cartItems.clear();
                  });
                },
                onCheckout: _checkout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkout() {
    // 簡單的結帳流程
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('結帳確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('商品清單:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...cartItems.map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item.product.name} x${item.quantity}'),
                    ),
                    SmallPriceDisplay(amount: item.subtotal),
                  ],
                ),
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '總計:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                LargePriceDisplay(amount: totalAmount),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                cartItems.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('結帳完成！')));
            },
            child: Text('確認結帳'),
          ),
        ],
      ),
    );
  }
}
