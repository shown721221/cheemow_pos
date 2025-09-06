import 'dart:async';
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
  String _scanBuffer = '';
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToBarcodeScanner();
    
    // 使用系統級鍵盤監聽，避免焦點問題
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    // 移除系統級鍵盤監聽器
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    _scanTimer?.cancel();
    super.dispose();
  }

  /// 系統級鍵盤事件處理器
  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Enter鍵：處理完整的條碼
        if (_scanBuffer.isNotEmpty) {
          _onBarcodeScanned(_scanBuffer.trim());
          _scanBuffer = '';
          _scanTimer?.cancel();
        }
        return true;
      } else {
        // 其他按鍵：累積到緩衝區，但限制只處理可見字符
        final char = event.character;
        if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
          _scanBuffer += char;

          // 重置計時器：1秒內沒有新輸入就清空緩衝區
          _scanTimer?.cancel();
          _scanTimer = Timer(Duration(seconds: 1), () {
            _scanBuffer = '';
          });
        }
        return true;
      }
    }
    return false;
  }

  Future<void> _loadProducts() async {
    // 確保特殊商品存在
    await LocalDatabaseService.instance.ensureSpecialProducts();

    final loadedProducts = await LocalDatabaseService.instance.getProducts();

    // 對商品進行排序：
    // 1. 特殊商品在最前面（預約商品 > 折扣商品）
    // 2. 其他商品按最後結帳時間排序（最近結帳的在前）
    loadedProducts.sort((a, b) {
      // 如果 a 是特殊商品而 b 不是，a 排在前面
      if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
      // 如果 b 是特殊商品而 a 不是，b 排在前面
      if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

      // 兩個都是特殊商品時，預約商品排在折扣商品前面
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0; // 兩個特殊商品相同類型時順序不變
      }

      // 兩個都是普通商品時，按最後結帳時間排序
      if (a.lastCheckoutTime != null && b.lastCheckoutTime != null) {
        // 最近結帳的在前面（降序）
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      } else if (a.lastCheckoutTime != null) {
        // a 有結帳記錄，b 沒有，a 排在前面
        return -1;
      } else if (b.lastCheckoutTime != null) {
        // b 有結帳記錄，a 沒有，b 排在前面
        return 1;
      }

      // 兩個都沒有結帳記錄，按商品名稱排序
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
                  '這是折扣商品，輸入金額會自動轉為負數',
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
                  var price = int.tryParse(priceText);
                  if (price != null) {
                    // 如果是折扣商品（祝您有奇妙的一天），自動轉為負數
                    if (product.isDiscountProduct && price > 0) {
                      price = -price;
                    }
                    Navigator.of(context).pop();
                    _addProductToCart(product, price);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('請輸入有效的數字')));
                  }
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('請輸入價格')));
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
            lastCheckoutTime: product.lastCheckoutTime,
          )
        : product;

    final existingItemIndex = cartItems.indexWhere(
      (item) =>
          item.product.id == productToAdd.id &&
          item.product.price == actualPrice,
    );

    setState(() {
      if (existingItemIndex >= 0) {
        // 如果商品已存在，增加數量並移到頂部
        final existingItem = cartItems.removeAt(existingItemIndex);
        existingItem.increaseQuantity();
        cartItems.insert(0, existingItem);
      } else {
        // 新商品插入到頂部（索引0）
        cartItems.insert(0, CartItem(product: productToAdd));
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
      // 移除該項目，增加數量後插入到頂部
      final item = cartItems.removeAt(index);
      item.increaseQuantity();
      cartItems.insert(0, item);
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
              Text('錯誤詳情：', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('CSV檔案格式要求：', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Text('範例：', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Cheemow POS'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            tooltip: '功能選單',
            onSelected: (String value) {
              switch (value) {
                case 'import':
                  _importCsvData();
                  break;
                case 'export':
                  _showComingSoonDialog('匯出功能');
                  break;
                case 'receipts':
                  _showComingSoonDialog('收據清單');
                  break;
                case 'revenue':
                  _showComingSoonDialog('營收總計');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, size: 20),
                    SizedBox(width: 8),
                    Text('匯入商品資料'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('匯出商品資料'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'receipts',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20),
                    SizedBox(width: 8),
                    Text('收據清單'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'revenue',
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 20),
                    SizedBox(width: 8),
                    Text('營收總計'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
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
            onPressed: () async {
              // 在處理結帳前記錄購物車商品數量
              final checkedOutCount = cartItems.length;
              await _processCheckout();
              Navigator.pop(context);

              // 顯示結帳完成的訊息，包含更新的商品數量
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('結帳完成！已更新 $checkedOutCount 個商品的排序'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: Text('確認結帳'),
          ),
        ],
      ),
    );
  }

  Future<void> _processCheckout() async {
    final checkoutTime = DateTime.now();

    // 記錄結帳的商品條碼，用於更新商品排序（使用條碼更準確）
    final checkedOutBarcodes = cartItems
        .map((item) => item.product.barcode)
        .toSet();

    print('結帳商品條碼: $checkedOutBarcodes'); // 除錯訊息

    // 創建新的商品列表，更新結帳時間
    final updatedProducts = <Product>[];
    int updatedCount = 0;

    for (final product in products) {
      if (checkedOutBarcodes.contains(product.barcode)) {
        // 結帳過的商品，更新結帳時間
        final updatedProduct = product.copyWithLastCheckoutTime(checkoutTime);
        updatedProducts.add(updatedProduct);
        updatedCount++;
        print(
          '更新商品: ${product.name} (${product.barcode}) -> 結帳時間: $checkoutTime',
        ); // 除錯訊息
      } else {
        // 其他商品保持原狀
        updatedProducts.add(product);
      }
    }

    print('實際更新了 $updatedCount 個商品'); // 除錯訊息

    // 重新排序商品
    updatedProducts.sort((a, b) {
      // 特殊商品始終在最前面
      if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
      if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

      // 兩個都是特殊商品時，預約商品排在折扣商品前面
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0;
      }

      // 兩個都是普通商品時，按最後結帳時間排序
      if (a.lastCheckoutTime != null && b.lastCheckoutTime != null) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      } else if (a.lastCheckoutTime != null) {
        return -1;
      } else if (b.lastCheckoutTime != null) {
        return 1;
      }

      // 兩個都沒有結帳記錄，按商品名稱排序
      return a.name.compareTo(b.name);
    });

    setState(() {
      // 清空購物車
      cartItems.clear();
      // 更新產品列表（這會觸發重新排序和回到頂部）
      products = updatedProducts;
    });

    // 保存更新後的商品資料到本地存儲
    await _saveProductsToStorage();

    print('結帳完成，商品列表已更新，實際更新: $updatedCount 個商品'); // 除錯訊息
  }

  /// 顯示敬請期待對話框
  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.construction, color: Colors.orange),
            SizedBox(width: 8),
            Text('敬請期待'),
          ],
        ),
        content: Text('$featureName 功能正在開發中，敬請期待！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('確定'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProductsToStorage() async {
    try {
      await LocalDatabaseService.instance.saveProducts(products);
    } catch (e) {
      print('保存商品資料失敗: $e');
    }
  }
}
