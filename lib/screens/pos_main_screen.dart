import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/price_display.dart';
import '../widgets/product_list_widget.dart';
import '../widgets/shopping_cart_widget.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/local_database_service.dart';
import '../services/bluetooth_scanner_service.dart';
import '../services/csv_import_service.dart';

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
    
    // 對商品進行排序：特殊商品在最前面
    loadedProducts.sort((a, b) {
      // 如果 a 是特殊商品而 b 不是，a 排在前面
      if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
      // 如果 b 是特殊商品而 a 不是，b 排在前面
      if (b.isSpecialProduct && !a.isSpecialProduct) return 1;
      
      // 兩個都是特殊商品時，預約商品排在折扣商品前面
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
      }
      
      // 其他情況按商品名稱排序
      return a.name.compareTo(b.name);
    });
    
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

  void _addToCart(Product product) async {
    // 如果是特殊商品（價格為0），需要手動輸入價格
    if (product.price == 0) {
      await _showPriceInputDialog(product);
    } else {
      _addProductToCart(product, product.price);
    }
  }

  Future<void> _showPriceInputDialog(Product product) async {
    final TextEditingController priceController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('輸入價格'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('商品：${product.name}'),
              SizedBox(height: 8),
              if (product.isPreOrderProduct) 
                Text(
                  '這是預購商品，請輸入實際價格',
                  style: TextStyle(color: Colors.purple[700], fontSize: 12),
                )
              else if (product.isDiscountProduct)
                Text(
                  '這是折扣商品，請輸入折扣金額（負數）',
                  style: TextStyle(color: Colors.orange[700], fontSize: 12),
                ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: product.isDiscountProduct ? '折扣金額' : '價格',
                  prefixText: 'NT\$ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('確定'),
              onPressed: () {
                final priceText = priceController.text.trim();
                if (priceText.isNotEmpty) {
                  final price = int.tryParse(priceText);
                  if (price != null) {
                    Navigator.of(context).pop();
                    _addProductToCart(product, price);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('請輸入有效的數字')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('請輸入價格')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _addProductToCart(Product product, int actualPrice) {
    // 如果實際價格與商品原價不同，創建一個新的商品物件
    final productToAdd = actualPrice != product.price 
        ? Product(
            id: product.id,
            barcode: product.barcode,
            name: product.name,
            price: actualPrice,
            category: product.category,
            stock: product.stock,
            isActive: product.isActive,
          )
        : product;

    final existingItemIndex = cartItems.indexWhere(
      (item) => item.product.id == productToAdd.id && item.product.price == actualPrice,
    );

    setState(() {
      if (existingItemIndex >= 0) {
        cartItems[existingItemIndex].increaseQuantity();
      } else {
        cartItems.add(CartItem(product: productToAdd));
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

  /// CSV匯入功能
  Future<void> _importCsvData() async {
    // 顯示loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await CsvImportService.importFromFile();
      
      // 關閉loading
      Navigator.pop(context);
      
      if (result.cancelled) {
        return; // 使用者取消，不顯示任何訊息
      }
      
      if (result.success) {
        // 重新載入商品資料
        await _loadProducts();
        
        // 顯示匯入結果
        _showImportResultDialog(result);
      } else {
        // 顯示錯誤訊息
        _showErrorDialog('匯入失敗', result.errorMessage ?? '未知錯誤');
      }
    } catch (e) {
      // 關閉loading
      Navigator.pop(context);
      _showErrorDialog('匯入失敗', e.toString());
    }
  }

  /// 顯示匯入結果對話框
  void _showImportResultDialog(CsvImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.hasErrors ? Icons.warning : Icons.check_circle,
              color: result.hasErrors ? Colors.orange : Colors.green,
            ),
            SizedBox(width: 8),
            Text('匯入完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('檔案：${result.fileName}'),
            SizedBox(height: 8),
            Text(result.statusMessage),
            if (result.hasErrors) ...[
              SizedBox(height: 16),
              Text(
                '錯誤詳情：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                height: 150,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    itemCount: result.errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        result.errors[index],
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
          if (result.hasErrors)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCsvFormatHelp();
              },
              child: Text('查看格式說明'),
            ),
        ],
      ),
    );
  }

  /// 顯示錯誤對話框
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCsvFormatHelp();
            },
            child: Text('查看格式說明'),
          ),
        ],
      ),
    );
  }

  /// 顯示CSV格式說明
  void _showCsvFormatHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('CSV格式說明'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CSV檔案格式要求：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. 第一行必須是標頭：id,barcode,name,price,category,stock'),
              Text('2. 每一行代表一個商品'),
              Text('3. 欄位說明：'),
              Text('   • id: 商品唯一識別碼'),
              Text('   • barcode: 商品條碼'),
              Text('   • name: 商品名稱'),
              Text('   • price: 價格（整數，單位：台幣元）'),
              Text('   • category: 商品分類'),
              Text('   • stock: 庫存數量（整數）'),
              SizedBox(height: 16),
              Text(
                '範例：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  CsvImportService.generateSampleCsv(),
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
        ],
      ),
    );
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
            onPressed: _importCsvData,
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
