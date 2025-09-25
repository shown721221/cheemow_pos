import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/money_formatter.dart';
import '../widgets/numeric_keypad.dart';
import '../config/app_messages.dart';
import '../config/style_config.dart';
import '../config/app_theme.dart';
import '../utils/money_util.dart';
import '../utils/payment_compute.dart';
import '../widgets/payment_method_selector.dart';
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
                          // 頂部：左側總金額，右側找零（僅現金），使用頂對齊避免 baseline 斷言
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: PriceDisplay(
                                  amount: totalAmount,
                                  iconSize: 38,
                                  fontSize: 34,
                                  thousands: true,
                                  color: AppColors.cartTotalNumber,
                                  symbolColor: AppColors.priceSymbol, // 使用 #f9ffd2
                                ),
                              ),
                              if (method == PaymentMethods.cash)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (compute.change >= 0) ...[
                                      // 顯示：找零：金額（無 $ 符號），字體 20，底部對齊左側總金額
                                      Text(
                                        '找零：${MoneyFormatter.thousands(compute.change)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.onDarkSecondary,
                                        ),
                                      ),
                                    ] else ...[
                                      // 不足顯示（沿用紅色）
                                      Text(
                                        '${AppMessages.insufficient} ${MoneyFormatter.symbol(-compute.change)}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ],
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
                            // 輸入框在上
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
                            // 快速金額按鈕在下，文案改為「實收 N」
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
                                          label: '實收 ${suggestions[i]}',
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
                            NumericKeypad(
                              keys: const [
                                ['1', '2', '3'],
                                ['4', '5', '6'],
                                ['7', '8', '9'],
                                ['ESC', '0', '⌫'],
                              ],
                              onKeyTap: (key) {
                                String t = cashController.text;
                                if (key == '⌫') {
                                  if (t.isNotEmpty) {
                                    t = t.substring(0, t.length - 1);
                                  }
                                } else if (key == 'ESC') {
                                  t = '';
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
  // 背景：選取時給淡底色
  final Color bg = sel ? baseColor.withValues(alpha: .20) : Colors.transparent;
  // 邊框：選取時更粗且實色
  final Color border = sel ? baseColor : baseColor.withValues(alpha: .55);
  // 文字全部白色
  const Color fg = Colors.white;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: Size(0, height),
  backgroundColor: bg,
  side: BorderSide(color: border, width: sel ? 2.0 : 1.4),
        foregroundColor: fg,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
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
