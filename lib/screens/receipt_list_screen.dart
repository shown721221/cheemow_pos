import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../config/app_messages.dart';
import '../models/receipt.dart';
import '../services/local_database_service.dart';
import '../services/receipt_service.dart';
import '../config/constants.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});
  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  late Future<List<Receipt>> _future;
  String _query = '';
  final Set<String> _payFilters = {}; // 現金/轉帳/LinePay
  bool _withDiscount = false;
  bool _withPreorder = false;
  bool _withRefund = false; // 退貨篩選
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
        title: const Text('🧾 收據清單'),
        actions: [
          IconButton(
            tooltip: '清空收據',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await _confirmWithPin(
                warningText: '⚠️ 這會清空所有收據',
                promptText: '✨ 請輸入奇妙數字 ✨',
              );
              if (!ok) return;
              final irreversible = await _confirmIrreversibleDeletion();
              if (!irreversible) return;
              await ReceiptService.instance.clearAllReceipts();
              if (!mounted) return;
              // 使用區塊形式避免 setState 閉包回傳 Future
              setState(() {
                _future = _loadReceipts();
              });
              if (!mounted) return;
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
              final label = _onlyToday ? '僅顯示今日 ($total)' : '全部收據 ($total)';
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
                  return const Center(child: Text('沒有符合條件的收據'));
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
    addSeg('💲' + r.totalAmount.toString());
    addSeg('售出 $nonSpecialQty 件');
    // 使用與商品清單一致的顏色：預購=紫色、折扣=橘色（取自 ProductStyleUtils 規則）
    if (preorderQty > 0) {
      addSeg('預購 $preorderQty 件', color: Colors.purple[700]);
    }
    if (discountQty > 0) {
      addSeg('折扣 $discountQty 件', color: Colors.orange[700]);
    }
    if (r.refundedProductIds.isNotEmpty) {
      // 退貨改用紅色系顯示
      addSeg('已退 ${r.refundedProductIds.length} 件', color: Colors.red.shade600);
    }
    return ListTile(
      dense: true,
      title: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          children: spans,
        ),
        textScaler: const TextScaler.linear(1.0),
      ),
      subtitle: null, // 已將預購/折扣/退貨資訊整合進主摘要行
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showReceiptDetailDialog(r),
    );
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '搜尋收據 ID / 付款方式 / 商品名稱',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _query = v),
    ),
  );

  Widget _buildFilters() {
    FilterChip payChip(String label, String key) => FilterChip(
      label: Text(label),
      selected: _payFilters.contains(key),
      onSelected: (s) => setState(() {
        if (_payFilters.contains(key)) {
          _payFilters.remove(key);
        } else {
          _payFilters.add(key);
        }
      }),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          payChip('💵 現金', PaymentMethods.cash),
          const SizedBox(width: 8),
          payChip('🔁 轉帳', '轉帳'),
          const SizedBox(width: 8),
          payChip('📲 LinePay', 'LinePay'),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('折扣'),
            selected: _withDiscount,
            onSelected: (s) => setState(() => _withDiscount = s),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('預購商品'),
            selected: _withPreorder,
            onSelected: (s) => setState(() => _withPreorder = s),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('退貨'),
            selected: _withRefund,
            onSelected: (s) => setState(() => _withRefund = s),
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
    if (_payFilters.isNotEmpty) {
      list = list.where((r) => _payFilters.contains(r.paymentMethod));
    }
    if (_withDiscount) {
      list = list.where(
        (r) => r.items.any((it) => it.product.isDiscountProduct),
      );
    }
    if (_withPreorder) {
      list = list.where(
        (r) => r.items.any((it) => it.product.isPreOrderProduct),
      );
    }
    if (_withRefund) {
      list = list.where((r) => r.refundedProductIds.isNotEmpty);
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
                    Text('是否要退貨'),
                  ],
                ),
                content: Text(
                  '要退貨「${item.product.name}」嗎？（數量：${item.quantity}）',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c2, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c2, true),
                    child: const Text('確認'),
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
            if (!newRefunded.contains(item.product.id))
              newRefunded.add(item.product.id);
            final hasNonDiscountUnrefunded = current.items.any(
              (it) =>
                  !it.product.isDiscountProduct &&
                  !newRefunded.contains(it.product.id),
            );
            if (!hasNonDiscountUnrefunded) {
              for (final it in current.items.where(
                (e) => e.product.isDiscountProduct,
              )) {
                if (!newRefunded.contains(it.product.id))
                  newRefunded.add(it.product.id);
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
                const Text('收據明細'),
                const Spacer(),
                DropdownButton<String>(
                  value: payment,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: PaymentMethods.cash, child: Text('💵 現金')),
                    DropdownMenuItem(value: '轉帳', child: Text('🔁 轉帳')),
                    DropdownMenuItem(
                      value: 'LinePay',
                      child: Text('📲 LinePay'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null || v == payment) return;
                    final okPin = await _confirmWithPin(
                      warningText: '🔒 變更付款方式需要管理密碼',
                      promptText: '✨ 請輸入奇妙數字 ✨',
                    );
                    if (!okPin) return;
                    final updated = current.copyWith(paymentMethod: v);
                    final saved = await ReceiptService.instance.updateReceipt(
                      updated,
                    );
                    if (saved)
                      setS(() {
                        payment = v;
                        current = updated;
                      });
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
                          color: Colors.black54,
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
                                    ? Colors.red[500]
                                    : (it.product.isDiscountProduct
                                          ? Colors.red[700]
                                          : null),
                                decoration: refunded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '單價 💲${it.product.price} × ${it.quantity}',
                              style: TextStyle(
                                color: refunded ? Colors.red[400] : null,
                                decoration: refunded
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: refunded
                                ? Icon(
                                    Icons.assignment_return,
                                    color: Colors.red[400],
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.assignment_return,
                                      color: Colors.teal,
                                    ),
                                    tooltip: '退貨',
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
                        const Text('合計件數'),
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
                          '💲${current.items.where((i) => !current.refundedProductIds.contains(i.product.id)).fold<int>(0, (s, it) => s + it.subtotal)}',
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
        title: const Text('確認刪除'),
        content: const Text('此動作無法復原，確定要永久刪除所有收據嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('確認刪除'),
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
                      color: Colors.orange[700],
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
                          if (input.isNotEmpty)
                            input = input.substring(0, input.length - 1);
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

// 已移除「匯出今日營收圖」與 CSV 匯出相關程式，集中於主銷售頁面。
