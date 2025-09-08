import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:media_store_plus/media_store_plus.dart';
import '../services/receipt_service.dart';
import '../services/local_database_service.dart';
import '../models/receipt.dart';
import '../models/cart_item.dart';
import '../config/app_config.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  late Future<List<Receipt>> _future;
  String _query = '';
  final Set<String> _payFilters = {}; // 現金/轉帳/LinePay，可多選
  bool _withDiscount = false;
  bool _withPreorder = false;
  bool _onlyToday = true; // 預設僅顯示今天

  @override
  void initState() {
    super.initState();
    _future = _loadReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收據清單'),
        actions: [
          // 匯出今天（CSV）
          IconButton(
            tooltip: '匯出今天（CSV）',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              await _exportTodayCsv();
            },
          ),
          IconButton(
            tooltip: '清空收據',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              // 先詢問是否要先匯出今天
              final todayReceipts = await ReceiptService.instance.getTodayReceipts();
              final exportFirst = await _askExportBeforeClear(todayReceipts.length);
              if (exportFirst == true) {
                final okExport = await _exportTodayCsv();
                if (!okExport) return; // 匯出失敗中止清空
              } else if (exportFirst == null) {
                return; // 使用者取消
              }

              // PIN 驗證
              final ok = await _confirmWithPin(
                warningText: '⚠️ 這會清空所有收據',
                promptText: '✨ 請輸入奇妙數字 ✨',
              );
              if (!ok) return;

              // 二次不可復原確認
              final irreversible = await _confirmIrreversibleDeletion();
              if (!irreversible) return;

        await ReceiptService.instance.clearAllReceipts();
        if (!context.mounted) return;
              setState(() {
                _future = _loadReceipts();
              });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已清空收據清單')));
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildTodayToggle(),
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
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final refundedIds = r.refundedProductIds;
                    final nonSpecialQty = r.items
                        .where((it) => !it.product.isSpecialProduct && !refundedIds.contains(it.product.id))
                        .fold<int>(0, (s, it) => s + it.quantity);
                    final hh = r.timestamp.hour.toString().padLeft(2, '0');
                    final mm = r.timestamp.minute.toString().padLeft(2, '0');
                    final summary = '${r.id} ・ $hh:$mm ・ ${r.paymentMethod} ・ 售出 $nonSpecialQty 件';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showReceiptDetailDialog(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  summary,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('NT\$${r.totalAmount}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Receipt>> _loadReceipts() async {
    if (_onlyToday) return ReceiptService.instance.getTodayReceipts();
    return ReceiptService.instance.getReceipts();
  }

  Widget _buildTodayToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Switch(
            value: _onlyToday,
            onChanged: (v) {
              setState(() {
                _onlyToday = v;
                _future = _loadReceipts();
              });
            },
          ),
          const Text('只看今天'),
          const Spacer(),
        ],
      ),
    );
  }

  // 搜尋列
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜尋收據 / 商品名稱 / 付款方式',
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: '清除',
                  onPressed: () => setState(() => _query = ''),
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) => setState(() => _query = v.trim()),
      ),
    );
  }

  // 篩選（付款、多選；折扣；預購）
  Widget _buildFilters() {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onSelected,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(
            label: '💵 現金',
            selected: _payFilters.contains('現金'),
            onSelected: () => setState(() {
              if (_payFilters.contains('現金')) {
                _payFilters.remove('現金');
              } else {
                _payFilters.add('現金');
              }
            }),
          ),
          chip(
            label: '🔁 轉帳',
            selected: _payFilters.contains('轉帳'),
            onSelected: () => setState(() {
              if (_payFilters.contains('轉帳')) {
                _payFilters.remove('轉帳');
              } else {
                _payFilters.add('轉帳');
              }
            }),
          ),
          chip(
            label: '📲 LinePay',
            selected: _payFilters.contains('LinePay'),
            onSelected: () => setState(() {
              if (_payFilters.contains('LinePay')) {
                _payFilters.remove('LinePay');
              } else {
                _payFilters.add('LinePay');
              }
            }),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('折扣'),
            selected: _withDiscount,
            onSelected: (s) => setState(() => _withDiscount = s),
          ),
          FilterChip(
            label: const Text('預購商品'),
            selected: _withPreorder,
            onSelected: (s) => setState(() => _withPreorder = s),
          ),
        ],
      ),
    );
  }

  // 應用搜尋和篩選
  List<Receipt> _applyFilters(List<Receipt> receipts) {
    Iterable<Receipt> list = receipts;

    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final inId = r.id.toLowerCase().contains(q);
        final inPay = r.paymentMethod.toLowerCase().contains(q);
        final inItems = r.items.any((it) => it.product.name.toLowerCase().contains(q));
        return inId || inPay || inItems;
      });
    }

    if (_payFilters.isNotEmpty) {
      list = list.where((r) => _payFilters.contains(r.paymentMethod));
    }

    if (_withDiscount) {
      list = list.where((r) => r.items.any((it) => it.product.isDiscountProduct));
    }
    if (_withPreorder) {
      list = list.where((r) => r.items.any((it) => it.product.isPreOrderProduct));
    }

    return list.toList();
  }

  // 明細對話框：可修改付款方式、逐品退貨
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
                title: Row(children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('是否要退貨'),
                ]),
                content: Text('要退貨「${item.product.name}」嗎？（數量：${item.quantity}）'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(c2, true), child: const Text('確認')),
                ],
              ),
            );
            if (confirm != true) return;

            // 回補庫存（非特殊商品）
            if (!item.product.isSpecialProduct) {
              final products = await LocalDatabaseService.instance.getProducts();
              final idx = products.indexWhere((p) => p.id == item.product.id);
              final currentStock = idx >= 0 ? products[idx].stock : item.product.stock;
              await LocalDatabaseService.instance
                  .updateProductStock(item.product.id, currentStock + item.quantity);
            }

            // 標記退貨（保留明細）
            final newRefunded = List<String>.from(current.refundedProductIds);
            if (!newRefunded.contains(item.product.id)) newRefunded.add(item.product.id);

            // 若退貨後只剩折扣，則折扣一併標記退貨
            final hasNonDiscountUnrefunded = current.items.any(
              (it) => !it.product.isDiscountProduct && !newRefunded.contains(it.product.id),
            );
            if (!hasNonDiscountUnrefunded) {
              for (final it in current.items.where((e) => e.product.isDiscountProduct)) {
                if (!newRefunded.contains(it.product.id)) newRefunded.add(it.product.id);
              }
            }

            final effectiveItems = current.items.where((it) => !newRefunded.contains(it.product.id));
            final newTotal = effectiveItems.fold<int>(0, (s, it) => s + it.subtotal);
            final newQty = effectiveItems.fold<int>(0, (s, it) => s + it.quantity);

            final updated = current.copyWith(
              refundedProductIds: newRefunded,
              totalAmount: newTotal,
              totalQuantity: newQty,
            );

            final saved = await ReceiptService.instance.updateReceipt(updated);
            if (saved) {
              setS(() {
                current = updated;
              });
            }
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
                    DropdownMenuItem(value: '現金', child: Text('💵 現金')),
                    DropdownMenuItem(value: '轉帳', child: Text('🔁 轉帳')),
                    DropdownMenuItem(value: 'LinePay', child: Text('📲 LinePay')),
                  ],
                  onChanged: (v) async {
                    if (v == null || v == payment) return;
                    final okPin = await _confirmWithPin(
                      warningText: '🔒 變更付款方式需要管理密碼',
                      promptText: '✨ 請輸入奇妙數字 ✨',
                    );
                    if (!okPin) return;
                    final updated = current.copyWith(paymentMethod: v);
                    final saved = await ReceiptService.instance.updateReceipt(updated);
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
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: current.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (_, idx) {
                          final it = current.items[idx];
                          final isDiscount = it.product.isDiscountProduct;
                          final price = it.product.price;
                          final qty = it.quantity;
                          final refunded = current.refundedProductIds.contains(it.product.id);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                            title: Text(
                              it.product.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: refunded ? Colors.grey : (isDiscount ? Colors.red[700] : null),
                                decoration: refunded ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              '單價 NT\$$price × $qty',
                              style: TextStyle(
                                color: refunded ? Colors.grey : null,
                                decoration: refunded ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            trailing: refunded
                                ? const Icon(Icons.assignment_return, color: Colors.grey)
                                : IconButton(
                                    icon: const Icon(Icons.assignment_return, color: Colors.teal),
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
                        Text('${current.items.where((i) => !current.refundedProductIds.contains(i.product.id)).fold<int>(0, (s, it) => s + it.quantity)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('總金額', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          'NT\$${current.items.where((i) => !current.refundedProductIds.contains(i.product.id)).fold<int>(0, (s, it) => s + it.subtotal)}',
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

  // 通用 PIN 驗證對話框
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
      builder: (ctx) {
        return StatefulBuilder(
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    Text(promptText, textAlign: TextAlign.center),
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
                      Text(error!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
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
                        actionKey('🧹', () => setS(() {
                              input = '';
                              error = null;
                            })),
                        numKey('0'),
                        actionKey('⌫', () => setS(() {
                              if (input.isNotEmpty) {
                                input = input.substring(0, input.length - 1);
                              }
                              error = null;
                            })),
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

  // 問是否先匯出今天（回傳 true=要匯出、false=不要匯出、null=取消）
  Future<bool?> _askExportBeforeClear(int todayCount) async {
    return showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空收據'),
        content: Text('今天共有 $todayCount 筆。清空前要先匯出今天的收據（CSV）嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('不要匯出')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('先匯出 CSV')),
        ],
      ),
    );
  }

  // 匯出今天（CSV）到可存取位置：
  // - Android: 公用 Downloads/cheemow_pos（根目錄，檔名含日期）
  // - Windows/Linux/macOS: 系統 Downloads
  // - iOS: 應用文件夾（無公用 Downloads）
  // 內容只含實際商品：排除預購/折扣、且排除已退貨項目；預購/折扣另存一份「特殊明細」
  Future<bool> _exportTodayCsv() async {
    try {
      final receipts = await ReceiptService.instance.getTodayReceipts();
      // 準備主檔 CSV 列（標題 + 內容列）
      final rows = <List<dynamic>>[];
      rows.add([
        'receipt_id', 'date', 'time', 'payment', 'payment_code', 'product_code', 'product_name', 'barcode', 'quantity', 'category',
      ]);

      // 特殊項（預購/折扣）另存一份可查詢的 CSV
      final specialRows = <List<dynamic>>[];
      specialRows.add([
        'receipt_id', 'date', 'time', 'payment', 'payment_code', 'special_type', 'product_code', 'product_name', 'barcode', 'quantity', 'unit_price', 'subtotal',
      ]);

      for (final r in receipts) {
        final refunded = r.refundedProductIds.toSet();
        final dt = r.timestamp;
        final y = dt.year.toString().padLeft(4, '0');
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        final dateStr = '$y-$m-$d';
        final timeStr = '$hh:$mm';

        final paymentCode = r.id.split('-').first;
        for (final it in r.items) {
          final p = it.product;
          final isPre = p.isPreOrderProduct;
          final isDisc = p.isDiscountProduct;
          final isReal = !isPre && !isDisc;
          final isRefunded = refunded.contains(p.id);
          if (isRefunded) continue;

          // 為避免 Excel 去除前導 0，使用 ="..." 的文字公式格式
          final codeText = '="${p.id}"';
          final barcodeText = '="${p.barcode}"';

          if (isReal) {
            rows.add([
              r.id,
              dateStr,
              timeStr,
              r.paymentMethod,
              paymentCode,
              codeText,
              p.name,
              barcodeText,
              it.quantity,
              p.category,
            ]);
          } else {
            final specialType = isPre ? '預購' : '折扣';
            specialRows.add([
              r.id,
              dateStr,
              timeStr,
              r.paymentMethod,
              paymentCode,
              specialType,
              codeText,
              p.name,
              barcodeText,
              it.quantity,
              p.price,
              it.subtotal,
            ]);
          }
        }
      }

      final csvStr = const ListToCsvConverter().convert(rows);
      final specialCsvStr = const ListToCsvConverter().convert(specialRows);

      // 檔名（放在 cheemow_pos 根目錄即可，避免子資料夾難找）
  final now = DateTime.now();
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      final yy = (now.year % 100).toString().padLeft(2, '0');
      final fileName = '銷售_$yy$m$d.csv';
      final fileNameSpecial = '銷售_$yy$m${d}_特殊明細.csv';

      // 準備 CSV bytes（含 BOM）
      final csvBytes = utf8.encode(csvStr);
      final specialBytes = utf8.encode(specialCsvStr);
      final withBom = <int>[0xEF, 0xBB, 0xBF, ...csvBytes];
      final withBomSpecial = <int>[0xEF, 0xBB, 0xBF, ...specialBytes];

      String? savedPathMain;
      String? savedPathSpecial;

      if (Platform.isAndroid) {
        // Android: 使用 MediaStore 存到公用 Downloads/cheemow_pos 根目錄
        File? tmpMain;
        File? tmpSpecial;
        try {
          final tmpDir = await getTemporaryDirectory();
          tmpMain = File('${tmpDir.path}/$fileName');
          tmpSpecial = File('${tmpDir.path}/$fileNameSpecial');
          await tmpMain.writeAsBytes(withBom, flush: true);
          await tmpSpecial.writeAsBytes(withBomSpecial, flush: true);

          await MediaStore.ensureInitialized();
          final mediaStore = MediaStore();
          MediaStore.appFolder = 'cheemow_pos';

          final saveMain = await mediaStore.saveFile(
            tempFilePath: tmpMain.path,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: FilePath.root,
          );
          savedPathMain = saveMain?.uri.toString();
          if (savedPathMain != null) {
            final p = await mediaStore.getFilePathFromUri(uriString: savedPathMain);
            if (p != null) savedPathMain = p;
          }

          final saveSpecial = await mediaStore.saveFile(
            tempFilePath: tmpSpecial.path,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: FilePath.root,
          );
          savedPathSpecial = saveSpecial?.uri.toString();
          if (savedPathSpecial != null) {
            final p = await mediaStore.getFilePathFromUri(uriString: savedPathSpecial);
            if (p != null) savedPathSpecial = p;
          }
        } finally {
          try { await tmpMain?.delete(); } catch (_) {}
          try { await tmpSpecial?.delete(); } catch (_) {}
        }

        if (!mounted) return savedPathMain != null || savedPathSpecial != null;
        if (savedPathMain != null || savedPathSpecial != null) {
          final lines = <String>[];
          if (savedPathMain != null) lines.add('下載: $savedPathMain');
          if (savedPathSpecial != null) lines.add('下載: $savedPathSpecial');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已匯出 CSV\n${lines.join('\n')}')),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('匯出失敗：無法寫入公用 Downloads')),
          );
          return false;
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // 桌面：寫入系統 Downloads
        final downloads = await getDownloadsDirectory();
        final base = downloads?.path;
        if (base == null) {
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('匯出失敗：找不到系統 Downloads')),
          );
          return false;
        }
        File? fileMain;
        File? fileSpecial;
        try {
          fileMain = File('$base/$fileName');
          fileSpecial = File('$base/$fileNameSpecial');
          await fileMain.writeAsBytes(withBom, flush: true);
          await fileSpecial.writeAsBytes(withBomSpecial, flush: true);
          savedPathMain = fileMain.path;
          savedPathSpecial = fileSpecial.path;
        } catch (e) {
          // 若只寫入其中一個，仍視為成功但顯示對應資訊
        }
        if (!mounted) return savedPathMain != null || savedPathSpecial != null;
        final lines = <String>[];
        if (savedPathMain != null) lines.add('下載: $savedPathMain');
        if (savedPathSpecial != null) lines.add('下載: $savedPathSpecial');
        if (lines.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已匯出 CSV\n${lines.join('\n')}')),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('匯出失敗：無法寫入 Downloads')),
          );
          return false;
        }
      } else {
        // iOS：寫入應用文件夾
        final docs = await getApplicationDocumentsDirectory();
        final fileMain = File('${docs.path}/$fileName');
        final fileSpecial = File('${docs.path}/$fileNameSpecial');
        await fileMain.writeAsBytes(withBom, flush: true);
        await fileSpecial.writeAsBytes(withBomSpecial, flush: true);
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已匯出 CSV\n儲存: ${fileMain.path}\n儲存: ${fileSpecial.path}')),
        );
        return true;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('匯出失敗: $e')),
      );
      return false;
    }
  }

  // 已移除「匯出今日營收圖」功能，改移至銷售頁更多功能選單
}
