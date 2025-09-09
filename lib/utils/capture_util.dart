import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 提供將任意 Widget 以 RepaintBoundary 捕捉為 PNG bytes 的工具。
class CaptureUtil {
  /// 將 widget 以隱形 Overlay 渲染後擷取成 PNG bytes。
  /// pixelRatio：輸出解析度倍率。
  static Future<Uint8List> captureWidget({
    required BuildContext context,
    required Widget Function(GlobalKey key) builder,
    double pixelRatio = 3.0,
  }) async {
  final key = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    final completer = Completer<Uint8List>();
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: 0.01,
            child: Material(
              type: MaterialType.transparency,
              child: builder(key),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      // 等待 2 frame 確保繪製完成
      await Future.delayed(const Duration(milliseconds: 16));
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 16));
      final ro = key.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) {
        // 再給一次機會
        await Future.delayed(const Duration(milliseconds: 32));
        final ro2 = key.currentContext?.findRenderObject();
        if (ro2 is! RenderRepaintBoundary) {
          throw Exception('渲染尚未完成，無法擷取');
        }
        final img2 = await ro2.toImage(pixelRatio: pixelRatio);
        final bd2 = await img2.toByteData(format: ui.ImageByteFormat.png);
        if (bd2 == null) throw Exception('擷取失敗');
        completer.complete(bd2.buffer.asUint8List());
      } else {
        final img = await ro.toImage(pixelRatio: pixelRatio);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        if (bd == null) throw Exception('擷取失敗');
        completer.complete(bd.buffer.asUint8List());
      }
    } finally {
      try { entry.remove(); } catch (_) {}
    }
    return completer.future;
  }
}
