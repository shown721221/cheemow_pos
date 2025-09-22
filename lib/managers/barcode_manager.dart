import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cheemeow_pos/utils/app_logger.dart';

/// 條碼掃描管理器
class BarcodeManager {
  String _scanBuffer = '';
  Timer? _scanTimer;
  Function(String)? _onBarcodeComplete;

  /// 初始化掃描管理器
  void initialize({Function(String)? onBarcodeComplete}) {
    _onBarcodeComplete = onBarcodeComplete;
  }

  /// 處理單個字符輸入
  void handleCharacterInput(String character) {
    // 清除之前的計時器
    _scanTimer?.cancel();

    // 添加字符到緩衝區
    _scanBuffer += character;

    // 設置新的計時器，如果在指定時間內沒有新字符，則視為條碼完成
    _scanTimer = Timer(const Duration(milliseconds: 100), () {
      if (_scanBuffer.isNotEmpty) {
        final barcode = _scanBuffer.trim();
        _scanBuffer = '';

        if (kDebugMode) {
          AppLogger.d('條碼掃描完成: $barcode');
        }

        _onBarcodeComplete?.call(barcode);
      }
    });
  }

  /// 清理資源
  void dispose() {
    _scanTimer?.cancel();
  }
}
