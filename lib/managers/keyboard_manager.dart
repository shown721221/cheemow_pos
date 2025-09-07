import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 鍵盤事件管理器
/// 負責處理 POS 系統的鍵盤輸入事件，特別是條碼掃描器的輸入
class PosKeyboardManager {
  late FocusNode _focusNode;
  Function(String)? _onBarcodeScanned;
  Function()? _onEnterPressed;
  
  /// 初始化鍵盤管理器
  void initialize({
    Function(String)? onBarcodeScanned,
    Function()? onEnterPressed,
  }) {
    _focusNode = FocusNode();
    _onBarcodeScanned = onBarcodeScanned;
    _onEnterPressed = onEnterPressed;
  }

  /// 獲取焦點節點
  FocusNode get focusNode => _focusNode;

  /// 處理鍵盤事件
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    // 只處理按下事件，避免重複觸發
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final character = event.character;
    
    // 處理 Enter 鍵
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _onEnterPressed?.call();
      return KeyEventResult.handled;
    }
    
    // 處理可列印字符（條碼掃描器輸入）
    if (character != null && character.isNotEmpty) {
      // 過濾掉控制字符，只接受可列印字符
      if (_isPrintableCharacter(character)) {
        _onBarcodeScanned?.call(character);
        return KeyEventResult.handled;
      }
    }
    
    return KeyEventResult.ignored;
  }

  /// 檢查是否為可列印字符
  bool _isPrintableCharacter(String character) {
    final codeUnit = character.codeUnitAt(0);
    // ASCII 可列印字符範圍：32-126
    // 也包含常見的擴展 ASCII 字符
    return (codeUnit >= 32 && codeUnit <= 126) || 
           (codeUnit >= 160 && codeUnit <= 255);
  }

  /// 請求焦點
  void requestFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  /// 釋放資源
  void dispose() {
    _focusNode.dispose();
  }
}

/// 鍵盤監聽 Widget
/// 包裝子 Widget 並提供鍵盤事件監聽功能
class KeyboardListener extends StatefulWidget {
  final Widget child;
  final PosKeyboardManager keyboardManager;

  const KeyboardListener({
    super.key,
    required this.child,
    required this.keyboardManager,
  });

  @override
  State<KeyboardListener> createState() => _KeyboardListenerState();
}

class _KeyboardListenerState extends State<KeyboardListener> {
  @override
  void initState() {
    super.initState();
    // 確保在下一幀請求焦點
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.keyboardManager.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.keyboardManager.focusNode,
      onKeyEvent: widget.keyboardManager.handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          // 點擊時重新獲取焦點
          widget.keyboardManager.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}
