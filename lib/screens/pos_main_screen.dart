import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/price_display.dart';
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

  // 根據庫存數量回傳對應的顏色
  Color _getStockColor(int stock) {
    if (stock > 0) {
      return Colors.green[700]!; // 正數：綠色
    } else if (stock == 0) {
      return Colors.orange[700]!; // 零：橘色
    } else {
      return Colors.red[700]!; // 負數：紅色
    }
  }

  // 根據庫存數量回傳顯示文字
  String _getStockText(int stock) {
    if (stock > 0) {
      return '庫存: $stock';
    } else if (stock == 0) {
      return '庫存: $stock';
    } else {
      return '庫存: $stock'; // 負數也顯示實際數字
    }
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
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '商品列表',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '共 ${products.length} 項商品',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '暫無商品資料',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '請匯入CSV檔案',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        Text(
                                          _getStockText(product.stock),
                                          style: TextStyle(
                                            color: _getStockColor(
                                              product.stock,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        SmallPriceDisplay(
                                          amount: product.price,
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      Icons.add_shopping_cart,
                                      color: Colors.blue,
                                    ),
                                    onTap: () =>
                                        _addToCart(product), // 移除庫存限制，都可以點擊
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // 分隔線
            Container(width: 1, color: Colors.grey[300]),

            // 右側：購物車（40%）
            Expanded(
              flex: 4,
              child: Container(
                padding: EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '購物車',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (cartItems.isNotEmpty)
                          TextButton.icon(
                            icon: Icon(Icons.clear_all, size: 16),
                            label: Text('清空'),
                            onPressed: () {
                              setState(() {
                                cartItems.clear();
                              });
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // 購物車項目
                    Expanded(
                      child: cartItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '購物車是空的',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '點擊商品或掃描條碼新增',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: cartItems.length,
                              itemBuilder: (context, index) {
                                final item = cartItems[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: Dismissible(
                                    key: Key('${item.product.id}_$index'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.only(right: 16),
                                      color: Colors.red,
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onDismissed: (direction) {
                                      _removeFromCart(index);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '已移除 ${item.product.name}',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      title: Text(
                                        item.product.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SmallPriceDisplay(
                                            amount: item.product.price,
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text('小計: '),
                                              SmallPriceDisplay(
                                                amount: item.subtotal,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: Container(
                                        width: 120,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              iconSize: 20,
                                              onPressed: () =>
                                                  _decreaseQuantity(index),
                                              icon: Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                            ),
                                            Container(
                                              width: 30,
                                              child: Text(
                                                '${item.quantity}',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              iconSize: 20,
                                              onPressed: () =>
                                                  _increaseQuantity(index),
                                              icon: Icon(
                                                Icons.add_circle_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // 底部統計和結帳
                    if (cartItems.isNotEmpty) ...[
                      Divider(thickness: 2),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('商品數量:', style: TextStyle(fontSize: 16)),
                                Text(
                                  '$totalQuantity 件',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '總金額:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                LargePriceDisplay(amount: totalAmount),
                              ],
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _checkout,
                                icon: Icon(Icons.payment),
                                label: Text(
                                  '結帳',
                                  style: TextStyle(fontSize: 18),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
