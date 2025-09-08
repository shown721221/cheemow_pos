import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/product_list_widget.dart';
import '../widgets/shopping_cart_widget.dart';
import '../dialogs/payment_dialog.dart';
import '../services/receipt_service.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/receipt.dart';
import '../services/local_database_service.dart';
import '../services/bluetooth_scanner_service.dart';
import '../services/csv_import_service.dart';
import '../managers/keyboard_scanner_manager.dart';
import '../dialogs/price_input_dialog_manager.dart';
import '../utils/product_sort_utils.dart';
import '../dialogs/dialog_manager.dart';
import '../config/app_config.dart';

class PosMainScreen extends StatefulWidget {
  const PosMainScreen({super.key});

  @override
  State<PosMainScreen> createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> {
  List<Product> products = [];
  List<CartItem> cartItems = [];
  String lastScannedBarcode = '';
  KeyboardScannerManager? _kbScanner;
  bool _shouldScrollToTop = false;
  int _currentPageIndex = 0; // 0: 銷售頁面, 1: 搜尋頁面
  String _searchQuery = '';
  List<Product> _searchResults = [];
  final List<String> _selectedFilters = []; // 選中的篩選條件

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToBarcodeScanner();
    // 使用鍵盤掃描管理器，集中處理條碼鍵盤事件
    _kbScanner = KeyboardScannerManager(onBarcodeScanned: _onBarcodeScanned);
    ServicesBinding.instance.keyboard.addHandler(_kbScanner!.handleKeyEvent);
  }

