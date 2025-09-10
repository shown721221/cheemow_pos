import 'package:flutter/material.dart';
import '../config/app_messages.dart';

/// 系統相關對話框
class SystemDialogs {
  
  /// 顯示載入對話框
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  /// 關閉載入對話框
  static void closeLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// 顯示錯誤對話框
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(AppMessages.confirm),
            ),
          ],
        );
      },
    );
  }

  /// 顯示即將推出功能的對話框
  static void showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
      title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
        Text(AppMessages.comingSoonTitle),
            ],
          ),
      content: Text(AppMessages.comingSoonContent(feature)),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
        child: const Text(AppMessages.confirm),
            ),
          ],
        );
      },
    );
  }
}
