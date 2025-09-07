import 'dart:async';
import 'package:flutter/services.dart';

/// 鍵盤和條碼掃描處理管理器
/// 負責處理鍵盤事件和條碼掃描邏輯
class KeyboardScannerManager {
  String _scanBuffer = '';
  Timer? _scanTimer;
  final Function(String) onBarcodeScanned;
  
  // 條碼掃描配置
  static const Duration _scanTimeout = Duration(milliseconds: 100);
  static const int _minBarcodeLength = 3;
  static const int _maxBarcodeLength = 20;

  KeyboardScannerManager({required this.onBarcodeScanned});

  /// 處理鍵盤事件
  bool handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      
      // 處理 Enter 鍵（條碼掃描器通常以 Enter 結尾）
      if (key == LogicalKeyboardKey.enter) {
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
    
    // 重置定時器
    _scanTimer?.cancel();
    _scanTimer = Timer(_scanTimeout, () {
      if (_scanBuffer.isNotEmpty) {
        _processScanBuffer();
      }
    });
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
