import 'dart:async';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/bluetooth_scanner_service.dart';
import '../services/barcode_scan_helper.dart';
import '../managers/keyboard_scanner_manager.dart';

typedef ProductAdder = Future<void> Function(Product product);
typedef SpecialPriceAdder = Future<void> Function(Product product);
typedef NotFoundHandler = void Function(String barcode);
typedef PreScanCleanup = void Function();

/// 整合藍牙與鍵盤條碼掃描，並將結果分派給呼叫者。
class BarcodeScanCoordinator {
  final ProductAdder onAddNormal; // 一般商品直接加
  final ProductAdder onAddSpecial; // 特殊需輸入價格後再加（或直接加入待後處理）
  final NotFoundHandler onNotFound;
  final PreScanCleanup onPreScan;

  StreamSubscription<String>? _sub;
  KeyboardScannerManager? _kb;

  BarcodeScanCoordinator({
    required this.onAddNormal,
    required this.onAddSpecial,
    required this.onNotFound,
    required this.onPreScan,
  });

  void start() {
    _sub = BluetoothScannerService.instance.barcodeStream.listen(
      _handleBarcode,
    );
    _kb = KeyboardScannerManager(onBarcodeScanned: _handleBarcode);
    ServicesBinding.instance.keyboard.addHandler(_kb!.handleKeyEvent);
  }

  void _handleBarcode(String code) async {
    onPreScan();
    final decision = await BarcodeScanHelper.decideFromDatabase(code);
    switch (decision.result) {
      case ScanAddResult.foundNormal:
        await onAddNormal(decision.product!);
        break;
      case ScanAddResult.foundSpecialNeedsPrice:
        await onAddSpecial(decision.product!);
        break;
      case ScanAddResult.notFound:
        onNotFound(code);
        break;
    }
  }

  void dispose() {
    _sub?.cancel();
    if (_kb != null) {
      ServicesBinding.instance.keyboard.removeHandler(_kb!.handleKeyEvent);
      _kb!.dispose();
    }
  }
}
