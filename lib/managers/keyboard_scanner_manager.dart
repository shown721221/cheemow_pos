import 'dart:async';
import 'package:flutter/services.dart';

/// 鍵盤和條碼掃描處理管理器
/// 負責處理鍵盤事件和條碼掃描邏輯
class KeyboardScannerManager {
  String _scanBuffer = '';
  Timer? _scanTimer;
  final Function(String) onBarcodeScanned;

  // 條碼掃描配置
  // 基本 timeout（會被動態調整）
  // 原先 timeout 過短（12~30ms 尾端），可能導致尚未全部鍵入就被截斷
  // 放寬基準 timeout 以增加完整讀取成功率
  static const Duration _defaultTimeout = Duration(milliseconds: 120);
  // 啟用純掃描模式（使用者表示不會人工輸入）
  static const bool _scannerOnlyMode = true;
  // 快速掃描（硬體條碼槍）常見鍵間隔 < 30ms
  static const int _fastIntervalMs = 45; // 判定 burst 的單次最大間隔（放寬）
  // 純掃描模式：尾端延遲加長，避免碼尾尚未送達即提早處理
  static const Duration _fastProcessDelay = Duration(
    milliseconds: 55,
  ); // 末端等待（高速但保守）
  static const Duration _slowProcessDelay = Duration(
    milliseconds: 120,
  ); // 較慢/不穩定間隔時的等待
  static const int _adaptiveWindow = 6; // 取最近 N 次間隔
  static const bool _debug = false; // 設為 true 可印出調試資訊

  final List<int> _intervals = [];
  int? _lastKeyMillis;
  static const int _minBarcodeLength = 3;
  static const int _maxBarcodeLength = 20;

  KeyboardScannerManager({required this.onBarcodeScanned});

  /// 處理鍵盤事件
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_lastKeyMillis != null) {
        final gap = now - _lastKeyMillis!;
        if (gap >= 0 && gap < 500) {
          _intervals.add(gap);
          if (_intervals.length > _adaptiveWindow) _intervals.removeAt(0);
        } else {
          _intervals.clear();
        }
      }
      _lastKeyMillis = now;

      // 處理結束鍵（條碼掃描器常設定 Enter / numpadEnter / Tab 作為結束）
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.tab) {
        _processScanBuffer();
        return true;
      }

      // 處理數字和字母鍵
      if (_isValidBarcodeCharacter(key)) {
        final character = _getCharacterFromKey(key);
        if (character != null) {
          _addToScanBuffer(character);
          return true;
        }
      }

      // 處理退格鍵
      if (key == LogicalKeyboardKey.backspace) {
        _removeFromScanBuffer();
        return true;
      }
    }

    return false;
  }

  /// 添加字符到掃描緩衝區
  void _addToScanBuffer(String character) {
    _scanBuffer += character;

    _scheduleAdaptiveTimer();
  }

  /// 從掃描緩衝區移除字符
  void _removeFromScanBuffer() {
    if (_scanBuffer.isNotEmpty) {
      _scanBuffer = _scanBuffer.substring(0, _scanBuffer.length - 1);
    }
  }

  /// 處理掃描緩衝區
  void _processScanBuffer() {
    final barcode = _scanBuffer.trim();

    if (_isValidBarcode(barcode)) {
      onBarcodeScanned(barcode);
    }

    _clearScanBuffer();
  }

  /// 清空掃描緩衝區
  void _clearScanBuffer() {
    _scanBuffer = '';
    _scanTimer?.cancel();
  }

  void _scheduleAdaptiveTimer() {
    _scanTimer?.cancel();
    Duration delay = _defaultTimeout;
    if (_intervals.isNotEmpty) {
      final avg = _intervals.reduce((a, b) => a + b) / _intervals.length;
      final isBurst = avg <= _fastIntervalMs;
      if (_scannerOnlyMode) {
        delay = isBurst ? _fastProcessDelay : _slowProcessDelay;
      } else {
        delay = isBurst
            ? _fastProcessDelay
            : _slowProcessDelay * 2; // 仍保留人工輸入支援
      }
      // 針對較短的緩衝長度再額外加一些時間，避免前幾碼被過早送出
      if (_scanBuffer.length < 8) {
        delay += const Duration(milliseconds: 25);
      }
      if (_debug) {
        // ignore: avoid_print
        print(
          '[Scanner] avg=${avg.toStringAsFixed(1)} burst=$isBurst delay=${delay.inMilliseconds}ms len=${_scanBuffer.length} buf="$_scanBuffer"',
        );
      }
    } else {
      // 尚未蒐集足夠間隔，使用保守 timeout
      delay = _defaultTimeout;
    }
    _scanTimer = Timer(delay, () {
      if (_scanBuffer.isNotEmpty) {
        _processScanBuffer();
      }
    });
  }

  /// 檢查是否為有效條碼字符
  bool _isValidBarcodeCharacter(LogicalKeyboardKey key) {
    // 數字鍵
    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      return true;
    }

    // 小鍵盤數字鍵
    if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      return true;
    }

    // 字母鍵
    if (key.keyId >= LogicalKeyboardKey.keyA.keyId &&
        key.keyId <= LogicalKeyboardKey.keyZ.keyId) {
      return true;
    }

    // 特殊字符
    return key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.period;
  }

  /// 從鍵盤鍵值獲取字符
  String? _getCharacterFromKey(LogicalKeyboardKey key) {
    // 數字鍵
    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      return (key.keyId - LogicalKeyboardKey.digit0.keyId).toString();
    }

    // 小鍵盤數字鍵
    if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      return (key.keyId - LogicalKeyboardKey.numpad0.keyId).toString();
    }

    // 字母鍵
    if (key.keyId >= LogicalKeyboardKey.keyA.keyId &&
        key.keyId <= LogicalKeyboardKey.keyZ.keyId) {
      final charCode = key.keyId - LogicalKeyboardKey.keyA.keyId + 65;
      return String.fromCharCode(charCode);
    }

    // 特殊字符
    switch (key) {
      case LogicalKeyboardKey.minus:
        return '-';
      case LogicalKeyboardKey.space:
        return ' ';
      case LogicalKeyboardKey.period:
        return '.';
      default:
        return null;
    }
  }

  /// 檢查是否為有效條碼
  bool _isValidBarcode(String barcode) {
    if (barcode.length < _minBarcodeLength ||
        barcode.length > _maxBarcodeLength) {
      return false;
    }

    // 檢查是否包含有效字符
    final validPattern = RegExp(r'^[A-Z0-9\-\.\s]+$');
    return validPattern.hasMatch(barcode.toUpperCase());
  }

  /// 獲取當前掃描緩衝區內容（用於調試）
  String get currentBuffer => _scanBuffer;

  /// 獲取掃描緩衝區長度
  int get bufferLength => _scanBuffer.length;

  /// 手動觸發條碼掃描（用於測試）
  void simulateBarcodeScan(String barcode) {
    if (_isValidBarcode(barcode)) {
      onBarcodeScanned(barcode);
    }
  }

  /// 清理資源
  void dispose() {
    _scanTimer?.cancel();
    _clearScanBuffer();
  }

  /// 重置掃描狀態
  void reset() {
    _clearScanBuffer();
  }
}
