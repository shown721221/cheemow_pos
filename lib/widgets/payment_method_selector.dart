import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/app_messages.dart';
import '../config/style_config.dart';
import 'payment_option_button.dart';

/// 支付方式選擇列；後續若新增方式只要在 children 中擴充。
class PaymentMethodSelector extends StatelessWidget {
  final String method; // 當前選擇
  final ValueChanged<String> onChanged;
  const PaymentMethodSelector({
    super.key,
    required this.method,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PaymentOptionButton(
            label: '💰',
            selected: method == PaymentMethods.cash,
            onTap: () => onChanged(PaymentMethods.cash),
            // 放大現金 emoji 與銀行一致
            textStyle: const TextStyle(fontSize: 28),
          ),
        ),
        const SizedBox(width: StyleConfig.gap8),
        Expanded(
          child: PaymentOptionButton(
            label: AppMessages.transferLabel,
            selected: method == PaymentMethods.transfer,
            onTap: () => onChanged(PaymentMethods.transfer),
            // 放大銀行 emoji
            textStyle: const TextStyle(fontSize: 28),
          ),
        ),
        const SizedBox(width: StyleConfig.gap8),
        Expanded(
          child: PaymentOptionButton(
            label: AppMessages.linePayLabel,
            selected: method == PaymentMethods.linePay,
            onTap: () => onChanged(PaymentMethods.linePay),
            imageAsset: 'assets/images/linepay.png',
          ),
        ),
      ],
    );
  }
}
