import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path/path.dart' as p;
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
import '../dialogs/dialog_manager.dart';
import '../config/app_config.dart';
import 'receipt_list_screen.dart';

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

    // 開發用途：可用 dart-define 控制啟動時自動匯出今日營收圖片
    // 例如：flutter run -d <device> --dart-define=EXPORT_REVENUE_ON_START=true
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAutoExportRevenueOnStart(),
    );

    // 安排跨日零用金自動重置檢查（每天 00:00）
    _scheduleMidnightPettyCashReset();
  }

  void _scheduleMidnightPettyCashReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);
    // 單次計時，觸發後再排下一次（避免累積 Timer）
    Timer(duration, () async {
      await AppConfig.resetPettyCashIfNewDay();
      if (!mounted) return;
      setState(() {}); // 重新繪製顯示（選單顯示零用金等）
      // 再排下一次
      _scheduleMidnightPettyCashReset();
    });
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

  void _maybeAutoExportRevenueOnStart() {
    const auto = bool.fromEnvironment('EXPORT_REVENUE_ON_START');
    if (!auto) return;
    if (!mounted) return;
    () async {
      final ok = await _exportTodayRevenueImage();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? '啟動自動匯出營收完成' : '啟動自動匯出營收失敗')));
    }();
  }

  Future<void> _loadProducts() async {
    // 確保特殊商品存在
    await LocalDatabaseService.instance.ensureSpecialProducts();

    final loadedProducts = await LocalDatabaseService.instance.getProducts();
    final sorted = _sortProductsDaily(loadedProducts);
    setState(() { products = sorted; });
  }

  // 每日排序：今日有售出的商品 (lastCheckoutTime 為今日) 置頂；
  // 特殊商品永遠最前（預購在折扣前），再來今日售出的普通商品（依時間新→舊），
  // 其餘按名稱。
  List<Product> _sortProductsDaily(List<Product> list) {
    final now = DateTime.now();
    bool isToday(DateTime? dt) => dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final sorted = [...list];
    sorted.sort((a, b) {
      final aSpecial = a.isSpecialProduct;
      final bSpecial = b.isSpecialProduct;
      if (aSpecial && !bSpecial) return -1;
      if (bSpecial && !aSpecial) return 1;
      if (aSpecial && bSpecial) {
        if (a.isPreOrderProduct && b.isDiscountProduct) return -1;
        if (a.isDiscountProduct && b.isPreOrderProduct) return 1;
        return a.name.compareTo(b.name);
      }
      final aToday = isToday(a.lastCheckoutTime);
      final bToday = isToday(b.lastCheckoutTime);
      if (aToday && !bToday) return -1;
      if (bToday && !aToday) return 1;
      if (aToday && bToday) {
        return b.lastCheckoutTime!.compareTo(a.lastCheckoutTime!);
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
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
    // 1) 判斷購物車內是否已存在相同商品且相同價格的項目
    final existingIndex = cartItems.indexWhere(
      (item) =>
          item.product.id == product.id && item.product.price == actualPrice,
    );

    // 2) 若存在：數量 +1 並移至頂部
    if (existingIndex >= 0) {
      setState(() {
        cartItems[existingIndex].increaseQuantity();
        final item = cartItems.removeAt(existingIndex);
        cartItems.insert(0, item);
      });
      return;
    }

    // 3) 若不存在：建立商品（若價格不同，建立臨時副本），插入頂部
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

    setState(() {
      cartItems.insert(0, CartItem(product: productToAdd, quantity: 1));
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

  // 移除購物車指定索引的項目
  void _removeFromCart(int index) {
    setState(() {
      if (index >= 0 && index < cartItems.length) {
        cartItems.removeAt(index);
      }
    });
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
                    const Text(
                      '✨ 請輸入奇妙數字 ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
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
            onSelected: (String value) async {
              switch (value) {
                case 'import':
                  _importCsvData();
                  break;
                case 'receipts':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReceiptListScreen(),
                    ),
                  ).then((_) => _loadProducts());
                  break;
                case 'revenue':
                  await _exportTodayRevenueImage();
                  break;
                case 'popularity':
                  await _exportTodayPopularityImage();
                  break;
                case 'pettycash':
                  await _showSetPettyCashDialog();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'import',
                child: Row(
                  children: const [
                    Text('🧸', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('上架寶貝們'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: const [
                    Text('📤', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('匯出商品資料'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'receipts',
                child: Row(
                  children: const [
                    Text('🧾', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('收據清單'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'revenue',
                child: Row(
                  children: const [
                    Text('🌤️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('闆娘心情指數'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'popularity',
                child: Row(
                  children: const [
                    Text('📈', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('寶寶人氣指數'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pettycash',
                child: Row(
                  children: const [
                    Text('💰', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('設定零用金'),
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

  // 匯出今日營收圖（含：總營收、預購小計、折扣小計、三種付款方式小計）
  Future<bool> _exportTodayRevenueImage() async {
    try {
      final receipts = await ReceiptService.instance.getTodayReceipts();
      // 彙總金額
      int total = 0;
      int preorder = 0;
      int discount = 0;
      int cash = 0;
      int transfer = 0;
      int linepay = 0;

      for (final r in receipts) {
        total += r.totalAmount; // 已排除退貨
        switch (r.paymentMethod) {
          case '現金':
            cash += r.totalAmount;
            break;
          case '轉帳':
            transfer += r.totalAmount;
            break;
          case 'LinePay':
            linepay += r.totalAmount;
            break;
        }
        final refunded = r.refundedProductIds.toSet();
        for (final it in r.items) {
          if (refunded.contains(it.product.id)) continue;
          if (it.product.isPreOrderProduct) {
            preorder += it.subtotal;
          } else if (it.product.isDiscountProduct) {
            discount += it.subtotal;
          }
        }
      }

      // 建立可愛繽紛的圖像 Widget（統一卡片樣式）
      final now = DateTime.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final dateStr = '$y-$m-$d';

      // captureKey 用於不可見的「未遮蔽」版本擷取；預覽不使用 key
      final captureKey = GlobalKey();

      final tsHeadline = const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
      );
      final tsSectionLabel = const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      );
      final tsMetricValueLg = const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
      );
      final tsMetricValue = const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );
      // final tsChipValue = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600); // reserved for future chips
      // metric card
      Widget metricCard({
        required String icon,
        required String title,
        required String value,
        required Color bg,
        Color? valueColor,
        bool large = false,
      }) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: (large ? tsMetricValueLg : tsMetricValue).copyWith(
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        );
      }

      Widget revenueWidget({required bool showNumbers, Key? key}) {
        String money(int v) {
          final s = v.toString();
          final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
          final withComma = s.replaceAllMapped(reg, (m) => ',');
          return withComma; // 去除 NT$ 前綴
        }

        Color bg1 = const Color(0xFFFFF0F6); // 粉
        Color bg2 = const Color(0xFFE8F5FF); // 淡藍
        Color bg3 = const Color(0xFFEFFFF2); // 淡綠
        Color bg4 = const Color(0xFFFFF9E6); // 淡黃

        String mask(int v) => showNumbers ? money(v) : '💰';

        return RepaintBoundary(
          key: key,
          child: Container(
            width: 800,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('🌈 今日營收', style: tsHeadline),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (AppConfig.pettyCash > 0) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '零用金 💲' + AppConfig.pettyCash.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text('總營收', style: tsSectionLabel),
                      const Spacer(),
                      Text(
                        mask(total),
                        style: tsHeadline.copyWith(color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: metricCard(
                        icon: '💵',
                        title: '現金',
                        value: mask(cash),
                        bg: bg3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '🔁',
                        title: '轉帳',
                        value: mask(transfer),
                        bg: bg4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '📲',
                        title: 'LinePay',
                        value: mask(linepay),
                        bg: bg2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: metricCard(
                        icon: '🧸',
                        title: '預購小計',
                        value: mask(preorder),
                        bg: bg1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '✨',
                        title: '折扣小計',
                        value: mask(discount),
                        bg: const Color(0xFFFFEEF0),
                        valueColor: Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'cheemow POS',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 顯示唯一一個預覽視窗（預設隱藏數字；點擊可切換顯示）
      if (mounted) {
        bool previewShowNumbers = false; // 放在外層，避免 StatefulBuilder 重建時被重設
        // ignore: unawaited_futures
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (ctx, cons) => ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 720,
                        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          previewShowNumbers = !previewShowNumbers;
                          setLocal(() {});
                        },
                        child: revenueWidget(showNumbers: previewShowNumbers),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

      // 插入透明 Overlay，渲染「未遮蔽」版本做擷取，不影響使用者看到的預覽
      OverlayEntry? captureEntry;
      if (!mounted) return false;
      final overlayState = Overlay.of(context, rootOverlay: true);
      captureEntry = OverlayEntry(
        builder: (ctx) => IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.01,
              child: Material(
                color: Colors.transparent,
                child: revenueWidget(showNumbers: true, key: captureKey),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(captureEntry);

      // 等待 1~2 個 frame 確保完成繪製
      await Future.delayed(const Duration(milliseconds: 16));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 16));

      // 擷取圖片
      late final Uint8List bytes;
      try {
        final renderObj = captureKey.currentContext?.findRenderObject();
        if (renderObj is! RenderRepaintBoundary) {
          await Future.delayed(const Duration(milliseconds: 32));
          final ro2 = captureKey.currentContext?.findRenderObject();
          if (ro2 is! RenderRepaintBoundary) {
            throw Exception('尚未完成渲染，請重試');
          }
          final img2 = await ro2.toImage(pixelRatio: 3.0);
          final bd2 = await img2.toByteData(format: ui.ImageByteFormat.png);
          bytes = bd2!.buffer.asUint8List();
        } else {
          final image = await renderObj.toImage(pixelRatio: 3.0);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          bytes = byteData!.buffer.asUint8List();
        }
      } finally {
        try {
          captureEntry.remove();
        } catch (_) {}
      }

      // 準備檔名
      final yy = (now.year % 100).toString().padLeft(2, '0');
      final fileName = '營收_$yy$m$d.png';
      // Android 的 MediaStore 需要一個暫存檔供複製
      File? tempPngFile;
      if (Platform.isAndroid) {
        final tmp = await getTemporaryDirectory();
        tempPngFile = File('${tmp.path}/$fileName');
        try {
          await tempPngFile.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }

      // 下載（Android: Downloads/cheemow_pos/{dateStr}；桌面也建立同樣層級）
      File? easyFile;
      String? savedPublicPath;
      if (Platform.isAndroid) {
        try {
          await MediaStore.ensureInitialized();
          final mediaStore = MediaStore();
          MediaStore.appFolder = 'cheemow_pos';
          // ---- 淨空同日重複檔 (含 (1)(2)... ) 以避免再產生編號 ----
          try {
            final baseNameNoExt = fileName.substring(
              0,
              fileName.length - 4,
            ); // 去掉 .png
            for (int i = 0; i < 8; i++) {
              final candidate = i == 0 ? fileName : '${baseNameNoExt} ($i).png';
              final deleted = await mediaStore.deleteFile(
                fileName: candidate,
                dirType: DirType.download,
                dirName: DirName.download,
                relativePath: dateStr,
              );
              if (deleted) {
                // ignore: avoid_print
                print('[RevenueExport] pre-clean deleted: $candidate');
              }
            }
          } catch (e) {
            // ignore: avoid_print
            print('[RevenueExport] pre-clean error: $e');
          }
          // 先檢查是否存在 -> 存在則用 editFile 覆寫，不存在則 saveFile
          final existingUri = await mediaStore.getFileUri(
            fileName: fileName,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: dateStr,
          );
          if (existingUri != null) {
            final tmpFile = tempPngFile; // promote for non-null access
            if (tmpFile == null) throw Exception('temp file missing');
            // 直接覆寫內容
            final ok = await mediaStore.editFile(
              uriString: existingUri.toString(),
              tempFilePath: tmpFile.path,
            );
            if (ok) {
              savedPublicPath = await mediaStore.getFilePathFromUri(
                uriString: existingUri.toString(),
              );
              // ignore: avoid_print
              print('[RevenueExport] edited existing file: $savedPublicPath');
            } else {
              // 覆寫失敗：嘗試刪除再重新建立
              // ignore: avoid_print
              print('[RevenueExport] editFile failed, fallback delete+save');
              try {
                await mediaStore.deleteFile(
                  fileName: fileName,
                  dirType: DirType.download,
                  dirName: DirName.download,
                  relativePath: dateStr,
                );
              } catch (e) {
                // ignore: avoid_print
                print('[RevenueExport] delete old file failed: $e');
              }
              final saveInfo = await mediaStore.saveFile(
                tempFilePath: tmpFile.path,
                dirType: DirType.download,
                dirName: DirName.download,
                relativePath: dateStr,
              );
              savedPublicPath = saveInfo?.uri.toString();
              if (saveInfo != null) {
                if (saveInfo.isDuplicated) {
                  // ignore: avoid_print
                  print('[RevenueExport] duplicated created: ${saveInfo.name}');
                }
              }
              if (savedPublicPath != null) {
                final pReal = await mediaStore.getFilePathFromUri(
                  uriString: savedPublicPath,
                );
                if (pReal != null) savedPublicPath = pReal;
              }
            }
          } else {
            final tmpFile = tempPngFile; // promote
            if (tmpFile == null) throw Exception('temp file missing');
            final saveInfo = await mediaStore.saveFile(
              tempFilePath: tmpFile.path,
              dirType: DirType.download,
              dirName: DirName.download,
              // 使用日期子資料夾與人氣指數一致
              relativePath: dateStr,
            );
            if (saveInfo != null && saveInfo.isDuplicated) {
              // 理論上第一次不應 duplicated，若發生記錄
              // ignore: avoid_print
              print(
                '[RevenueExport] unexpected duplicated on first save: ${saveInfo.name}',
              );
            }
            savedPublicPath = saveInfo?.uri.toString();
            if (savedPublicPath != null) {
              final pReal = await mediaStore.getFilePathFromUri(
                uriString: savedPublicPath,
              );
              if (pReal != null) savedPublicPath = pReal;
            }
            // ignore: avoid_print
            print('[RevenueExport] created new file: $savedPublicPath');
          }
        } catch (e) {
          // ignore: avoid_print
          print('[RevenueExport] save to public Downloads failed: $e');
        }
        try {
          await tempPngFile?.delete();
        } catch (_) {}
      } else {
        String? downloadsPath;
        try {
          final downloads = await getDownloadsDirectory();
          downloadsPath = downloads?.path;
        } catch (_) {
          downloadsPath = null;
        }
        if (downloadsPath != null) {
          final targetDir = Directory(
            p.join(downloadsPath, 'cheemow_pos', dateStr),
          );
          if (!await targetDir.exists()) {
            try {
              await targetDir.create(recursive: true);
            } catch (_) {}
          }
          easyFile = File(p.join(targetDir.path, fileName));
          // 若已存在則刪除再寫入，避免殘留舊檔（確保覆寫語意明確）
          try {
            if (await easyFile.exists()) {
              await easyFile.delete();
            }
          } catch (_) {}
          try {
            await easyFile.writeAsBytes(bytes, flush: true);
            // ignore: avoid_print
            print('[RevenueExport] downloads: ${easyFile.path}');
          } catch (e) {
            // ignore: avoid_print
            print('[RevenueExport] write downloads failed: $e');
            easyFile = null;
          }
        }
      }

      // 預覽已顯示於對話框（只有一個畫面，不會先出現一張又跳到另一張）

      if (!mounted) return true;
      final paths = [
        if (Platform.isAndroid && savedPublicPath != null)
          '下載: $savedPublicPath'
        else if (easyFile != null)
          '下載: ${easyFile.path}',
      ].join('\\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已匯出今日營收圖\n$paths')));
      return true;
    } catch (e) {
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (_) {}
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出營收圖失敗: $e')));
      return false;
    }
  }

  Future<void> _showSetPettyCashDialog() async {
    final pin = AppConfig.csvImportPin;
    // 若已有值且要修改，先輸入 PIN
    if (AppConfig.pettyCash > 0) {
      final ok = await _confirmPin(pin: pin);
      if (!ok) return;
    }
    int tempValue = AppConfig.pettyCash;
    await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          String current = tempValue == 0 ? '' : tempValue.toString();
          void append(String d) {
            if (current.length >= 7) return;
            current += d;
            setS(() => tempValue = int.tryParse(current) ?? 0);
          }

          void clearAll() {
            setS(() {
              current = '';
              tempValue = 0;
            });
          }

          void confirm() async {
            if (tempValue < 0) return; // 不接受負值
            await AppConfig.setPettyCash(tempValue);
            if (!mounted) return;
            Navigator.of(ctx).pop(tempValue);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('零用金已設定為 💲' + tempValue.toString())),
            );
          }

          Widget priceDisplay() => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Text(
              '💲 ${current.isEmpty ? '0' : current}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
              textAlign: TextAlign.center,
            ),
          );
          Widget numKey(String n, VoidCallback onTap) => SizedBox(
            width: 72,
            height: 60,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[700],
              ),
              child: Text(
                n,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
          Widget actionKey(String label, VoidCallback onTap) => SizedBox(
            width: 72,
            height: 60,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[50],
                foregroundColor: Colors.orange[700],
              ),
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
          );
          return AlertDialog(
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '💰 設定零用金',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  priceDisplay(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('1', () => append('1')),
                      numKey('2', () => append('2')),
                      numKey('3', () => append('3')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('4', () => append('4')),
                      numKey('5', () => append('5')),
                      numKey('6', () => append('6')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('7', () => append('7')),
                      numKey('8', () => append('8')),
                      numKey('9', () => append('9')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      actionKey('🧹', clearAll),
                      numKey('0', () => append('0')),
                      actionKey('✅', confirm),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _confirmPin({required String pin}) async {
    String input = '';
    bool ok = false;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget numKey(String d) => SizedBox(
            width: 70,
            height: 56,
            child: ElevatedButton(
              onPressed: input.length < 4
                  ? () => setS(() {
                      input += d;
                      if (input.length == 4) {
                        if (input == pin) {
                          ok = true;
                          Navigator.of(ctx).pop();
                        } else {
                          input = '';
                        }
                      }
                    })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[700],
              ),
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
          return AlertDialog(
            // 移除標題，統一樣式
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '✨ 請輸入奇妙數字 ✨',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '目前零用金：💲' + AppConfig.pettyCash.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[600]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Text(
                      ('••••'.substring(0, input.length)).padRight(4, '—'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numKey('1'), numKey('2'), numKey('3')],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numKey('4'), numKey('5'), numKey('6')],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [numKey('7'), numKey('8'), numKey('9')],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 70,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => setS(() => input = ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[50],
                            foregroundColor: Colors.orange[700],
                          ),
                          child: const Text('清除'),
                        ),
                      ),
                      numKey('0'),
                      SizedBox(
                        width: 70,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.grey[700],
                          ),
                          child: const Text('取消'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return ok;
  }

  // 新增：寶寶人氣指數匯出（與營收匯出相同的穩定預覽 + 隱藏擷取流程）
  Future<void> _exportTodayPopularityImage() async {
    try {
      final receipts = await ReceiptService.instance.getTodayReceipts();
      final Map<String, int> categoryCount = {};
      int preorderQty = 0, discountQty = 0, normalQty = 0;
      for (final r in receipts) {
        final refunded = r.refundedProductIds.toSet();
        for (final it in r.items) {
          if (refunded.contains(it.product.id)) continue;
          final p = it.product;
          if (p.isPreOrderProduct)
            preorderQty += it.quantity;
          else if (p.isDiscountProduct)
            discountQty += it.quantity;
          else
            normalQty += it.quantity;
          final cat = p.category.isEmpty ? '未分類' : p.category;
          categoryCount.update(
            cat,
            (v) => v + it.quantity,
            ifAbsent: () => it.quantity,
          );
        }
      }
      final fixedCats = [
        'Duffy',
        'ShellieMay',
        'Gelatoni',
        'StellaLou',
        'CookieAnn',
        'OluMel',
        'LinaBell',
      ];
      final Map<String, int> baseMap = {for (final c in fixedCats) c: 0};
      int others = 0;
      categoryCount.forEach((k, v) {
        if (baseMap.containsKey(k))
          baseMap[k] = baseMap[k]! + v;
        else
          others += v;
      });
      final totalAll = normalQty + preorderQty + discountQty;
      String pct(int v) => totalAll == 0
          ? '0%'
          : ((v * 1000 / (totalAll == 0 ? 1 : totalAll)).round() / 10)
                    .toStringAsFixed(1) +
                '%';
      final sortable = [
        ...baseMap.entries.map((e) => MapEntry(e.key, e.value)),
        MapEntry('其他角色', others),
      ]..sort((a, b) => b.value.compareTo(a.value));
      String deco(String raw) {
        switch (raw) {
          case 'Duffy':
            return '🐻 Duffy';
          case 'ShellieMay':
            return '🐻 ShellieMay';
          case 'Gelatoni':
            return '🐱 Gelatoni';
          case 'StellaLou':
            return '🐰 StellaLou';
          case 'CookieAnn':
            return '🐶 CookieAnn';
          case 'OluMel':
            return '🐢 OluMel';
          case 'LinaBell':
            return '🦊 LinaBell';
          case '其他角色':
            return '🏰 其他角色';
          default:
            return raw;
        }
      }

      // 角色代表色（可再微調）
      final popularityColors = <String, Color>{
        'Duffy': Colors.brown[400]!,
        'ShellieMay': Colors.pink[300]!,
        'Gelatoni': Colors.teal[400]!,
        'StellaLou': Colors.purple[300]!,
        'CookieAnn': Colors.amber[400]!,
        'OluMel': Colors.green[300]!,
        'LinaBell': Colors.pink[200]!,
        '其他角色': Colors.blueGrey[300]!,
      };
      final now = DateTime.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final captureKey = GlobalKey();
      Widget popularityWidget({Key? key}) => RepaintBoundary(
        key: key,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          width: 560, // 縮窄整體寬度，減少右側留白
          decoration: BoxDecoration(
            // 淡漸層背景讓卡片更柔和
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '🍼 寶寶人氣指數',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _metricChip('交易筆數', receipts.length, Colors.indigo[600]!),
                  _metricChip('總件數', totalAll, Colors.teal[700]!),
                  _metricChip('一般件數', normalQty, Colors.blue[600]!),
                  _metricChip('預購件數', preorderQty, Colors.purple[600]!),
                  _metricChip('折扣件數', discountQty, Colors.orange[700]!),
                ],
              ),
              const SizedBox(height: 18), // 移除表頭後保留適度空隙
              for (int i = 0; i < sortable.length; i++) ...[
                _categoryBarNew(
                  deco(sortable[i].key),
                  sortable[i].value,
                  pct(sortable[i].value),
                  totalAll,
                  popularityColors[sortable[i].key] ?? Colors.blueGrey,
                  i == 0
                      ? '🥇'
                      : i == 1
                      ? '🥈'
                      : i == 2
                      ? '🥉'
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'CheeMeow POS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // 預覽對話框（使用者看到穩定版本）
      if (mounted) {
        // ignore: unawaited_futures
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: popularityWidget()),
          ),
        );
      }
      if (!mounted) return;
      // 隱藏透明 Overlay 擷取高解析版本
      final overlayState = Overlay.of(context, rootOverlay: true);
      final entry = OverlayEntry(
        builder: (_) => IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.01,
              child: Material(
                color: Colors.transparent,
                child: popularityWidget(key: captureKey),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(entry);
      await Future.delayed(const Duration(milliseconds: 16));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 16));
      late final Uint8List bytes;
      try {
        final ro = captureKey.currentContext?.findRenderObject();
        if (ro is! RenderRepaintBoundary) {
          await Future.delayed(const Duration(milliseconds: 32));
          final ro2 = captureKey.currentContext?.findRenderObject();
          if (ro2 is! RenderRepaintBoundary) throw Exception('渲染尚未完成');
          final img2 = await ro2.toImage(pixelRatio: 3.0);
          final bd2 = await img2.toByteData(format: ui.ImageByteFormat.png);
          bytes = bd2!.buffer.asUint8List();
        } else {
          final img = await ro.toImage(pixelRatio: 3.0);
          final bd = await img.toByteData(format: ui.ImageByteFormat.png);
          bytes = bd!.buffer.asUint8List();
        }
      } finally {
        try {
          entry.remove();
        } catch (_) {}
      }

      final fileName = '人氣指數_${dateStr}.png';
      String? savedPath;
      if (Platform.isAndroid) {
        File? tmp;
        try {
          final tmpDir = await getTemporaryDirectory();
          tmp = File(p.join(tmpDir.path, fileName));
          await tmp.writeAsBytes(bytes, flush: true);
          await MediaStore.ensureInitialized();
          final mediaStore = MediaStore();
          MediaStore.appFolder = 'cheemow_pos';
          // ---- 淨空同日重複檔 (含 (1)(2)... ) ----
          try {
            final baseNameNoExt = fileName.substring(0, fileName.length - 4);
            for (int i = 0; i < 8; i++) {
              final candidate = i == 0 ? fileName : '${baseNameNoExt} ($i).png';
              final deleted = await mediaStore.deleteFile(
                fileName: candidate,
                dirType: DirType.download,
                dirName: DirName.download,
                relativePath: dateStr,
              );
              if (deleted) {
                // ignore: avoid_print
                print('[PopularityExport] pre-clean deleted: $candidate');
              }
            }
          } catch (e) {
            // ignore: avoid_print
            print('[PopularityExport] pre-clean error: $e');
          }
          final exist = await mediaStore.getFileUri(
            fileName: fileName,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: dateStr,
          );
          if (exist != null) {
            final ok = await mediaStore.editFile(
              uriString: exist.toString(),
              tempFilePath: tmp.path,
            );
            if (ok) {
              savedPath = await mediaStore.getFilePathFromUri(
                uriString: exist.toString(),
              );
              // ignore: avoid_print
              print('[PopularityExport] edited existing file: $savedPath');
            } else {
              // ignore: avoid_print
              print('[PopularityExport] editFile failed, fallback delete+save');
              try {
                await mediaStore.deleteFile(
                  fileName: fileName,
                  dirType: DirType.download,
                  dirName: DirName.download,
                  relativePath: dateStr,
                );
              } catch (e) {
                // ignore: avoid_print
                print('[PopularityExport] delete old failed: $e');
              }
              final save = await mediaStore.saveFile(
                tempFilePath: tmp.path,
                dirType: DirType.download,
                dirName: DirName.download,
                relativePath: dateStr,
              );
              String? uriStr = save?.uri.toString();
              if (save != null && save.isDuplicated) {
                // ignore: avoid_print
                print(
                  '[PopularityExport] duplicated after fallback: ${save.name}',
                );
              }
              if (uriStr != null) {
                final real = await mediaStore.getFilePathFromUri(
                  uriString: uriStr,
                );
                if (real != null) uriStr = real;
                savedPath = uriStr;
              }
            }
          } else {
            final save = await mediaStore.saveFile(
              tempFilePath: tmp.path,
              dirType: DirType.download,
              dirName: DirName.download,
              relativePath: dateStr,
            );
            String? uriStr = save?.uri.toString();
            if (save != null && save.isDuplicated) {
              // ignore: avoid_print
              print(
                '[PopularityExport] unexpected duplicated on first save: ${save.name}',
              );
            }
            if (uriStr != null) {
              final real = await mediaStore.getFilePathFromUri(
                uriString: uriStr,
              );
              if (real != null) uriStr = real;
              savedPath = uriStr;
            }
            // ignore: avoid_print
            print('[PopularityExport] created new file: $savedPath');
          }
        } finally {
          try {
            await tmp?.delete();
          } catch (_) {}
        }
      } else {
        final downloads = await getDownloadsDirectory();
        final base = downloads?.path;
        if (base != null) {
          final dir = Directory(p.join(base, 'cheemow_pos', dateStr));
          if (!await dir.exists()) {
            try {
              await dir.create(recursive: true);
            } catch (_) {}
          }
          final file = File(p.join(dir.path, fileName));
          // 明確覆寫：若存在先刪除
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
          await file.writeAsBytes(bytes, flush: true);
          savedPath = file.path;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath != null ? '已匯出寶寶人氣指數：$savedPath' : '匯出失敗'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('人氣指數匯出錯誤：$e')));
    }
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

    // 建立並儲存收據：自訂編號（每日序號），時間精度到分鐘
    final now = DateTime.now();
    final id = await ReceiptService.instance.generateReceiptId(
      payment.method,
      now: now,
    );
    final tsMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final receipt = Receipt.fromCart(
      itemsSnapshot,
    ).copyWith(id: id, timestamp: tsMinute, paymentMethod: payment.method);
    await ReceiptService.instance.saveReceipt(receipt);
    if (!mounted) return;

    // 顯示結帳完成
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          payment.method == '現金'
              ? '結帳完成（${payment.method}）。找零 💲${payment.change}，已更新 $checkedOutCount 個商品排序'
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

  // 重新排序商品（依當日銷售規則）
  final resorted = _sortProductsDaily(updatedProducts);

    // 儲存更新後商品
    await LocalDatabaseService.instance.saveProducts(updatedProducts);

    setState(() {
      // 清空購物車
      cartItems.clear();
      // 更新產品列表（這會觸發重新排序和回到頂部）
  products = resorted;

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

  debugPrint('結帳完成，商品列表已更新，實際更新: $updatedCount 個商品 (daily sort applied)');
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

  Widget _metricChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _darken(color))),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _darken(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    final dark = hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0));
    return dark.toColor();
  }

  Widget _categoryBarNew(
    String name,
    int count,
    String percent,
    int total,
    Color barColor, [
    String? medal,
  ]) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // 獎牌欄位（可為 null）
          SizedBox(
            width: 26,
            child: Text(
              medal ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            width: 128, // 增加可視文字寬（原 120）
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 50, // 微放大，搭配字體
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230), // 縮短條形寬度騰出文字空間
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  children: [
                    Container(height: 18, color: Colors.blueGrey[50]),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [barColor.withOpacity(0.85), barColor],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8), // 百分比更靠近
          SizedBox(
            width: 56,
            child: Text(
              percent,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
