import 'package:flutter/material.dart';
import '../widgets/price_display.dart';

class PaymentResult {
  final String method; // 現金/轉帳/LinePay
  final int paidCash; // 若為現金，實收金額（未輸入 = 剛好）
  final int change; // 找零

  PaymentResult({
    required this.method,
    required this.paidCash,
    required this.change,
  });
}

class PaymentDialog {
  static Future<PaymentResult?> show(
    BuildContext context, {
    required int totalAmount,
  }) async {
    String method = '現金';
    final TextEditingController cashController = TextEditingController();

    return showDialog<PaymentResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final String raw = cashController.text.trim();
            final int paidRaw = int.tryParse(raw) ?? 0;
            final int effectivePaid = (method == '現金' && raw.isEmpty)
                ? totalAmount
                : paidRaw;
            final int change = method == '現金'
                ? (effectivePaid - totalAmount)
                : 0;
            final bool canConfirm = method == '現金'
                ? (raw.isEmpty || paidRaw >= totalAmount)
                : true;

            return AlertDialog(
              title: null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              scrollable: true,
              content: Builder(
                builder: (innerCtx) {
                  final bottomInset = MediaQuery.of(innerCtx).viewInsets.bottom;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomInset > 0 ? 12 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顯示應收金額（僅數字）
                          Align(
                            alignment: Alignment.centerRight,
                            child: LargePriceDisplay(amount: totalAmount),
                          ),
                          const SizedBox(height: 12),
                          // 單行付款方式按鈕
                          Row(
                            children: [
                              Expanded(
                                child: _PayOptionButton(
                                  label: '💵 現金',
                                  selected: method == '現金',
                                  onTap: () => setState(() => method = '現金'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PayOptionButton(
                                  label: '🔁 轉帳',
                                  selected: method == '轉帳',
                                  onTap: () => setState(() => method = '轉帳'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PayOptionButton(
                                  label: '📲 LinePay',
                                  selected: method == 'LinePay',
                                  onTap: () =>
                                      setState(() => method = 'LinePay'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (method == '現金') ...[
                            TextField(
                              controller: cashController,
                              keyboardType: TextInputType.number,
                              readOnly: true, // 避免平板 IME 失效問題，改用自訂小鍵盤
                              decoration: const InputDecoration(
                                hintText: '輸入實收金額',
                                border: OutlineInputBorder(),
                              ),
                              onTap: () {
                                /* 僅顯示游標，由下方自訂鍵盤輸入 */
                              },
                            ),
                            const SizedBox(height: 8),
                            // 動態快速金額（台幣面額 50/100/500/1000 的「後面三種」）
                            Builder(
                              builder: (context) {
                                final suggestions = _suggestCashOptions(
                                  totalAmount,
                                );
                                if (suggestions.isEmpty)
                                  return const SizedBox.shrink();
                                return Row(
                                  children: [
                                    for (
                                      int i = 0;
                                      i < suggestions.length;
                                      i++
                                    ) ...[
                                      Expanded(
                                        child: _QuickAmountButton(
                                          label: suggestions[i].toString(),
                                          onTap: () {
                                            cashController.text = suggestions[i]
                                                .toString();
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      if (i != suggestions.length - 1)
                                        const SizedBox(width: 8),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _NumericKeypad(
                              onKey: (key) {
                                String t = cashController.text;
                                if (key == '⌫') {
                                  if (t.isNotEmpty)
                                    t = t.substring(0, t.length - 1);
                                } else {
                                  t = t + key;
                                }
                                cashController.text = t;
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  '找零',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  change >= 0
                                      ? '💲 $change'
                                      : '不足 💲 ${-change}',
                                  style: TextStyle(
                                    color: change < 0
                                        ? Colors.red
                                        : Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (method == '轉帳') ...[
                            _PaymentPlaceholder(label: '預留：轉帳帳號圖片/資訊'),
                          ] else if (method == 'LinePay') ...[
                            _PaymentPlaceholder(label: '預留：LinePay QR Code 圖片'),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              actions: [
                ElevatedButton(
                  onPressed: canConfirm
                      ? () {
                          Navigator.pop(
                            ctx,
                            PaymentResult(
                              method: method,
                              paidCash: method == '現金' ? effectivePaid : 0,
                              change: method == '現金' ? change : 0,
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('確認付款'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 依台幣常見面額（50/100/500/1000）計算大於等於應收金額的「後面三種」可能實收金額
  static List<int> _suggestCashOptions(int total) {
    int ceilTo(int base) {
      if (base <= 0) return total;
      final m = total % base;
      return m == 0 ? total : total + (base - m);
    }

    // 先找各面額的「向上取整」
    final s50 = ceilTo(50);
    final s100 = ceilTo(100);
    final s500 = ceilTo(500);
    final s1000 = ceilTo(1000);

    // 蒐集候選值（可能會有與 total 相等的值，代表剛好）
    final candidates = <int>{s50, s100, s500, s1000, total};
    // 移除小於 total 的（保險起見）
    final filtered = candidates.where((v) => v >= total).toList()..sort();

    // 去除剛好，取唯一並排序
    final uniqueAsc = filtered.where((v) => v > total).toSet().toList()..sort();

    if (uniqueAsc.length <= 3) return uniqueAsc;
    // 一律取「最後三個」（最大三個）
    return uniqueAsc.sublist(uniqueAsc.length - 3);
  }
}

class _PayOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PayOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle selectedStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    );
    final ButtonStyle unselectedStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
    );
    return selected
        ? FilledButton(
            onPressed: onTap,
            style: selectedStyle,
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onTap,
            style: unselectedStyle,
            child: Text(label),
          );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 40),
      ),
      child: Text(label),
    );
  }
}

class _PaymentPlaceholder extends StatelessWidget {
  final String label;
  const _PaymentPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Text(label, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final void Function(String key) onKey;
  const _NumericKeypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', '⌫'],
    ];
    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((k) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton(
                      onPressed: () => onKey(k),
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
