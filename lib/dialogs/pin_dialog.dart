import 'package:flutter/material.dart';
import '../config/app_messages.dart';

/// 通用 PIN 輸入對話框（4 位數字）。
/// 返回 true 代表驗證成功；false 或關閉視窗代表失敗 / 取消。
class PinDialog {
  static Future<bool> show({
    required BuildContext context,
    required String pin,
    String title = AppMessages.pinTitleMagic,
    String? subtitle,
    bool barrierDismissible = true,
  }) async {
    String input = '';
    bool ok = false;

    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget numKey(String d) => SizedBox(
            width: 70,
            height: 56,
            child: ElevatedButton(
              onPressed: input.length < 4
                  ? () => setS(() {
                      input += d;
                      if (input.length == 4) {
                        if (input == pin) {
                          ok = true;
                          Navigator.of(ctx).pop();
                        } else {
                          // 重置重新輸入
                          input = '';
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(AppMessages.pinWrong)),
                          );
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

          List<Widget> buildPinBoxes() {
            return List.generate(4, (i) {
              final filled = i < input.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: filled ? Colors.blueAccent : Colors.grey[300]!,
                    width: filled ? 2 : 1,
                  ),
                  color: filled ? Colors.blue[50] : Colors.white,
                ),
                child: Text(
                  filled ? '•' : '',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              );
            });
          }

          return AlertDialog(
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueGrey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: buildPinBoxes(),
                  ),
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
                      SizedBox(
                        width: 70,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => setS(() => input = ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[50],
                            foregroundColor: Colors.orange[700],
                          ),
                          child: const Icon(Icons.backspace_outlined),
                        ),
                      ),
                      numKey('0'),
                      SizedBox(
                        width: 70,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.grey[700],
                          ),
                          child: const Icon(Icons.close_rounded),
                        ),
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
