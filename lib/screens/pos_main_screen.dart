import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// import 'dart:ui' as ui; // 擷取已改用 CaptureUtil，不再直接使用
// import 'dart:convert'; // 已不直接使用
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
import '../dialogs/dialog_manager.dart';
import '../config/app_config.dart';
import 'receipt_list_screen.dart';
import '../config/app_messages.dart';
import '../services/time_service.dart';
import '../controllers/pos_cart_controller.dart';
import '../utils/product_sorter.dart';
import '../services/export_service.dart';
import '../utils/capture_util.dart';
import '../dialogs/pin_dialog.dart';
import '../managers/search_filter_manager.dart';
import '../services/report_service.dart';
import '../services/sales_export_service.dart';
import '../widgets/search_filter_bar.dart';
import '../services/product_update_service.dart';
import '../services/barcode_scan_helper.dart';

class PosMainScreen extends StatefulWidget {
  const PosMainScreen({super.key});

  @override
  State<PosMainScreen> createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> {
  List<Product> products = [];
  List<CartItem> cartItems = [];
  late final PosCartController _cartController = PosCartController(cartItems);
  // 結帳後暫存最後購物車，用於結帳完成後仍顯示內容直到下一次操作
  List<CartItem> _lastCheckedOutCart = [];
  String? _lastCheckoutPaymentMethod; // 顯示『已結帳完成 使用 XX 付款方式』
  String lastScannedBarcode = '';
  KeyboardScannerManager? _kbScanner;
  bool _shouldScrollToTop = false;
  int _currentPageIndex = 0; // 0: 銷售頁面, 1: 搜尋頁面
  String _searchQuery = '';
  List<Product> _searchResults = [];
  final List<String> _selectedFilters = []; // 選中的篩選條件
  final SearchFilterManager _searchFilterManager = SearchFilterManager();

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

  Timer? _midnightTimer;

  void _scheduleMidnightPettyCashReset() {
    _midnightTimer?.cancel();
    final now = TimeService.now();
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = TimeService.scheduleAt(tomorrowMidnight, () async {
      await AppConfig.resetPettyCashIfNewDay();
      if (!mounted) return;
      setState(() {});
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
  _midnightTimer?.cancel();
  super.dispose();
  }

  void _maybeAutoExportRevenueOnStart() {
    const auto = bool.fromEnvironment('EXPORT_REVENUE_ON_START');
    if (!auto) return;
    if (!mounted) return;
    () async {
      final ok = await _exportTodayRevenueImage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppMessages.autoExportRevenueSuccess
                : AppMessages.autoExportRevenueFailure,
          ),
        ),
      );
    }();
  }

  Future<void> _loadProducts() async {
    // 確保特殊商品存在
    await LocalDatabaseService.instance.ensureSpecialProducts();

    final loadedProducts = await LocalDatabaseService.instance.getProducts();
  final sorted = ProductSorter.sortDaily(loadedProducts, now: TimeService.now());
    setState(() {
      products = sorted;
    });
  }

  // 每日排序：今日有售出的商品 (lastCheckoutTime 為今日) 置頂；
  // 特殊商品永遠最前（預購在折扣前），再來今日售出的普通商品（依時間新→舊），
  // 其餘按名稱。
  // 已抽離至 ProductSorter.sortDaily

  void _listenToBarcodeScanner() {
    BluetoothScannerService.instance.barcodeStream.listen((barcode) {
      _onBarcodeScanned(barcode);
    });
  }

