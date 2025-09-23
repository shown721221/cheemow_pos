import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../widgets/price_display.dart';
import '../utils/money_formatter.dart';
import '../widgets/numeric_keypad.dart';
import '../config/app_messages.dart';
import '../config/style_config.dart';
import '../config/app_theme.dart';
import '../utils/money_util.dart';
import '../utils/payment_compute.dart';
import '../widgets/payment_method_selector.dart';

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
            final compute = PaymentCompute.evaluate(
              method: method,
              totalAmount: totalAmount,
              rawInput: cashController.text,
            );

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
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomInset > 0 ? 12 : 0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 頂部：左側總金額，右側找零（僅現金）
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: LargePriceDisplay(amount: totalAmount),
                              ),
                              if (method == PaymentMethods.cash)
                                Text(
                                  compute.change >= 0
                                      ? '${AppMessages.changeLabel} ${MoneyFormatter.symbol(compute.change)}'
                                      : '${AppMessages.insufficient} ${MoneyFormatter.symbol(-compute.change)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: compute.change < 0
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: StyleConfig.gap12),
                          // 單行付款方式按鈕
                          PaymentMethodSelector(
                            method: method,
                            onChanged: (m) => setState(() => method = m),
                          ),
                          const SizedBox(height: StyleConfig.gap12),
                          if (method == PaymentMethods.cash) ...[
                            // 先顯示快速金額按鈕（位置已與輸入框交換）
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
                                          label: '💲 ${suggestions[i]}',
                                          selected:
                                              cashController.text ==
                                              suggestions[i].toString(),
                                          onTap: () {
                                            cashController.text = suggestions[i]
                                                .toString();
                                            setState(() {});
                                          },
                                          height: 48,
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
                  onPressed: compute.canConfirm
                      ? () {
                          Navigator.pop(
                            ctx,
                            PaymentResult(
                              method: method,
                              paidCash: method == PaymentMethods.cash
                                  ? compute.effectivePaid
                                  : 0,
                              change: method == PaymentMethods.cash
                                  ? compute.change
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

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  final bool selected;
  const _QuickAmountButton({
    required this.label,
    required this.onTap,
    this.height = 40,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = AppColors.info;
    final bool sel = selected;
    final bg = sel ? baseColor.withValues(alpha: .18) : AppColors.darkCard;
    final border = sel ? baseColor : baseColor.withValues(alpha: .55);
    final fg = sel ? baseColor : baseColor;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size(0, height),
        backgroundColor: bg,
        side: BorderSide(color: border, width: 1.4),
        foregroundColor: fg,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
        border: Border.all(
          color: AppColors.neutralBorder.withValues(alpha: .4),
        ),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.darkCard,
      ),
      child: Text(
        label,
        style: TextStyle(color: AppColors.onDarkSecondary, fontSize: 14),
      ),
    );
  }
}
