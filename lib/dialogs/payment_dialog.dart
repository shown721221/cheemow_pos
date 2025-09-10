import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../widgets/price_display.dart';
import '../utils/money_formatter.dart';
import '../widgets/numeric_keypad.dart';
import '../config/app_messages.dart';
import '../config/style_config.dart';
import '../utils/money_util.dart';

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
    String method = PaymentMethods.cash;
    final TextEditingController cashController = TextEditingController();

    return showDialog<PaymentResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final String raw = cashController.text.trim();
            final int paidRaw = int.tryParse(raw) ?? 0;
            final int effectivePaid =
                (method == PaymentMethods.cash && raw.isEmpty)
                ? totalAmount
                : paidRaw;
            final int change = method == PaymentMethods.cash
                ? (effectivePaid - totalAmount)
                : 0;
            final bool canConfirm = method == PaymentMethods.cash
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
                          const SizedBox(height: StyleConfig.gap12),
                          // 單行付款方式按鈕
                          Row(
                            children: [
                              Expanded(
                                child: _PayOptionButton(
                                  label: AppMessages.cashLabel,
                                  selected: method == PaymentMethods.cash,
                                  onTap: () => setState(
                                    () => method = PaymentMethods.cash,
                                  ),
                                ),
                              ),
                              const SizedBox(width: StyleConfig.gap8),
                              Expanded(
                                child: _PayOptionButton(
                                  label: AppMessages.transferLabel,
                                  selected: method == PaymentMethods.transfer,
                                  onTap: () => setState(
                                    () => method = PaymentMethods.transfer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: StyleConfig.gap8),
                              Expanded(
                                child: _PayOptionButton(
                                  label: AppMessages.linePayLabel,
                                  selected: method == PaymentMethods.linePay,
                                  onTap: () => setState(
                                    () => method = PaymentMethods.linePay,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: StyleConfig.gap12),
                          if (method == PaymentMethods.cash) ...[
                            TextField(
                              controller: cashController,
                              keyboardType: TextInputType.number,
                              readOnly: true, // 避免平板 IME 失效問題，改用自訂小鍵盤
                              decoration: const InputDecoration(
                                hintText: AppMessages.enterPaidAmount,
                                border: OutlineInputBorder(),
                              ),
                              onTap: () {
                                /* 僅顯示游標，由下方自訂鍵盤輸入 */
                              },
                            ),
                            const SizedBox(height: StyleConfig.gap8),
                            // 動態快速金額（後面三種）
                            Builder(
                              builder: (context) {
                                final suggestions =
                                    MoneyUtil.suggestCashOptions(totalAmount);
                                if (suggestions.isEmpty) {
                                  return const SizedBox.shrink();
                                }
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
                            const SizedBox(height: StyleConfig.gap8),
                            NumericKeypad(
                              keys: const [
                                ['1', '2', '3'],
                                ['4', '5', '6'],
                                ['7', '8', '9'],
                                ['00', '0', '⌫'],
                              ],
                              onKeyTap: (key) {
                                String t = cashController.text;
                                if (key == '⌫') {
                                  if (t.isNotEmpty) {
                                    t = t.substring(0, t.length - 1);
                                  }
                                } else {
                                  t = t + key;
                                }
                                cashController.text = t;
                                setState(() {});
                              },
                            ),
                            const SizedBox(height: StyleConfig.gap8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  AppMessages.changeLabel,
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  change >= 0
                                      ? MoneyFormatter.symbol(change)
                                      : '${AppMessages.insufficient} ${MoneyFormatter.symbol(-change)}',
                                  style: TextStyle(
                                    color: change < 0
                                        ? Colors.red
                                        : Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (method == PaymentMethods.transfer) ...[
                            _PaymentPlaceholder(
                              label: AppMessages.paymentTransferPlaceholder,
                            ),
                          ] else if (method == PaymentMethods.linePay) ...[
                            _PaymentPlaceholder(
                              label: AppMessages.paymentLinePayPlaceholder,
                            ),
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
                              paidCash: method == PaymentMethods.cash
                                  ? effectivePaid
                                  : 0,
                              change: method == PaymentMethods.cash
                                  ? change
                                  : 0,
                            ),
                          );
                        }
                      : null,
                  style: StyleConfig.primaryButtonStyle,
                  child: const Text(AppMessages.confirmPayment),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 已移至 MoneyUtil.suggestCashOptions
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
    final ButtonStyle selectedStyle = StyleConfig.payOptionSelectedStyle;
    final ButtonStyle unselectedStyle = StyleConfig.payOptionUnselectedStyle;
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
