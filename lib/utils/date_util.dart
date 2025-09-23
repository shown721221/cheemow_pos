class DateUtil {
  DateUtil._();

  /// 回傳 yyyy-MM-dd
  static String ymd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 回傳 yymmdd（兩位年 + 月日補零）
  static String ymdCompact(DateTime dt) {
    final y = (dt.year % 100).toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
