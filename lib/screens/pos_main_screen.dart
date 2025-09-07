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
  bool _shouldScrollToTop = false;
  int _currentPageIndex = 0; // 0: 銷售頁面, 1: 搜尋頁面
  String _searchQuery = '';
  List<Product> _searchResults = [];
  List<String> _selectedFilters = []; // 選中的篩選條件

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
      await _showCustomNumberInputDialog(product);
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

  /// 顯示自定義數字鍵盤輸入對話框
  Future<void> _showCustomNumberInputDialog(Product product) async {
    String currentPrice = '';

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 商品名稱（不含標籤）
                    Text(
                      '${product.name}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    if (product.isPreOrderProduct)
                      Text(
                        '這是預購商品，請輸入實際價格',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontSize: 12,
                        ),
                      )
                    else if (product.isDiscountProduct)
                      Text(
                        '這是折扣商品，輸入金額會自動轉為負數',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    SizedBox(height: 16),

                    // 價格顯示
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Text(
                        'NT\$ ${currentPrice.isEmpty ? "0" : currentPrice}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: product.isDiscountProduct
                              ? Colors.orange[700]
                              : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 16),

                    // 數字鍵盤
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumKey(
                              '1',
                              () => setState(() => currentPrice += '1'),
                            ),
                            _buildNumKey(
                              '2',
                              () => setState(() => currentPrice += '2'),
                            ),
                            _buildNumKey(
                              '3',
                              () => setState(() => currentPrice += '3'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumKey(
                              '4',
                              () => setState(() => currentPrice += '4'),
                            ),
                            _buildNumKey(
                              '5',
                              () => setState(() => currentPrice += '5'),
                            ),
                            _buildNumKey(
                              '6',
                              () => setState(() => currentPrice += '6'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNumKey(
                              '7',
                              () => setState(() => currentPrice += '7'),
                            ),
                            _buildNumKey(
                              '8',
                              () => setState(() => currentPrice += '8'),
                            ),
                            _buildNumKey(
                              '9',
                              () => setState(() => currentPrice += '9'),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionKey(
                              '清除',
                              () => setState(() => currentPrice = ''),
                            ),
                            _buildNumKey(
                              '0',
                              () => setState(() => currentPrice += '0'),
                            ),
                            _buildActionKey(
                              '刪除',
                              () => setState(() {
                                if (currentPrice.isNotEmpty) {
                                  currentPrice = currentPrice.substring(
                                    0,
                                    currentPrice.length - 1,
                                  );
                                }
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('取消'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('確定'),
                  onPressed: currentPrice.isEmpty
                      ? null
                      : () {
                          var price = int.tryParse(currentPrice);
                          if (price != null && price > 0) {
                            // 如果是折扣商品，檢查折扣金額不能大於目前購物車總金額
                            if (product.isDiscountProduct) {
                              final currentTotal = totalAmount;
                              if (price > currentTotal) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '折扣金額 ($price 元) 不能大於目前購物車總金額 ($currentTotal 元)',
                                    ),
                                    backgroundColor: Colors.orange[600],
                                  ),
                                );
                                return;
                              }
                              price = -price;
                            }
                            Navigator.of(context).pop();
                            _addProductToCart(product, price);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNumKey(String number, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          number,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[700],
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label, style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[50],
          foregroundColor: Colors.orange[700],
        ),
      ),
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
      resizeToAvoidBottomInset: false, // 防止鍵盤影響佈局
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
            // 左側：商品列表和搜尋頁面（60%）
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  // 分頁標籤
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _currentPageIndex = 0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _currentPageIndex == 0
                                    ? Colors.blue[50]
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: _currentPageIndex == 0
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart,
                                      size: 18,
                                      color: _currentPageIndex == 0
                                          ? Colors.blue
                                          : Colors.black54,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '銷售',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: _currentPageIndex == 0
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _currentPageIndex == 0
                                            ? Colors.blue
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _currentPageIndex = 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _currentPageIndex == 1
                                    ? Colors.blue[50]
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: _currentPageIndex == 1
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 18,
                                      color: _currentPageIndex == 1
                                          ? Colors.blue
                                          : Colors.black54,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '搜尋',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: _currentPageIndex == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _currentPageIndex == 1
                                            ? Colors.blue
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 頁面內容
                  Expanded(
                    child: _currentPageIndex == 0
                        ? ProductListWidget(
                            products: _searchResults.isNotEmpty
                                ? _searchResults
                                : products,
                            onProductTap: _addToCart,
                            shouldScrollToTop: _shouldScrollToTop,
                          )
                        : _buildSearchPage(),
                  ),
                ],
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
      // 設置滾動到頂部標記
      _shouldScrollToTop = true;
    });

    // 立即重置滾動標記
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _shouldScrollToTop = false;
      });
    });

    // 保存更新後的商品資料到本地存儲
    await _saveProductsToStorage();

    print('結帳完成，商品列表已更新，實際更新: $updatedCount 個商品'); // 除錯訊息
  }

  /// 建構搜尋頁面
  Widget _buildSearchPage() {
    return Column(
      children: [
        // 搜尋輸入框
        Container(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜尋奇妙寶貝',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: _performSearch,
          ),
        ),
        // 快速篩選按鈕區域
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SizedBox(height: 4), // 減少頂部間距
                // 第一排：地區
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('東京')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('上海')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('香港')),
                    ],
                  ),
                ),
                SizedBox(height: 4), // 減少間距
                // 第二排：角色1
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('Duffy')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('Gelatoni')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('OluMel')),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                // 第三排：角色2
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('ShellieMay')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('StellaLou')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('CookieAnn')),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                // 第四排：角色3與類型
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('LinaBell')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('其他角色')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('娃娃')),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                // 第五排：姿勢
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('站姿')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('坐姿')),
                      SizedBox(width: 8),
                      Expanded(child: _buildFilterButton('其他吊飾')),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                // 第六排：特殊功能
                Flexible(
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterButton('有庫存')),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterButton('重選', isSpecial: true),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterButton('確認', isSpecial: true),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4), // 底部小間距
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 執行搜尋
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
      if (_searchQuery.isEmpty) {
        _searchResults = [];
        return;
      }

      // 搜尋商品名稱或條碼
      _searchResults = products.where((product) {
        final name = product.name.toLowerCase();
        final barcode = product.barcode.toLowerCase();
        final searchLower = _searchQuery.toLowerCase();

        return name.contains(searchLower) || barcode.contains(searchLower);
      }).toList();

      // 搜尋結果排序：特殊商品優先，然後按相關性
      _searchResults.sort((a, b) {
        // 特殊商品始終在最前面
        if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
        if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

        // 兩個都是特殊商品時，預約商品排在折扣商品前面
        if (a.isSpecialProduct && b.isSpecialProduct) {
          if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
          if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
          return 0;
        }

        // 普通商品按名稱排序
        return a.name.compareTo(b.name);
      });
    });
  }

  /// 建構篩選按鈕
  Widget _buildFilterButton(String label, {bool isSpecial = false}) {
    final isSelected = _selectedFilters.contains(label);

    Color backgroundColor;
    Color textColor;

    if (isSpecial) {
      // 特殊按鈕（重選、確認）
      if (label == '重選') {
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
      } else {
        // 確認
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
      }
    } else {
      // 普通篩選按鈕
      backgroundColor = isSelected ? Colors.blue[100]! : Colors.grey[100]!;
      textColor = isSelected ? Colors.blue[700]! : Colors.grey[700]!;
    }

    return GestureDetector(
      onTap: () => _onFilterButtonTap(label),
      child: Container(
        height: 70, // 固定高度 70px
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 檢查地區按鈕是否應該被禁用
  /// 處理篩選按鈕點擊
  void _onFilterButtonTap(String label) {
    setState(() {
      if (label == '重選') {
        // 清除所有篩選條件
        _selectedFilters.clear();
        _searchQuery = '';
        _searchResults = [];
      } else if (label == '確認') {
        // 如果是篩選結果描述，清除搜尋文字以進行純篩選
        if (_searchQuery.startsWith('篩選結果')) {
          _searchQuery = '';
        }

        // 執行篩選並切換到銷售頁面
        _applyFiltersWithTextSearch();
        _currentPageIndex = 0; // 切換到銷售頁面
      } else {
        // 定義互斥群組
        const locationGroup = ['東京', '上海', '香港'];
        const characterGroup = [
          'Duffy',
          'Gelatoni',
          'OluMel',
          'ShellieMay',
          'StellaLou',
          'CookieAnn',
          'LinaBell',
          '其他角色',
        ];
        const typeGroup = ['娃娃', '站姿', '坐姿', '其他吊飾'];

        // 處理互斥邏輯
        if (locationGroup.contains(label)) {
          _handleMutualExclusiveGroup(locationGroup, label);
        } else if (characterGroup.contains(label)) {
          _handleMutualExclusiveGroup(characterGroup, label);
        } else if (typeGroup.contains(label)) {
          _handleMutualExclusiveGroup(typeGroup, label);
        } else {
          // 其他按鈕（如有庫存）的正常切換邏輯
          if (_selectedFilters.contains(label)) {
            _selectedFilters.remove(label);
          } else {
            _selectedFilters.add(label);
          }
        }
      }
    });
  }

  /// 處理互斥群組的邏輯
  void _handleMutualExclusiveGroup(List<String> group, String label) {
    // 移除同群組的其他選項
    _selectedFilters.removeWhere(
      (filter) => group.contains(filter) && filter != label,
    );

    // 切換當前選項
    if (_selectedFilters.contains(label)) {
      _selectedFilters.remove(label);
    } else {
      _selectedFilters.add(label);
    }
  }

  /// 應用篩選條件
  /// 應用篩選條件並結合文字搜尋
  void _applyFiltersWithTextSearch() {
    List<Product> filteredProducts = products.where((product) {
      final name = product.name.toLowerCase();

      // 如果有文字搜尋，先進行文字過濾
      if (_searchQuery.isNotEmpty) {
        final searchTerms = _searchQuery
            .toLowerCase()
            .split(' ')
            .where((term) => term.isNotEmpty);
        bool matchesSearch = false;
        for (String term in searchTerms) {
          if (name.contains(term) || product.barcode.contains(term)) {
            matchesSearch = true;
            break;
          }
        }
        if (!matchesSearch) return false;
      }

      // 然後應用篩選條件
      for (String filter in _selectedFilters) {
        switch (filter) {
          case '東京':
            if (!name.contains('東京disney限定') &&
                !name.contains('東京迪士尼限定') &&
                !name.contains('東京disney') &&
                !name.contains('東京迪士尼') &&
                !name.contains('tokyo'))
              return false;
            break;
          case '上海':
            if (!name.contains('上海disney限定') &&
                !name.contains('上海迪士尼限定') &&
                !name.contains('上海disney') &&
                !name.contains('上海迪士尼') &&
                !name.contains('shanghai'))
              return false;
            break;
          case '香港':
            bool matchesHongKong =
                name.contains('香港disney限定') ||
                name.contains('香港迪士尼限定') ||
                name.contains('香港disney') ||
                name.contains('香港迪士尼') ||
                name.contains('hongkong') ||
                name.contains('hk');
            if (!matchesHongKong) {
              return false;
            }
            break;
          case 'Duffy':
            if (!name.contains('duffy') && !name.contains('達菲')) return false;
            break;
          case 'Gelatoni':
            if (!name.contains('gelatoni') && !name.contains('傑拉托尼'))
              return false;
            break;
          case 'OluMel':
            if (!name.contains('olumel') && !name.contains('歐嚕')) return false;
            break;
          case 'ShellieMay':
            if (!name.contains('shelliemay') && !name.contains('雪莉玫'))
              return false;
            break;
          case 'StellaLou':
            if (!name.contains('stellalou') &&
                !name.contains('星黛露') &&
                !name.contains('史黛拉露'))
              return false;
            break;
          case 'CookieAnn':
            if (!name.contains('cookieann') &&
                !name.contains('可琦安') &&
                !name.contains('cookie'))
              return false;
            break;
          case 'LinaBell':
            if (!name.contains('linabell') &&
                !name.contains('玲娜貝兒') &&
                !name.contains('貝兒'))
              return false;
            break;
          case '其他角色':
            // 如果包含任何已知角色名稱，則不是其他角色
            if (name.contains('duffy') ||
                name.contains('達菲') ||
                name.contains('gelatoni') ||
                name.contains('傑拉托尼') ||
                name.contains('olumel') ||
                name.contains('歐嚕') ||
                name.contains('shelliemay') ||
                name.contains('雪莉玫') ||
                name.contains('stellalou') ||
                name.contains('星黛露') ||
                name.contains('史黛拉露') ||
                name.contains('cookieann') ||
                name.contains('可琦安') ||
                name.contains('cookie') ||
                name.contains('linabell') ||
                name.contains('玲娜貝兒') ||
                name.contains('貝兒'))
              return false;
            break;
          case '娃娃':
            if (!name.contains('娃娃')) return false;
            break;
          case '站姿':
            if (!name.contains('站姿')) return false;
            break;
          case '坐姿':
            if (!name.contains('坐姿')) return false;
            break;
          case '其他吊飾':
            // 必須包含"吊飾"關鍵字，但不能包含"站姿"、"坐姿"
            if (!name.contains('吊飾')) return false;
            if (name.contains('站姿') || name.contains('坐姿')) return false;
            break;
          case '有庫存':
            if (product.stock <= 0) return false;
            break;
        }
      }
      return true;
    }).toList();

    // 排序篩選結果
    filteredProducts.sort((a, b) {
      // 特殊商品始終在最前面
      if (a.isSpecialProduct && !b.isSpecialProduct) return -1;
      if (b.isSpecialProduct && !a.isSpecialProduct) return 1;

      // 兩個都是特殊商品時，預約商品排在折扣商品前面
      if (a.isSpecialProduct && b.isSpecialProduct) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return 0;
      }

      // 普通商品按名稱排序
      return a.name.compareTo(b.name);
    });

    setState(() {
      _searchResults = filteredProducts;
      _searchQuery = '篩選結果 (${_selectedFilters.join(', ')})';
    });

    // 顯示搜尋結果通知
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('找到 ${filteredProducts.length} 項商品'),
        duration: Duration(seconds: 2),
      ),
    );
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
