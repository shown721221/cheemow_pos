import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cheemeow_pos/utils/app_logger.dart';
import '../widgets/pos_tab_bar.dart';
import '../widgets/pos_more_menu.dart';
import '../widgets/pos_product_panel.dart';
import '../widgets/shopping_cart_widget.dart';
import '../dialogs/payment_dialog.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/local_database_service.dart';
import '../services/csv_import_service.dart';
import '../dialogs/price_input_dialog_manager.dart';
import '../dialogs/dialog_manager.dart';
import '../config/app_config.dart';
import '../config/app_messages.dart';
import '../services/time_service.dart';
import '../controllers/pos_cart_controller.dart';
import '../controllers/checkout_controller.dart';
import '../utils/product_sorter.dart';
import '../dialogs/pin_dialog.dart';
import '../widgets/primary_app_bar.dart';
// 新拆分的匯出與對話框輔助
// revenue_export_helper 由 PosActionsService 間接使用
import '../services/pos_actions_service.dart';
import '../managers/search_filter_manager.dart'; // 舊 manager 仍供 controller 使用
import '../controllers/search_controller.dart' as pos_search;
import '../managers/barcode_scan_coordinator.dart';
import '../managers/petty_cash_scheduler.dart';

class PosMainScreen extends StatefulWidget {
  const PosMainScreen({super.key});

