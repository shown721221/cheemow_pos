import 'package:flutter/foundation.dart';

/// 簡易集中式 Logger
/// - 支援等級: debug / info / warn / error
/// - release 模式自動只輸出 warn 以上
/// - 可透過 [AppLogger.enabled] 全域關閉（仍保留 error）
class AppLogger {
  AppLogger._();

  /// 是否啟用一般輸出（debug/info/warn）
  static bool enabled = true;

  /// 是否顯示 debug 等級
  static bool debugEnabled = true;

  static String _ts() => DateTime.now().toIso8601String();

  static void d(String message) {
    if (!enabled) return;
    if (!kDebugMode) return; // 只在 debug/profile 顯示
    if (!debugEnabled) return;
    debugPrint('[D][${_ts()}] $message');
  }

  static void i(String message) {
    if (!enabled) return;
    if (!kDebugMode) return; // release 不輸出 info
    debugPrint('[I][${_ts()}] $message');
  }

  static void w(String message, [Object? err, StackTrace? st]) {
    if (!enabled && !kDebugMode) return;
    // warn 在 release 仍允許（若完全關閉可再判斷 enabled）
    final buf = StringBuffer('[W][${_ts()}] $message');
    if (err != null) buf.write(' err=$err');
    if (st != null) buf.write('\n$st');
    debugPrint(buf.toString());
  }

  static void e(String message, [Object? err, StackTrace? st]) {
    final buf = StringBuffer('[E][${_ts()}] $message');
    if (err != null) buf.write(' err=$err');
    if (st != null) buf.write('\n$st');
    debugPrint(buf.toString());
  }
}
