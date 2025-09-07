import 'package:flutter/material.dart';
import '../widgets/product_list_widget.dart';
import '../widgets/shopping_cart_widget.dart';
import '../models/product.dart';
import '../services/bluetooth_scanner_service.dart';
import '../services/csv_import_service.dart';
import '../controllers/pos_controller.dart';
import '../dialogs/pos_dialog_manager_new.dart';
import '../managers/keyboard_manager.dart' as keyboard;

class PosMainScreen extends StatefulWidget {
  @override
  _PosMainScreenState createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> {
  // 核心控制器和管理器
  late PosController _posController;
  late keyboard.PosKeyboardManager _keyboardManager;
  
  // 滾動控制器
  final ScrollController _productListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeServices();
  }

  /// 初始化控制器
  void _initializeControllers() {
    _posController = PosController();
    _keyboardManager = keyboard.PosKeyboardManager();
    
    // 設定鍵盤事件回調
    _keyboardManager.initialize(
      onBarcodeScanned: _posController.handleBarcodeInput,
      onEnterPressed: null, // 禁用 Enter 快速結帳，避免與掃描器衝突
    );
    
    // 監聽控制器變化
    _posController.addListener(_handleControllerUpdate);
  }

  /// 初始化服務
  void _initializeServices() async {
    await _posController.initialize();
    _listenToBarcodeScanner();
  }

  /// 處理控制器更新
  void _handleControllerUpdate() {
    // 檢查是否有未找到的商品
    if (_posController.hasUnfoundProduct) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PosDialogManager.showProductNotFoundDialog(
          context,
          _posController.lastScannedBarcode,
        );
        _posController.clearUnfoundProduct();
      });
    }
    
    setState(() {}); // 觸發 UI 更新
  }

  @override
  void dispose() {
    _posController.removeListener(_handleControllerUpdate);
    _productListScrollController.dispose();
    super.dispose();
  }

  /// 處理商品點擊（添加到購物車）
  void _onProductTap(Product product) async {
    if (product.price == 0) {
      // 特殊商品需要輸入價格
      final price = await PosDialogManager.showPriceInputDialog(context, product);
      if (price != null) {
        _posController.addProductToCart(product, price);
      }
    } else {
      // 普通商品直接添加
      _posController.addToCart(product);
    }
  }

  /// 處理結帳流程
  void _processCheckout() async {
    if (!_posController.hasItems) return;

    // 顯示確認對話框
    final confirmed = await PosDialogManager.showCheckoutConfirmDialog(
      context,
      _posController.totalAmount,
      _posController.totalQuantity,
    );

    if (!confirmed) return;

    // 顯示載入對話框
    PosDialogManager.showLoadingDialog(context, '處理中...');

    try {
      final receipt = await _posController.processCheckout();
      
      // 關閉載入對話框
      PosDialogManager.closeLoadingDialog(context);

      if (receipt != null) {
        // 結帳成功，直接滾動到頂部
        _scrollToTop();
      } else {
        PosDialogManager.showErrorDialog(
          context,
          '結帳失敗',
          '處理結帳時發生錯誤，請重試。',
        );
      }
    } catch (e) {
      // 關閉載入對話框
      PosDialogManager.closeLoadingDialog(context);
      
      PosDialogManager.showErrorDialog(
        context,
        '結帳失敗',
        '發生未知錯誤：$e',
      );
    }
  }

  /// 滾動到頂部
  void _scrollToTop() {
    if (_productListScrollController.hasClients) {
      _productListScrollController.jumpTo(0);
    }
  }

  /// 監聽藍牙掃描器
  void _listenToBarcodeScanner() {
    BluetoothScannerService.instance.barcodeStream.listen((barcode) {
      print('接收到條碼: $barcode');
      _posController.processBarcodeScanned(barcode);
    });
  }

  /// 匯入 CSV 資料
  void _importCsvData() async {
    try {
      final result = await CsvImportService.importFromFile();
      
      if (result.success) {
        // 重新載入商品資料
        await _posController.refreshProducts();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV 匯入成功！已匯入 ${result.importedCount} 個商品'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (!result.cancelled) {
        PosDialogManager.showErrorDialog(
          context,
          '匯入失敗',
          result.errorMessage ?? '未知錯誤',
        );
      }
    } catch (e) {
      PosDialogManager.showErrorDialog(
        context,
        '匯入失敗',
        '匯入 CSV 檔案時發生錯誤：$e',
      );
    }
  }

  /// 顯示即將推出功能的對話框
  void _showComingSoonDialog(String feature) {
    PosDialogManager.showComingSoonDialog(context, feature);
  }

  @override
  Widget build(BuildContext context) {
    return keyboard.KeyboardListener(
      keyboardManager: _keyboardManager,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Cheemow POS'),
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
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
                const PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.upload_file),
                      SizedBox(width: 8),
                      Text('匯入 CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('匯出資料'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'receipts',
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long),
                      SizedBox(width: 8),
                      Text('收據清單'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'revenue',
                  child: Row(
                    children: [
                      Icon(Icons.analytics),
                      SizedBox(width: 8),
                      Text('營收總計'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Row(
          children: [
            // 左側：商品列表
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: ProductListWidget(
                  products: _posController.products,
                  onProductTap: _onProductTap,
                ),
              ),
            ),
            // 右側：購物車
            Expanded(
              flex: 1,
              child: ShoppingCartWidget(
                cartItems: _posController.cartItems,
                onRemoveItem: _posController.removeFromCart,
                onIncreaseQuantity: _posController.increaseQuantity,
                onDecreaseQuantity: _posController.decreaseQuantity,
                onClearCart: () {
                  _posController.clearCart();
                },
                onCheckout: _processCheckout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
