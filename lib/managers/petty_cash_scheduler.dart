import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/time_service.dart';
import '../config/app_config.dart';

/// 每日凌晨自動重置零用金；呼叫者提供 onReset 回呼以觸發 UI 更新。
class PettyCashScheduler {
  Timer? _timer;
  final VoidCallback onReset;
  PettyCashScheduler({required this.onReset});

  void start() {
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = TimeService.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _timer = TimeService.scheduleAt(nextMidnight, () async {
      await AppConfig.resetPettyCashIfNewDay();
      onReset();
      _schedule();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
