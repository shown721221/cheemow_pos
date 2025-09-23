import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../utils/money_formatter.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../config/app_messages.dart';
import '../models/receipt.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../config/constants.dart';
import '../widgets/empty_state.dart';
import '../config/style_config.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});
  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  late Future<List<Receipt>> _future;
  String _query = '';
  String? _selectedPay; // 單選付款方式
  String? _tagFilter; // discount / preorder / refund 單選
  bool _onlyToday = true;

  @override
  void initState() {
    super.initState();
    _future = _loadReceipts();
  }

  Future<List<Receipt>> _loadReceipts() async {
    return _onlyToday
        ? ReceiptService.instance.getTodayReceipts()
        : ReceiptService.instance.getReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppMessages.receiptListTitle),
        actions: [
          IconButton(
            tooltip: AppMessages.clearReceiptsTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await _confirmWithPin(
                warningText: AppMessages.warningClearReceipts,
                promptText: AppMessages.pinTitleMagic,
              );
              if (!ok) return;
              final irreversible = await _confirmIrreversibleDeletion();
              if (!irreversible) return;
              await ReceiptService.instance.clearAllReceipts();
              if (!context.mounted) return;
              // 使用區塊形式避免 setState 閉包回傳 Future
              setState(() {
                _future = _loadReceipts();
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppMessages.clearedReceipts)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 替換今日開關：用 FutureBuilder 取得收據數量（只計 raw list 長度；顯示『今日 X 筆』或『全部 X 筆』）
          FutureBuilder<List<Receipt>>(
            future: _future,
            builder: (ctx, snap) {
              final total = snap.data?.length ?? 0;
              final label = _onlyToday
                  ? AppMessages.onlyTodayLabel(total)
                  : AppMessages.allReceiptsLabel(total);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: _onlyToday,
                      onChanged: (v) => setState(() {
                        _onlyToday = v;
                        _future = _loadReceipts();
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(label),
                  ],
                ),
              );
            },
          ),
          _buildSearchBar(),
          _buildFilters(),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Receipt>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final receipts = snapshot.data ?? [];
                final filtered = _applyFilters(receipts);
                if (filtered.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.receipt_long,
                      title: AppMessages.noReceipts,
                      titleSize: 20,
                      message: null,
                      iconSize: 56,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _buildReceiptTile(filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTile(Receipt r) {
    final refundedIds = r.refundedProductIds;
    final nonSpecialQty = r.items
        .where(
          (it) =>
              !it.product.isSpecialProduct &&
              !refundedIds.contains(it.product.id),
        )
        .fold<int>(0, (s, it) => s + it.quantity);
    final hh = r.timestamp.hour.toString().padLeft(2, '0');
    final mm = r.timestamp.minute.toString().padLeft(2, '0');
    // 計算預購與折扣件數（僅計算未退貨項目）
    final preorderQty = r.items
        .where(
          (it) =>
              it.product.isPreOrderProduct &&
              !refundedIds.contains(it.product.id),
        )
        .fold<int>(0, (s, it) => s + it.quantity);
    final discountQty = r.items
        .where(
          (it) =>
              it.product.isDiscountProduct &&
              !refundedIds.contains(it.product.id),
        )
        .fold<int>(0, (s, it) => s + it.quantity);

    // 使用 RichText 給「預購 / 折扣 / 已退」上色
    final spans = <TextSpan>[];
    void addSeg(String text, {Color? color}) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' ・ '));
      spans.add(
        TextSpan(
          text: text,
          style: color != null ? TextStyle(color: color) : null,
        ),
      );
    }

    addSeg(r.id);
    addSeg('$hh:$mm');
    addSeg(r.paymentMethod);
    // 總金額（已是扣除退貨後的淨額）
    addSeg(MoneyFormatter.symbol(r.totalAmount));
    addSeg('售出 $nonSpecialQty 件');
    // 使用與商品清單一致的顏色：預購=紫色、折扣=橘色（取自 ProductStyleUtils 規則）
    if (preorderQty > 0) {
      addSeg('預購 $preorderQty 件', color: AppColors.preorder);
    }
    if (discountQty > 0) {
      addSeg('折扣 $discountQty 件', color: AppColors.discount);
    }
    if (r.refundedProductIds.isNotEmpty) {
      addSeg('已退 ${r.refundedProductIds.length} 件', color: AppColors.error);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.darkCard.withValues(alpha: .35),
        ),
        child: ListTile(
          dense: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          minVerticalPadding: 4,
          title: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onDarkPrimary,
                height: 1.25,
              ),
              children: spans,
            ),
            textScaler: const TextScaler.linear(1.0),
          ),
          trailing: const Icon(Icons.chevron_right, size: 22),
          onTap: () => _showReceiptDetailDialog(r),
        ),
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: AppMessages.receiptSearchHint,
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _query = v),
    ),
  );

  Widget _buildFilters() {
    void selectPay(String key) =>
        setState(() => _selectedPay = (_selectedPay == key) ? null : key);
    void selectTag(String key) =>
        setState(() => _tagFilter = (_tagFilter == key) ? null : key);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.cash,
            onTap: () => selectPay(PaymentMethods.cash),
            child: Text(AppMessages.cashLabel),
          ),
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.transfer,
            onTap: () => selectPay(PaymentMethods.transfer),
            child: Image.asset(
              'assets/images/cathay.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(AppMessages.transferLabel),
            ),
          ),
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.linePay,
            onTap: () => selectPay(PaymentMethods.linePay),
            child: Image.asset(
              'assets/images/linepay.png',
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Text(AppMessages.linePayLabel),
            ),
          ),
          FilterPillButton(
            selected: _tagFilter == 'discount',
            onTap: () => selectTag('discount'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💸', style: TextStyle(fontSize: 16)),
                SizedBox(width: 4),
                Text('折扣'),
              ],
            ),
            minWidth: 72,
          ),
          FilterPillButton(
            selected: _tagFilter == 'preorder',
            onTap: () => selectTag('preorder'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎁', style: TextStyle(fontSize: 16)),
                SizedBox(width: 4),
                Text('預購商品'),
              ],
            ),
            minWidth: 72,
          ),
          FilterPillButton(
            selected: _tagFilter == 'refund',
            onTap: () => selectTag('refund'),
            child: const Text(AppMessages.chipRefund),
            minWidth: 72,
          ),
        ],
      ),
    );
  }

  List<Receipt> _applyFilters(List<Receipt> receipts) {
    Iterable<Receipt> list = receipts;
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final inId = r.id.toLowerCase().contains(q);
        final inPay = r.paymentMethod.toLowerCase().contains(q);
        final inItems = r.items.any(
          (it) => it.product.name.toLowerCase().contains(q),
        );
        return inId || inPay || inItems;
      });
    }
    if (_selectedPay != null) {
      list = list.where((r) => r.paymentMethod == _selectedPay);
    }
    if (_tagFilter != null) {
      switch (_tagFilter) {
        case 'discount':
          list = list.where(
            (r) => r.items.any((it) => it.product.isDiscountProduct),
          );
          break;
        case 'preorder':
          list = list.where(
            (r) => r.items.any((it) => it.product.isPreOrderProduct),
          );
          break;
        case 'refund':
          list = list.where((r) => r.refundedProductIds.isNotEmpty);
          break;
      }
    }
    return list.toList();
  }

  Future<void> _showReceiptDetailDialog(Receipt receipt) async {
    Receipt current = receipt;
    String payment = receipt.paymentMethod;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> refundItem(CartItem item) async {
            final confirm = await showDialog<bool>(
              context: ctx,
              builder: (c2) => AlertDialog(
                title: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(AppMessages.refundDialogTitle),
                  ],
                ),
                content: Text(
                  AppMessages.refundDialogMessage(
                    item.product.name,
                    item.quantity,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c2, false),
                    child: const Text(AppMessages.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c2, true),
                    child: const Text(AppMessages.confirm),
                  ),
                ],
              ),
            );
            if (confirm != true) return;
            if (!item.product.isSpecialProduct) {
              final products = await LocalDatabaseService.instance
                  .getProducts();
              final idx = products.indexWhere((p) => p.id == item.product.id);
              final stock = idx >= 0 ? products[idx].stock : item.product.stock;
              await LocalDatabaseService.instance.updateProductStock(
                item.product.id,
                stock + item.quantity,
              );
            }
            final newRefunded = List<String>.from(current.refundedProductIds);
            if (!newRefunded.contains(item.product.id)) {
              newRefunded.add(item.product.id);
            }
            final hasNonDiscountUnrefunded = current.items.any(
              (it) =>
                  !it.product.isDiscountProduct &&
                  !newRefunded.contains(it.product.id),
            );
            if (!hasNonDiscountUnrefunded) {
              for (final it in current.items.where(
                (e) => e.product.isDiscountProduct,
              )) {
                if (!newRefunded.contains(it.product.id)) {
                  newRefunded.add(it.product.id);
                }
              }
            }
            final effectiveItems = current.items.where(
              (it) => !newRefunded.contains(it.product.id),
            );
            final newTotal = effectiveItems.fold<int>(
              0,
              (s, it) => s + it.subtotal,
            );
            final newQty = effectiveItems.fold<int>(
              0,
              (s, it) => s + it.quantity,
            );
            final updated = current.copyWith(
              refundedProductIds: newRefunded,
              totalAmount: newTotal,
              totalQuantity: newQty,
            );
            final saved = await ReceiptService.instance.updateReceipt(updated);
            if (saved) setS(() => current = updated);
          }

          return AlertDialog(
            title: Row(
              children: [
                const Text(AppMessages.receiptDetailsTitle),
                const Spacer(),
                DropdownButton<String>(
                  value: payment,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: PaymentMethods.cash,
                      child: Text(AppMessages.cashLabel),
                    ),
                    DropdownMenuItem(
                      value: '轉帳',
                      child: Text(AppMessages.transferLabel),
                    ),
                    DropdownMenuItem(
                      value: 'LinePay',
                      child: Text(AppMessages.linePayLabel),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null || v == payment) return;
                    final okPin = await _confirmWithPin(
                      warningText: AppMessages.changePaymentPinWarning,
                      promptText: AppMessages.pinTitleMagic,
                    );
                    if (!okPin) return;
                    final updated = current.copyWith(paymentMethod: v);
                    final saved = await ReceiptService.instance.updateReceipt(
                      updated,
                    );
                    if (saved) {
                      setS(() {
                        payment = v;
                        current = updated;
                      });
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${current.id} ・ ${current.timestamp.hour.toString().padLeft(2, '0')}:${current.timestamp.minute.toString().padLeft(2, '0')} ・ $payment',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onDarkSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: current.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, idx) {
                          final it = current.items[idx];
                          final refunded = current.refundedProductIds.contains(
                            it.product.id,
                          );
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                            ),
                            title: Text(
                              it.product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: refunded
                                    ? AppColors.error
                                    : (it.product.isDiscountProduct
                                          ? AppColors.discount
                                          : (it.product.isPreOrderProduct
                                                ? AppColors.preorder
                                                : AppColors.onDarkPrimary)),
                                decoration: refunded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '單價 ${MoneyFormatter.symbol(it.product.price)} × ${it.quantity}',
                              style: TextStyle(
                                color: refunded
                                    ? AppColors.error
                                    : AppColors.onDarkSecondary,
                                decoration: refunded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: refunded
                                ? Icon(
                                    Icons.assignment_return,
                                    color: AppColors.error,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.assignment_return,
                                      color: AppColors.success,
                                    ),
                                    tooltip: AppMessages.refundTooltip,
                                    onPressed: () => refundItem(it),
                                  ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(AppMessages.totalQuantityLabel),
                        Text(
                          '${current.items.where((i) => !current.refundedProductIds.contains(i.product.id)).fold<int>(0, (s, it) => s + it.quantity)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '總金額',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          MoneyFormatter.symbol(
                            current.items
                                .where(
                                  (i) => !current.refundedProductIds.contains(
                                    i.product.id,
                                  ),
                                )
                                .fold<int>(0, (s, it) => s + it.subtotal),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (mounted) {
      // 使用區塊形式避免 setState 閉包回傳 Future
      setState(() {
        _future = _loadReceipts();
      });
    }
  }

  Future<bool> _confirmIrreversibleDeletion() async {
    bool confirmed = false;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text(AppMessages.confirmDeleteTitle),
        content: const Text(AppMessages.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppMessages.cancel),
          ),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppMessages.confirmDelete),
          ),
        ],
      ),
    );
    return confirmed;
  }

  Future<bool> _confirmWithPin({
    required String warningText,
    required String promptText,
  }) async {
    final pin = AppConfig.csvImportPin;
    String input = '';
    String? error;
    bool ok = false;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget numKey(String d) => SizedBox(
            width: 72,
            height: 60,
            child: ElevatedButton(
              onPressed: input.length < 4
                  ? () => setS(() {
                      input += d;
                      error = null;
                      if (input.length == 4) {
                        if (input == pin) {
                          ok = true;
                          Navigator.of(ctx).pop();
                        } else {
                          error = '密碼錯誤，請再試一次';
                        }
                      }
                    })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.primary,
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
          Widget actionKey(String label, VoidCallback onTap) => SizedBox(
            width: 72,
            height: 60,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.discount.withValues(alpha: 0.15),
                foregroundColor: AppColors.discount,
              ),
              child: Text(label, style: const TextStyle(fontSize: 18)),
            ),
          );
          final masked = ('••••'.substring(0, input.length)).padRight(4, '—');
          return AlertDialog(
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    warningText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.discount,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    promptText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.discount,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.neutralBorder),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.darkCard,
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
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ],
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
                      actionKey(
                        '🧹',
                        () => setS(() {
                          input = '';
                          error = null;
                        }),
                      ),
                      numKey('0'),
                      actionKey(
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
      ),
    );
    return ok;
  }
}

/// 可重用的篩選膠囊按鈕；統一支付方式與標籤篩選的樣式。
class FilterPillButton extends StatelessWidget {
  const FilterPillButton({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.height = 40,
    this.minWidth = 80,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double height;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle baseSel = StyleConfig.payOptionSelectedStyle;
    final ButtonStyle baseUnSel = StyleConfig.payOptionUnselectedStyle;
    final style = (selected ? baseSel : baseUnSel).copyWith(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12),
      ),
      minimumSize: WidgetStateProperty.all(Size(minWidth, height)),
    );
    final buttonChild = SizedBox(
      height: height,
      child: Center(child: child),
    );
    final btn = selected
        ? FilledButton(onPressed: onTap, style: style, child: buttonChild)
        : OutlinedButton(onPressed: onTap, style: style, child: buttonChild);
    return Padding(padding: const EdgeInsets.only(right: 8), child: btn);
  }
}

// 已移除「匯出今日營收圖」與 CSV 匯出相關程式，集中於主銷售頁面。
