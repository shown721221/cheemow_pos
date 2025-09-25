import 'package:flutter/material.dart';
import 'package:cheemeow_pos/config/app_config.dart';
import 'package:cheemeow_pos/config/app_messages.dart';
import 'package:cheemeow_pos/dialogs/pin_dialog.dart';
import '../widgets/price_display.dart';

/// 零用金設定對話框抽離
class PettyCashDialog {
  static Future<void> show(BuildContext context) async {
    final pin = AppConfig.csvImportPin;
    if (AppConfig.pettyCash > 0) {
      final ok = await PinDialog.show(
        context: context,
        pin: pin,
        subtitle: AppMessages.pettyCashCurrent(AppConfig.pettyCash),
      );
      if (!ok) return;
    }
    int tempValue = AppConfig.pettyCash;
    if (!context.mounted) return;
    await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          String current = tempValue == 0 ? '' : tempValue.toString();
          void append(String d) {
            if (current.length >= 7) return;
            current += d;
            setS(() => tempValue = int.tryParse(current) ?? 0);
          }

          void clearAll() {
            setS(() {
              current = '';
              tempValue = 0;
            });
          }

          void confirm() async {
            if (tempValue < 0) return;
            await AppConfig.setPettyCash(tempValue);
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop(tempValue);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppMessages.pettyCashSet(tempValue))),
            );
          }

          Widget priceDisplay() => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Center(
                  child: PriceDisplay(
                    amount: int.tryParse(current.isEmpty ? '0' : current) ?? 0,
                    iconSize: 24,
                    fontSize: 24,
                  ),
                ),
              );

          Widget numKey(String n, VoidCallback onTap) => SizedBox(
            width: 72,
            height: 60,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
              ),
              child: Text(
                n,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          );

          Widget actionKey(String label, VoidCallback onTap) => SizedBox(
            width: 72,
            height: 60,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );

          return AlertDialog(
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    AppMessages.setPettyCash,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  priceDisplay(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('1', () => append('1')),
                      numKey('2', () => append('2')),
                      numKey('3', () => append('3')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('4', () => append('4')),
                      numKey('5', () => append('5')),
                      numKey('6', () => append('6')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      numKey('7', () => append('7')),
                      numKey('8', () => append('8')),
                      numKey('9', () => append('9')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      actionKey('ESC', clearAll),
                      numKey('0', () => append('0')),
                      actionKey('✅', confirm),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
