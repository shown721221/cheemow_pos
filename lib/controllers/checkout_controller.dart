import '../models/cart_item.dart';
import '../models/receipt.dart';
import '../models/product.dart';
import '../services/time_service.dart';
import '../services/receipt_service.dart';
import '../services/product_update_service.dart';
import '../controllers/pos_cart_controller.dart';
import '../utils/app_logger.dart';
import '../utils/post_checkout_reorder.dart';
import '../utils/product_sorter.dart';

/// 封裝結帳與後處理邏輯，讓畫面 State 更精簡，維持原先行為。
class CheckoutResult {
  final Receipt receipt;
  final int unifiedTotal;
  CheckoutResult(this.receipt, this.unifiedTotal);
}

class CheckoutController {
  final List<CartItem> cartItems; // 由畫面層提供實際引用
  final PosCartController cartController;
  // 直接使用強型別，避免 insertAll 時因動態型別造成 runtime cast 失敗
  final List<Product> productsRef;
  final Future<void> Function() persistProducts; // 呼叫畫面層既有儲存邏輯
  List<CartItem> lastCheckedOutCart = [];
  String? lastPaymentMethod;

  CheckoutController({
    required this.cartItems,
    required this.cartController,
    required this.productsRef,
    required this.persistProducts,
  });

  /// 執行結帳主流程 (不含付款方式選擇 UI)，傳入已選擇付款方式字串
  Future<CheckoutResult> finalize(String paymentMethod) async {
    // 在清空購物車之前拍下快照
    final itemsSnapshot = List<CartItem>.from(cartItems);
    
    // 標記售出商品用於智能快取
    final soldProductIds = cartItems.map((item) => item.product.id).toSet().toList();
    ProductSorter.markAsSold(soldProductIds);

    final outcome = await ProductUpdateService.instance.applyCheckout(
      products: productsRef,
      cartItems: cartItems,
      now: TimeService.now(),
    );

    AppLogger.d('結帳更新商品數: ${outcome.updatedCount}');

    // 更新資料：保存結帳前購物車、清空購物車、更新商品（未排序）
    lastCheckedOutCart = List<CartItem>.from(cartItems);
    cartItems.clear();
    final oldProducts = List.of(productsRef); // 防護：異常時回復
    productsRef
      ..clear()
      ..addAll(outcome.updatedProducts);
    if (productsRef.isEmpty && oldProducts.isNotEmpty) {
      // 不預期：計算結果竟然空，回退舊資料
      AppLogger.w('結帳後商品清單意外為空，回復舊清單');
      productsRef
        ..clear()
        ..addAll(oldProducts);
    }

    // 額外：結帳後重新排列（抽離為共用函式，便於單元測試）
    try {
      final reordered = reorderAfterCheckout(
        currentProducts: productsRef,
        soldCartSnapshot: itemsSnapshot,
      );
      if (!identical(reordered, productsRef)) {
        productsRef
          ..clear()
          ..addAll(reordered);
      }
      AppLogger.d(
        '置頂後前5: ${productsRef.take(5).map((p) => p.name).join(' | ')}',
      );
    } catch (e) {
      AppLogger.w('結帳後置頂商品失敗', e);
    }

    // 保存更新後的商品資料
    await persistProducts();

    final now = TimeService.now();
    final id = await ReceiptService.instance.generateReceiptId(
      paymentMethod,
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
    ).copyWith(id: id, timestamp: tsMinute, paymentMethod: paymentMethod);
    await ReceiptService.instance.saveReceipt(receipt);

    final unifiedTotal = itemsSnapshot.fold<int>(
      0,
      (sum, i) => sum + i.subtotal,
    );
    lastPaymentMethod = paymentMethod;

    return CheckoutResult(receipt, unifiedTotal);
  }
}
