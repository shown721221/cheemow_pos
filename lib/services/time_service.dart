import 'dart:async';

/// 時間與排程服務
/// 目的：
/// 1. 集中 `DateTime.now()` 取得，未來可注入/模擬
/// 2. 測試時可關閉長時排程，避免 pending timer 造成測試失敗
class TimeService {
  /// 是否在測試中停用所有實際 Timer 排程（避免 24h Timer）
  static bool disableSchedulingForTests = false;

  /// 測試/模擬時可覆寫現在時間提供者
  static DateTime Function()? nowOverride;

  /// 取得現在時間（之後可改為可替換 provider）
  static DateTime now() => nowOverride?.call() ?? DateTime.now();

  /// 排程在指定目標時間執行 callback。
  /// 若目標時間已過，立即執行（同步）。
  /// 測試停用模式下，直接回傳一個已取消的 Dummy Timer。
  static Timer scheduleAt(DateTime target, void Function() callback) {
    if (disableSchedulingForTests) {
      // 直接執行一次，並回傳假 Timer（不會觸發第二次）
      if (target.isBefore(now())) {
        callback();
      }
      return _DummyTimer();
    }
    final diff = target.difference(now());
    final duration = diff.isNegative ? Duration.zero : diff;
    return Timer(duration, callback);
  }
}

/// 一個不會真的觸發的假 Timer，供測試模式使用
class _DummyTimer implements Timer {
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
  @override
  void cancel() {}
}