  @override
  void dispose() {
    // 移除鍵盤掃描管理器監聽
    if (_kbScanner != null) {
      ServicesBinding.instance.keyboard.removeHandler(
        _kbScanner!.handleKeyEvent,
      );
      _kbScanner!.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    // 確保特殊商品存在
    await LocalDatabaseService.instance.ensureSpecialProducts();

    final loadedProducts = await LocalDatabaseService.instance.getProducts();

    final sorted = ProductSortUtils.sortProducts(loadedProducts);

    setState(() {
      products = sorted;
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
    if (!mounted) return;
    if (product != null) {
      _addToCart(product);
      setState(() {
        lastScannedBarcode = barcode;
      });
    } else {
      // 統一改用 DialogManager 提示
      DialogManager.showProductNotFound(context, barcode);
    }
  }

  void _addToCart(Product product) async {
    // 特殊商品（價格為 0）需要輸入實際價格
    if (product.price == 0) {
      final inputPrice = await PriceInputDialogManager.showCustomNumberInput(
        context,
        product,
        totalAmount,
      );
      if (inputPrice != null) {
        _addProductToCart(product, inputPrice);
      }
    } else {
      _addProductToCart(product, product.price);
    }
  }

  // 插入商品到購物車（頂部），若同品且同價已存在則數量+1並移至頂部
  void _addProductToCart(Product product, int actualPrice) {
    // 若實際售價不同，需要建立臨時商品副本
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

    final existingIndex = cartItems.indexWhere(
      (item) =>
          item.product.id == productToAdd.id &&
          item.product.price == actualPrice,
    );

    setState(() {
      if (existingIndex >= 0) {
        final existing = cartItems.removeAt(existingIndex);
        existing.increaseQuantity();
        cartItems.insert(0, existing);
      } else {
        cartItems.insert(0, CartItem(product: productToAdd));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (index >= 0 && index < cartItems.length) {
        cartItems.removeAt(index);
      }
    });
  }

  //（已移除）手動加減數量功能

  // 本地未使用：找不到商品改由 DialogManager 管理

  int get totalAmount {
    return cartItems.fold(0, (total, item) => total + item.subtotal);
  }

  int get totalQuantity {
    return cartItems.fold(0, (total, item) => total + item.quantity);
  }

  /// CSV匯入功能
  Future<void> _importCsvData() async {
    // 匯入前的簡單數字密碼確認，預設 0000
    final bool confirmed = await _confirmImportWithPin();
    if (!confirmed) return;

    // 顯示 loading
    if (!mounted) return;
    DialogManager.showLoading(context, message: '匯入中...');

    try {
      final result = await CsvImportService.importFromFile();

      // 關閉 loading
      if (!mounted) return;
      DialogManager.hideLoading(context);

      if (result.cancelled) {
        return; // 使用者取消，不顯示任何訊息
      }

      if (result.success) {
        // 重新載入商品資料
        await _loadProducts();
        if (!mounted) return;

        // 顯示匯入結果
        DialogManager.showImportResult(context, result);
      } else {
        // 顯示錯誤訊息
        DialogManager.showError(context, '匯入失敗', result.errorMessage ?? '未知錯誤');
      }
    } catch (e) {
      // 關閉 loading
      if (!mounted) return;
      DialogManager.hideLoading(context);
      DialogManager.showError(context, '匯入失敗', e.toString());
    }
  }

  /// 匯入前 PIN 確認（四位數字，預設 0000）
  Future<bool> _confirmImportWithPin() async {
    final pin = AppConfig.csvImportPin;
    String input = '';
    String? error;
    bool ok = false;

    await showDialog(
      context: context,
      barrierDismissible: true, // 點擊外部即取消
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setS) {
            Widget buildNumKey(String number) => SizedBox(
              width: 72,
              height: 60,
              child: ElevatedButton(
                onPressed: input.length < 4
                    ? () => setS(() {
                        input += number;
                        error = null;
                        if (input.length == 4) {
                          if (input == pin) {
                            ok = true;
                            Navigator.pop(context);
                          } else {
                            error = '密碼錯誤，請再試一次';
                          }
                        }
                      })
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );

            Widget buildActionKey(String label, VoidCallback onPressed) =>
                SizedBox(
                  width: 72,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[50],
                      foregroundColor: Colors.orange[700],
                    ),
                    child: Text(label, style: const TextStyle(fontSize: 18)),
                  ),
                );

            String masked = '••••'.substring(0, input.length).padRight(4, '—');

            return AlertDialog(
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 保留說明：覆蓋警告與輸入提示（移除標題文字）
                    Text(
                      '⚠️ 這會覆蓋所有商品資料',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('✨ 請輸入奇妙數字 ✨', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: Text(
                        masked,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // 數字鍵盤
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildNumKey('1'),
                        buildNumKey('2'),
                        buildNumKey('3'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildNumKey('4'),
                        buildNumKey('5'),
                        buildNumKey('6'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildNumKey('7'),
                        buildNumKey('8'),
                        buildNumKey('9'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        buildActionKey(
                          '🧹',
                          () => setS(() {
                            input = '';
                            error = null;
                          }),
                        ),
                        buildNumKey('0'),
                        buildActionKey(
                          '⌫',
                          () => setS(() {
                            if (input.isNotEmpty) {
                              input = input.substring(0, input.length - 1);
                            }
                            error = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return ok;
  }

  // 對話框統一改用 DialogManager，移除本地自建實作

  // CSV 格式說明已統一由 DialogManager.showCsvFormatHelp(context) 處理

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
                  DialogManager.showComingSoon(context, '匯出功能');
                  break;
                case 'receipts':
                  DialogManager.showComingSoon(context, '收據清單');
                  break;
                case 'revenue':
                  DialogManager.showComingSoon(context, '營收總計');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: [
                    Text('🧸', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('上架寶貝們'),
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
                                    Text(
                                      '🛒',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: _currentPageIndex == 0
                                            ? Colors.blue
                                            : Colors.black54,
                                      ),
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
                                    Text(
                                      '🔎',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: _currentPageIndex == 1
                                            ? Colors.blue
                                            : Colors.black54,
                                      ),
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

  void _checkout() async {
    // 直接進入付款方式（極簡流程）
    // 結帳前最終把關：折扣不可大於非折扣商品總額
    final int nonDiscountTotal = cartItems
        .where((item) => !item.product.isDiscountProduct)
        .fold<int>(0, (sum, item) => sum + item.subtotal);
    final int discountAbsTotal = cartItems
        .where((item) => item.product.isDiscountProduct)
        .fold<int>(
          0,
          (sum, item) =>
              sum + (item.subtotal < 0 ? -item.subtotal : item.subtotal),
        );

    if (discountAbsTotal > nonDiscountTotal) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('折扣超過上限'),
          content: Text(
            '折扣金額 ($discountAbsTotal 元) 不能大於目前購物車商品總金額 ($nonDiscountTotal 元)。\n請調整折扣或商品數量後再試。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('確定'),
            ),
          ],
        ),
      );
      return; // 阻止結帳
    }

    final payment = await PaymentDialog.show(context, totalAmount: totalAmount);
    if (!mounted) return;
    if (payment == null) return; // 取消付款

    // 在清空購物車前拍下快照，用於建立收據
    final itemsSnapshot = List<CartItem>.from(cartItems);
    // 記錄購物車商品數量
    final checkedOutCount = itemsSnapshot.length;
    await _processCheckout();
    if (!mounted) return;

    // 建立並儲存收據
    final receipt = Receipt.fromCart(
      itemsSnapshot,
    ).copyWith(paymentMethod: payment.method);
    await ReceiptService.instance.saveReceipt(receipt);
    if (!mounted) return;

    // 顯示結帳完成
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payment.method == '現金'
              ? '結帳完成（${payment.method}）。找零 NT\$${payment.change}，已更新 $checkedOutCount 個商品排序'
              : '結帳完成（${payment.method}），已更新 $checkedOutCount 個商品排序',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _processCheckout() async {
    final checkoutTime = DateTime.now();

    // 記錄結帳品項數量（以條碼統計）
    final Map<String, int> quantityByBarcode = {};
    for (final item in cartItems) {
      quantityByBarcode.update(
        item.product.barcode,
        (prev) => prev + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }

    debugPrint('結帳數量統計: $quantityByBarcode');

    // 創建新的商品列表，更新結帳時間
    final updatedProducts = <Product>[];
    int updatedCount = 0;

    for (final product in products) {
      final qty = quantityByBarcode[product.barcode] ?? 0;
      if (qty > 0) {
        // 結帳過的商品：更新結帳時間與庫存（特殊商品不扣庫存）
        final newStock = product.isSpecialProduct
            ? product.stock
            : (product.stock - qty);
        final updatedProduct = Product(
          id: product.id,
          barcode: product.barcode,
          name: product.name,
          price: product.price,
          category: product.category,
          stock: newStock,
          isActive: product.isActive,
          lastCheckoutTime: checkoutTime,
        );
        updatedProducts.add(updatedProduct);
        updatedCount++;
        debugPrint(
          '更新商品: ${product.name} (${product.barcode}) -> 結帳時間: $checkoutTime, 庫存: ${product.stock} -> $newStock (扣 $qty)',
        );
      } else {
        // 其他商品保持原狀
        updatedProducts.add(product);
      }
    }

    debugPrint('實際更新了 $updatedCount 個商品');

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

    // 儲存更新後商品
    await LocalDatabaseService.instance.saveProducts(updatedProducts);

    setState(() {
      // 清空購物車
      cartItems.clear();
      // 更新產品列表（這會觸發重新排序和回到頂部）
      products = updatedProducts;

      // 若目前左側使用的是搜尋/篩選結果，將其以條碼對映為最新的商品資料，以避免顯示舊庫存
      if (_searchResults.isNotEmpty) {
        final Map<String, Product> latestByBarcode = {
          for (final p in updatedProducts) p.barcode: p,
        };
        _searchResults = _searchResults
            .map((old) => latestByBarcode[old.barcode] ?? old)
            .toList();
      }
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

    debugPrint('結帳完成，商品列表已更新，實際更新: $updatedCount 個商品');
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
                !name.contains('tokyo')) {
              return false;
            }
            break;
          case '上海':
            if (!name.contains('上海disney限定') &&
                !name.contains('上海迪士尼限定') &&
                !name.contains('上海disney') &&
                !name.contains('上海迪士尼') &&
                !name.contains('shanghai')) {
              return false;
            }
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
            if (!name.contains('duffy') && !name.contains('達菲')) {
              return false;
            }
            break;
          case 'Gelatoni':
            if (!name.contains('gelatoni') && !name.contains('傑拉托尼')) {
              return false;
            }
            break;
          case 'OluMel':
            if (!name.contains('olumel') && !name.contains('歐嚕')) {
              return false;
            }
            break;
          case 'ShellieMay':
            if (!name.contains('shelliemay') && !name.contains('雪莉玫')) {
              return false;
            }
            break;
          case 'StellaLou':
            if (!name.contains('stellalou') &&
                !name.contains('星黛露') &&
                !name.contains('史黛拉露')) {
              return false;
            }
            break;
          case 'CookieAnn':
            if (!name.contains('cookieann') &&
                !name.contains('可琦安') &&
                !name.contains('cookie')) {
              return false;
            }
            break;
          case 'LinaBell':
            if (!name.contains('linabell') &&
                !name.contains('玲娜貝兒') &&
                !name.contains('貝兒')) {
              return false;
            }
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
                name.contains('貝兒')) {
              return false;
            }
            break;
          case '娃娃':
            if (!name.contains('娃娃')) {
              return false;
            }
            break;
          case '站姿':
            if (!name.contains('站姿')) {
              return false;
            }
            break;
          case '坐姿':
            if (!name.contains('坐姿')) {
              return false;
            }
            break;
          case '其他吊飾':
            // 必須包含"吊飾"關鍵字，但不能包含"站姿"、"坐姿"
            if (!name.contains('吊飾')) {
              return false;
            }
            if (name.contains('站姿') || name.contains('坐姿')) {
              return false;
            }
            break;
          case '有庫存':
            if (product.stock <= 0) {
              return false;
            }
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('找到 ${filteredProducts.length} 項商品'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 敬請期待改由 DialogManager.showComingSoon(context, featureName) 統一處理

  Future<void> _saveProductsToStorage() async {
    try {
      await LocalDatabaseService.instance.saveProducts(products);
    } catch (e) {
      debugPrint('保存商品資料失敗: $e');
    }
  }

  //（已移除）場次功能不使用
}
