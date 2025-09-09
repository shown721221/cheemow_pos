import 'package:flutter/material.dart';

/// 通用 PIN 輸入對話框（4 位數字）。
/// 返回 true 代表驗證成功；false 或關閉視窗代表失敗 / 取消。
class PinDialog {
  static Future<bool> show({
    required BuildContext context,
    required String pin,
    String title = '✨ 請輸入奇妙數字 ✨',
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

          return AlertDialog(
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Text(
                      ('••••'.substring(0, input.length)).padRight(4, '—'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                          child: const Text('清除'),
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
                          child: const Text('取消'),
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