  @override
  State<PosMainScreen> createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> {
  List<Product> products = [];
  List<CartItem> cartItems = [];
  late final PosCartController _cartController = PosCartController(cartItems);
  late final CheckoutController _checkoutController;
  // 結帳後暫存最後購物車，用於結帳完成後仍顯示內容直到下一次操作
  List<CartItem> _lastCheckedOutCart = [];
  String? _lastCheckoutPaymentMethod; // 顯示『已結帳完成 使用 XX 付款方式』
  String lastScannedBarcode = '';
  BarcodeScanCoordinator? _barcodeCoordinator;
  PettyCashScheduler? _pettyCashScheduler;
  bool _shouldScrollToTop = false; // 需要動態切換 true->false 觸發列表回頂
  int _currentPageIndex = 0; // 0: 銷售頁面, 1: 搜尋頁面
  late final pos_search.PosSearchController _searchController;
  final SearchFilterManager _searchFilterManager = SearchFilterManager();
  StreamSubscription<String>? _barcodeSub;
  // 一旦第一次結帳後，商品清單改由 CheckoutController 手動重排（將本次售出商品置頂），
  // 就不再進行每日自動排序，避免覆蓋手動置頂結果；重新載入商品 (例如 CSV 匯入或啟動) 時會重置。
  bool _manualOrderActive = false;
  // 移除：早期為了強制列表重建與自動重載的除錯欄位

  @override
  void initState() {
    super.initState();
    _searchController =
        pos_search.PosSearchController(
          products: products,
          manager: _searchFilterManager,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _checkoutController = CheckoutController(
      cartItems: cartItems,
      cartController: _cartController,
      productsRef: products,
      persistProducts: _saveProductsToStorage,
    );
    _loadProducts();
    _barcodeCoordinator = BarcodeScanCoordinator(
      onAddNormal: (p) async => _handleAddScannedProduct(p, p.price),
      onAddSpecial: (p) async => _handleSpecialScannedProduct(p),
      onNotFound: (code) => DialogManager.showProductNotFound(context, code),
      onPreScan: () {
        if (!mounted) return;
        if (_lastCheckedOutCart.isNotEmpty || _currentPageIndex != 0) {
          setState(() {
            if (_lastCheckedOutCart.isNotEmpty) {
              _lastCheckedOutCart.clear();
              _lastCheckoutPaymentMethod = null;
            }
            _currentPageIndex = 0;
          });
        }
      },
    )..start();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAutoExportRevenueOnStart(),
    );

    _pettyCashScheduler = PettyCashScheduler(
      onReset: () {
        if (!mounted) return;
        setState(() {});
      },
    )..start();
  }

  @override
  void dispose() {
    _barcodeSub?.cancel();
    _searchController.dispose();
    _barcodeCoordinator?.dispose();
    _pettyCashScheduler?.dispose();
    super.dispose();
  }

  void _maybeAutoExportRevenueOnStart() {
    const auto = bool.fromEnvironment('EXPORT_REVENUE_ON_START');
    if (!auto) return;
    if (!mounted) return;
    () async {
      await PosActionsService.instance.exportTodayRevenueImage(context);
    }();
  }

  Future<void> _loadProducts() async {
    await LocalDatabaseService.instance.initialize();
    await LocalDatabaseService.instance.ensureSpecialProducts();

    final loadedProducts = await LocalDatabaseService.instance.getProducts();
    final sorted = ProductSorter.sortDaily(
      loadedProducts,
      now: TimeService.now(),
      recencyDominatesSpecial: true,
      forcePinSpecial: true,
    );
    setState(() {
      products
        ..clear()
        ..addAll(sorted);
      // 重新載入資料後恢復自動每日排序狀態
      _manualOrderActive = false;
    });
    AppLogger.d('載入產品數量: ${products.length}');
    _searchController.refreshProducts(products);
  }

  Future<void> _handleSpecialScannedProduct(Product product) async {
    if (!mounted) return;
    final inputPrice = await PriceInputDialogManager.showCustomNumberInput(
      context,
      product,
      totalAmount,
    );
    if (inputPrice != null) {
      _handleAddScannedProduct(product, inputPrice);
    }
  }

  Future<void> _handleAddScannedProduct(Product product, int price) async {
    if (!mounted) return;
    setState(() {
      _cartController.addProduct(product, price);
      lastScannedBarcode = product.barcode;
    });
  }

  void _addToCart(Product product) async {
    if (product.price == 0) {
      await _handleSpecialScannedProduct(product);
    } else {
      await _handleAddScannedProduct(product, product.price);
    }
  }

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
    DialogManager.showLoading(context, message: AppMessages.importing);
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
        DialogManager.showError(
          context,
          AppMessages.importFailed,
          result.errorMessage ?? AppMessages.unknownError,
        );
      }
    } catch (e) {
      // 關閉 loading
      if (!mounted) return;
      DialogManager.hideLoading(context);
      DialogManager.showError(context, AppMessages.importFailed, e.toString());
    }
  }

  /// 匯入前 PIN 確認（四位數字，預設 0000）
  Future<bool> _confirmImportWithPin() async {
    final pin = AppConfig.csvImportPin;

    return PinDialog.show(
      context: context,
      pin: pin,
      subtitle: '注意 ⚠️ 這會覆蓋所有商品資料',
      subtitleEmphasis: true,
    );
  }

  // 對話框統一改用 DialogManager，移除本地自建實作

  // CSV 格式說明已統一由 DialogManager.showCsvFormatHelp(context) 處理

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 防止鍵盤影響佈局
      backgroundColor: Colors.white,
      appBar: PrimaryAppBar(
        titleWidget: SizedBox(
          height: kToolbarHeight - 12, // 預留上下內距，避免撐高 AppBar
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.asset(
              'assets/images/title.png',
              errorBuilder: (context, error, stack) =>
                  Text(AppMessages.appTitle),
            ),
          ),
        ),
        actions: [
          PosMoreMenu(
            onImport: () async {
              if (_lastCheckedOutCart.isNotEmpty) {
                _clearPostCheckoutPreview();
              }
              await _importCsvData();
            },
            onReloadProducts: _loadProducts,
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
                  PosTabBar(
                    currentIndex: _currentPageIndex,
                    onSalesTap: () {
                      if (_lastCheckedOutCart.isNotEmpty) {
                        _clearPostCheckoutPreview();
                      }
                      setState(() => _currentPageIndex = 0);
                    },
                    onSearchTap: () {
                      if (_lastCheckedOutCart.isNotEmpty) {
                        _clearPostCheckoutPreview();
                      }
                      setState(() => _currentPageIndex = 1);
                    },
                  ),
                  // 頁面內容
                  Expanded(
                    child: PosProductPanel(
                      pageIndex: _currentPageIndex,
                      products: products,
                      searchController: _searchController,
                      manualOrderActive: _manualOrderActive,
                      shouldScrollToTop: _shouldScrollToTop,
                      onProductTap: (p) {
                        if (_lastCheckedOutCart.isNotEmpty) {
                          _clearPostCheckoutPreview();
                          setState(() => _currentPageIndex = 0);
                        }
                        _addToCart(p);
                      },
                      onSearchConfirmReturn: () =>
                          setState(() => _currentPageIndex = 0),
                    ),
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

  void _checkout() async {
    // 直接進入付款方式（極簡流程）
    // 結帳前最終把關：折扣不可大於非折扣商品總額
    final int nonDiscountTotal = _cartController.nonDiscountTotal;
    final int discountAbsTotal = _cartController.discountAbsTotal;

    if (discountAbsTotal > nonDiscountTotal) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(AppMessages.discountOverLimitTitle),
          content: Text(
            AppMessages.discountOverLimitBody(
              discountAbsTotal,
              nonDiscountTotal,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppMessages.confirm),
            ),
          ],
        ),
      );
      return; // 阻止結帳
    }

    final payment = await PaymentDialog.show(context, totalAmount: totalAmount);
    if (!mounted) return;
    if (payment == null) return; // 取消付款

    await _checkoutController.finalize(payment.method);
    if (!mounted) return;
    setState(() {
      _lastCheckoutPaymentMethod = payment.method;
      _searchController.clearQuery();
      _searchController.clearFilters();
      _currentPageIndex = 0; // 回到銷售頁
      _lastCheckedOutCart = List<CartItem>.from(
        _checkoutController.lastCheckedOutCart,
      );
      // 觸發商品列表回到頂部
      _shouldScrollToTop = true;
      // 啟用手動排序鎖定，後續不再自動每日排序，保留剛結帳商品置頂效果
      _manualOrderActive = true;
    });
    // 下一幀重置旗標，方便下次再次觸發
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_shouldScrollToTop) {
          setState(() => _shouldScrollToTop = false);
        }
      });
    }
  }

  Future<void> _saveProductsToStorage() async {
    try {
      await LocalDatabaseService.instance.saveProducts(products);
    } catch (e) {
      AppLogger.w('保存商品資料失敗', e);
    }
  }
}
