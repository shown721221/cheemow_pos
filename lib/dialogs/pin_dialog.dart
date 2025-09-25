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
    bool subtitleEmphasis = false,
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
            height: 60,
            child: OutlinedButton(
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
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
              ),
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      decoration: subtitleEmphasis
                          ? BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            )
                          : null,
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: subtitleEmphasis
                              ? Colors.deepOrange
                              : Colors.deepOrange,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
                    children: [
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('1'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('2'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('3'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('4'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('5'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('6'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('7'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('8'))),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('9'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                              onPressed: () => setS(() => input = ''),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 0,
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'ESC',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: numKey('0'))),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: SizedBox(
                            height: 60,
                            child: OutlinedButton(
                              onPressed: () => setS(() {
                                if (input.isNotEmpty) {
                                  input = input.substring(0, input.length - 1);
                                }
                              }),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 0,
                                ),
                              ),
                              child: const Icon(
                                Icons.backspace_outlined,
                                color: Colors.white,
                                size: 28, // 放大倒退圖示
                              ),
                            ),
                          ),
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