  void _onBarcodeScanned(String barcode) async {
    final decision = await BarcodeScanHelper.decideFromDatabase(barcode);
    if (!mounted) return;
    switch (decision.result) {
      case ScanAddResult.foundNormal:
        _addToCart(decision.product!);
        setState(() => lastScannedBarcode = barcode);
        break;
      case ScanAddResult.foundSpecialNeedsPrice:
        // 需要輸入價格再加入
        _addToCart(decision.product!);
        setState(() => lastScannedBarcode = barcode);
        break;
      case ScanAddResult.notFound:
        DialogManager.showProductNotFound(context, barcode);
        break;
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
    setState(() {
      _cartController.addProduct(product, actualPrice);
    });
  }

  //（已移除）手動加減數量功能

  // 本地未使用：找不到商品改由 DialogManager 管理

  int get totalAmount => _cartController.totalAmount;

  int get totalQuantity => _cartController.totalQuantity;

  void _clearPostCheckoutPreview() {
    setState(() {
      _lastCheckedOutCart.clear();
      _lastCheckoutPaymentMethod = null;
    });
  }

  // 移除購物車指定索引的項目
  void _removeFromCart(int index) {
    // 若仍在顯示上一筆結帳結果，任何修改購物車的操作都先清除暫存
    if (_lastCheckedOutCart.isNotEmpty) {
      _clearPostCheckoutPreview();
    }
    setState(() {
      _cartController.removeAt(index);
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

    return PinDialog.show(
      context: context,
      pin: pin,
      subtitle: '⚠️ 這會覆蓋所有商品資料',
    );
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
              if (_lastCheckedOutCart.isNotEmpty) _clearPostCheckoutPreview();
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
                case 'sales_export':
                  await _exportSalesData();
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
                value: 'sales_export',
                child: Row(
                  children: const [
                    Text('📊', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('匯出小幫手表格'),
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
                            onTap: () {
                              if (_lastCheckedOutCart.isNotEmpty)
                                _clearPostCheckoutPreview();
                              setState(() => _currentPageIndex = 0);
                            },
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
                            onTap: () {
                              if (_lastCheckedOutCart.isNotEmpty)
                                _clearPostCheckoutPreview();
                              setState(() => _currentPageIndex = 1);
                            },
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
                            onProductTap: (p) {
                              if (_lastCheckedOutCart.isNotEmpty)
                                _clearPostCheckoutPreview();
                              _addToCart(p);
                            },
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
                  if (_lastCheckedOutCart.isNotEmpty) {
                    _clearPostCheckoutPreview();
                    return;
                  }
                  setState(() {
                    cartItems.clear();
                  });
                },
                onCheckout: _checkout,
                lastCheckedOutCart: _lastCheckedOutCart,
                lastCheckoutPaymentMethod: _lastCheckoutPaymentMethod,
                onAnyInteraction: () {
                  if (_lastCheckedOutCart.isNotEmpty) {
                    _clearPostCheckoutPreview();
                  }
                },
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
  final summary = await ReportService.computeTodayRevenueSummary();

      // 建立可愛繽紛的圖像 Widget（統一卡片樣式）
  final now = TimeService.now();
      final y = now.year.toString().padLeft(4, '0');
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final dateStr = '$y-$m-$d';

      // captureKey 用於不可見的「未遮蔽」版本擷取；預覽不使用 key
  // captureKey 已由 CaptureUtil 內部自行建立

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
                        mask(summary.total),
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
                        value: mask(summary.cash),
                        bg: bg3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '🔁',
                        title: '轉帳',
                        value: mask(summary.transfer),
                        bg: bg4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '📲',
                        title: 'LinePay',
                        value: mask(summary.linepay),
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
                        value: mask(summary.preorder),
                        bg: bg1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: metricCard(
                        icon: '✨',
                        title: '折扣小計',
                        value: mask(summary.discount),
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

      if (!mounted) return false;
      final bytes = await CaptureUtil.captureWidget(
        context: context,
        builder: (k) => revenueWidget(showNumbers: true, key: k),
        pixelRatio: 3.0,
      );

      final yy = (now.year % 100).toString().padLeft(2, '0');
      final fileName = '營收_$yy$m$d.png';
      final res = await ExportService.instance.savePng(fileName: fileName, bytes: bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.success
                  ? AppMessages.exportRevenueSuccess(res.paths.join('\n'))
                  : AppMessages.exportRevenueFailure(res.error ?? '未知錯誤'),
            ),
          ),
        );
      }
      return res.success;
    } catch (e) {
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (_) {}
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppMessages.exportRevenueFailure(e))),
      );
      return false;
    }
  }

  Future<void> _showSetPettyCashDialog() async {
    final pin = AppConfig.csvImportPin;
    // 若已有值且要修改，先輸入 PIN
    if (AppConfig.pettyCash > 0) {
      final ok = await PinDialog.show(
        context: context,
        pin: pin,
        subtitle: '目前零用金：💲' + AppConfig.pettyCash.toString(),
      );
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
              SnackBar(content: Text(AppMessages.pettyCashSet(tempValue))),
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

  // 新增：寶寶人氣指數匯出（與營收匯出相同的穩定預覽 + 隱藏擷取流程）
  Future<void> _exportTodayPopularityImage() async {
    try {
  final pop = await ReportService.computeTodayPopularityStats();
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
      pop.categoryCount.forEach((String k, int v) {
        if (baseMap.containsKey(k)) {
          baseMap[k] = baseMap[k]! + v;
        } else {
          others += v;
        }
      });
      final totalAll = pop.totalQty;
      String pct(int v) => pop.totalQty == 0
          ? '0%'
          : ((v * 1000 / (pop.totalQty == 0 ? 1 : pop.totalQty)).round() / 10)
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
  final now = TimeService.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  // captureKey 已由 CaptureUtil 內部自行建立
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
          _metricChip('交易筆數', pop.receiptCount, Colors.indigo[600]!),
          _metricChip('總件數', pop.totalQty, Colors.teal[700]!),
          _metricChip('一般件數', pop.normalQty, Colors.blue[600]!),
          _metricChip('預購件數', pop.preorderQty, Colors.purple[600]!),
          _metricChip('折扣件數', pop.discountQty, Colors.orange[700]!),
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
      final bytes = await CaptureUtil.captureWidget(
        context: context,
        builder: (k) => popularityWidget(key: k),
        pixelRatio: 3.0,
      );

      final fileName = '人氣指數_${dateStr}.png';
      final res = await ExportService.instance.savePng(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success && res.paths.isNotEmpty
                ? AppMessages.popularityExportSuccess(res.paths.first)
                : AppMessages.popularityExportFailure,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppMessages.popularityExportError(e))),
      );
    }
  }

  // TODO: 實作銷售資料匯出（今日 / 全部 / 日期區間）
  Future<void> _exportSalesData() async {
    if (!mounted) return;
    try {
      // 確保收據服務初始化（避免尚未初始化導致 _prefs 為 null）
      await ReceiptService.instance.initialize();
      final receipts = await ReceiptService.instance.getTodayReceipts();
      if (receipts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppMessages.salesExportNoData)),
        );
        return;
      }

      // 建立日期（資料夾 yyyy-MM-dd，同現有圖片匯出）與檔名日期後綴（yyMMdd）
      final now = DateTime.now();
  // dateFolder 由 ExportService 處理，不再在此使用
      final dateSuffix =
          '${(now.year % 100).toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // 與營收 / 人氣匯出保持一致：Downloads/cheemow_pos/<date>
  // 由 ExportService 處理平台差異

  // 付款方式代碼對應已內建於 SalesExportService 中

      final bundle = SalesExportService.instance.buildCsvsForReceipts(receipts);
      final salesFileName = '銷售_${dateSuffix}.csv';
      final specialFileName = '特殊商品_${dateSuffix}.csv';
      final res = await ExportService.instance.saveCsvFiles(
        files: {
          salesFileName: bundle.salesCsv,
          specialFileName: bundle.specialCsv,
        },
        addBom: true,
      );
      if (!mounted) return;
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppMessages.salesExportSuccess(res.paths))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppMessages.salesExportFailure(res.error ?? '未知錯誤'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppMessages.salesExportFailure(e))),
      );
    }
  }

  void _checkout() async {
    // 直接進入付款方式（極簡流程）
    // 結帳前最終把關：折扣不可大於非折扣商品總額
  final int nonDiscountTotal = _cartController.nonDiscountTotal;
  final int discountAbsTotal = _cartController.discountAbsTotal;

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
  final now = TimeService.now();
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
              ? AppMessages.checkoutCash(
                  payment.method,
                  payment.change,
                  checkedOutCount,
                )
              : AppMessages.checkoutOther(payment.method, checkedOutCount),
        ),
        duration: Duration(seconds: 3),
      ),
    );
    setState(() {
      _lastCheckoutPaymentMethod = payment.method;
    });
  }

  Future<void> _processCheckout() async {
    final outcome = await ProductUpdateService.instance.applyCheckout(
      products: products,
      cartItems: cartItems,
      now: TimeService.now(),
    );

    debugPrint('結帳數量統計: ${outcome.quantityByBarcode}');
    debugPrint('實際更新了 ${outcome.updatedCount} 個商品');

    setState(() {
      // 暫存結帳前的購物車內容供結帳完成後顯示
      _lastCheckedOutCart = List<CartItem>.from(cartItems);
      cartItems.clear();
  products = outcome.resortedProducts;

      // 若目前左側使用的是搜尋/篩選結果，將其以條碼對映為最新的商品資料，以避免顯示舊庫存
      if (_searchResults.isNotEmpty) {
        final Map<String, Product> latestByBarcode = {
          for (final p in outcome.updatedProducts) p.barcode: p,
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

  debugPrint('結帳完成，商品列表已更新，實際更新: ${outcome.updatedCount} 個商品 (daily sort applied)');
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
        // 快速篩選按鈕區域（以可重用元件呈現）
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SearchFilterBar(
              buildFilterButton: (label, {bool isSpecial = false}) =>
                  _buildFilterButton(label, isSpecial: isSpecial),
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
      _searchResults = _searchFilterManager.search(products, _searchQuery);
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
        _selectedFilters.clear();
        _searchQuery = '';
        _searchResults = [];
      } else if (label == '確認') {
        if (_searchQuery.startsWith('篩選結果')) {
          _searchQuery = '';
        }
        _applyFiltersWithTextSearch();
        _currentPageIndex = 0; // 切到銷售頁
      } else {
        final updated =
            _searchFilterManager.toggleFilter(_selectedFilters, label);
        _selectedFilters
          ..clear()
          ..addAll(updated);
      }
    });
  }

  /// 處理互斥群組的邏輯
  

  /// 應用篩選條件
  /// 應用篩選條件並結合文字搜尋
  void _applyFiltersWithTextSearch() {
    final filtered = _searchFilterManager.filter(
      products,
      _selectedFilters,
      searchQuery: _searchQuery,
    );
    setState(() {
      _searchResults = filtered;
      _searchQuery = '篩選結果 (${_selectedFilters.join(', ')})';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppMessages.searchResultCount(filtered.length)),
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
