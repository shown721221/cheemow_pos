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
import '../dialogs/pin_dialog.dart';

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
    await ReceiptService.instance.initialize();
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
              final ok = await PinDialog.show(
                context: context,
                pin: AppConfig.csvImportPin,
                subtitle: AppMessages.warningClearReceipts,
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
    if (r.items.isNotEmpty) {
      int refundedCount = 0;
      for (final it in r.items) {
        refundedCount += r.refundedQtyFor(it.product.id, it.quantity);
      }
      if (refundedCount > 0) {
        addSeg('已退 $refundedCount 件', color: AppColors.error);
      }
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
          // 與結帳視覺一致但使用穩定的膠囊按鈕（寬度有約束）
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.cash,
            onTap: () => selectPay(PaymentMethods.cash),
            minWidth: 72,
            height: 44,
            child: const Text('💰', style: TextStyle(fontSize: 20)),
          ),
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.transfer,
            onTap: () => selectPay(PaymentMethods.transfer),
            minWidth: 72,
            height: 44,
            child: Image.asset(
              'assets/images/cathay.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text(AppMessages.transferLabel),
            ),
          ),
          FilterPillButton(
            selected: _selectedPay == PaymentMethods.linePay,
            onTap: () => selectPay(PaymentMethods.linePay),
            minWidth: 72,
            height: 44,
            child: Image.asset(
              'assets/images/linepay.png',
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text(AppMessages.linePayLabel),
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 8),
          FilterPillButton(
            selected: _tagFilter == 'discount',
            onTap: () => selectTag('discount'),
            minWidth: 72,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💸', style: TextStyle(fontSize: 16)),
                SizedBox(width: 4),
                Text('折扣'),
              ],
            ),
          ),
          FilterPillButton(
            selected: _tagFilter == 'preorder',
            onTap: () => selectTag('preorder'),
            minWidth: 72,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎁', style: TextStyle(fontSize: 16)),
                SizedBox(width: 4),
                Text('預購商品'),
              ],
            ),
          ),
          FilterPillButton(
            selected: _tagFilter == 'refund',
            onTap: () => selectTag('refund'),
            minWidth: 72,
            child: const Text(AppMessages.chipRefund),
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
            final purchased = item.quantity;
            final alreadyRefunded = current.refundedQtyFor(
              item.product.id,
              purchased,
            );
            final remaining = (purchased - alreadyRefunded).clamp(0, purchased);
            if (remaining <= 0) return;

            int? chooseQty = await showDialog<int>(
              context: ctx,
              barrierDismissible: true,
              builder: (c2) {
                int currentVal = remaining > 0 ? 1 : 0;
                return StatefulBuilder(
                  builder: (c2, setLocal) => AlertDialog(
                    title: Row(
                      children: const [
                        Icon(Icons.assignment_return, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('設定退貨數量'),
                      ],
                    ),
                    content: SizedBox(
                      width: 360,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text('可退：$remaining 件'),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Text(
                              '選擇：$currentVal 件',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: currentVal > 0
                                        ? () => setLocal(() {
                                            currentVal = (currentVal - 1).clamp(
                                              0,
                                              remaining,
                                            );
                                          })
                                        : null,
                                    child: const Text(
                                      '-',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: currentVal < remaining
                                        ? () => setLocal(() {
                                            currentVal = (currentVal + 1).clamp(
                                              0,
                                              remaining,
                                            );
                                          })
                                        : null,
                                    child: const Text(
                                      '+',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: currentVal > 0
                            ? () => Navigator.pop(c2, currentVal)
                            : null,
                        child: const Text(AppMessages.confirm),
                      ),
                    ],
                  ),
                );
              },
            );
            if (chooseQty == null) return;

            // 更新庫存（非特殊商品）
            if (!item.product.isSpecialProduct) {
              final products = await LocalDatabaseService.instance
                  .getProducts();
              final idx = products.indexWhere((p) => p.id == item.product.id);
              final stock = idx >= 0 ? products[idx].stock : item.product.stock;
              await LocalDatabaseService.instance.updateProductStock(
                item.product.id,
                stock + chooseQty,
              );
            }

            // 更新退貨映射與舊欄位相容
            final newRefundedIds = List<String>.from(
              current.refundedProductIds,
            );
            final newMap = Map<String, int>.from(current.refundedQuantities);
            final nowRefunded = (newMap[item.product.id] ?? 0) + chooseQty;
            final clamped = nowRefunded.clamp(0, purchased);
            newMap[item.product.id] = clamped;
            if (clamped >= purchased) {
              if (!newRefundedIds.contains(item.product.id)) {
                newRefundedIds.add(item.product.id);
              }
            } else {
              newRefundedIds.remove(item.product.id);
            }

            // 若所有「非折扣」品項皆已無剩餘數量，則將折扣品也一併標記為退貨（全退）
            bool hasNonDiscountRemaining = current.items.any((it) {
              if (it.product.isDiscountProduct) return false;
              final refunded = (it.product.id == item.product.id
                  ? clamped
                  : (newMap[it.product.id] ?? 0));
              return refunded < it.quantity;
            });
            if (!hasNonDiscountRemaining) {
              for (final it in current.items.where(
                (e) => e.product.isDiscountProduct,
              )) {
                newMap[it.product.id] = it.quantity;
                if (!newRefundedIds.contains(it.product.id)) {
                  newRefundedIds.add(it.product.id);
                }
              }
            }

            // 以剩餘數量重算總額與件數
            int newTotal = 0;
            int newQty = 0;
            for (final it in current.items) {
              final refunded = newMap[it.product.id] ?? 0;
              final remain = (it.quantity - refunded).clamp(0, it.quantity);
              if (remain <= 0) continue;
              newQty += remain;
              newTotal += it.product.price * remain;
            }

            final updated = current.copyWith(
              refundedProductIds: newRefundedIds,
              refundedQuantities: newMap,
              totalAmount: newTotal,
              totalQuantity: newQty,
            );
            final saved = await ReceiptService.instance.updateReceipt(updated);
            if (saved) setS(() => current = updated);
          }

          return AlertDialog(
            title: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                const Text(AppMessages.receiptDetailsTitle),
                DropdownButton<String>(
                  value: payment,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: PaymentMethods.cash,
                      child: Text(PaymentMethods.cash),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethods.transfer,
                      child: Text(PaymentMethods.transfer),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethods.linePay,
                      child: Text(PaymentMethods.linePay),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null || v == payment) return;
                    final okPin = await PinDialog.show(
                      context: context,
                      pin: AppConfig.csvImportPin,
                      subtitle: AppMessages.changePaymentPinWarning,
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
                          final fullyRefunded = current.isFullyRefunded(
                            it.product.id,
                            it.quantity,
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
                                color: fullyRefunded
                                    ? AppColors.error
                                    : (it.product.isDiscountProduct
                                          ? AppColors.discount
                                          : (it.product.isPreOrderProduct
                                                ? AppColors.preorder
                                                : AppColors.onDarkPrimary)),
                                decoration: fullyRefunded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Builder(
                              builder: (_) {
                                final refunded = current.refundedQtyFor(
                                  it.product.id,
                                  it.quantity,
                                );
                                final remain = (it.quantity - refunded).clamp(
                                  0,
                                  it.quantity,
                                );
                                final text = remain == it.quantity
                                    ? '單價 ${MoneyFormatter.symbol(it.product.price)} × ${it.quantity}'
                                    : '單價 ${MoneyFormatter.symbol(it.product.price)} × $remain（已退$refunded）';
                                return Text(
                                  text,
                                  style: TextStyle(
                                    color: fullyRefunded
                                        ? AppColors.error
                                        : AppColors.onDarkSecondary,
                                    decoration: fullyRefunded
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                );
                              },
                            ),
                            trailing: fullyRefunded
                                ? const Icon(
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
                        Text(() {
                          int qty = 0;
                          for (final it in current.items) {
                            final refunded = current.refundedQtyFor(
                              it.product.id,
                              it.quantity,
                            );
                            qty += (it.quantity - refunded).clamp(
                              0,
                              it.quantity,
                            );
                          }
                          return '$qty';
                        }()),
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
                          () {
                            int total = 0;
                            for (final it in current.items) {
                              final refunded = current.refundedQtyFor(
                                it.product.id,
                                it.quantity,
                              );
                              final remain = (it.quantity - refunded).clamp(
                                0,
                                it.quantity,
                              );
                              total += it.product.price * remain;
                            }
                            return MoneyFormatter.symbol(total);
                          }(),
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
