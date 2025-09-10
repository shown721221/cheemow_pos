/// MoneyUtil: 金錢相關的純函式工具
class MoneyUtil {
  /// 依台幣常見面額（50/100/500/1000）計算
  /// 大於應收金額的「三個」建議實收金額（不含剛好）。
  /// 規則：
  /// - 小額以 50/100/500 為主，逐步放大至 1000。
  /// - 500~999 以 [1000, 1500, 2000]。
  /// - >=1000 時，以 500/1000 為主要刻度，並以 1000 的倍數向上補足到三個。
  static List<int> suggestCashOptions(int total) {
  if (total <= 0) return [];
    int strictCeilTo(int base) {
      if (base <= 0) return total;
      final m = total % base;
      return m == 0 ? total + base : total + (base - m);
    }

    // 小額區間直接回傳固定三筆建議（皆為「嚴格進位」後的刻度）。
    if (total < 50) {
      return [50, 100, 500];
    }
    if (total < 100) {
      return [100, 500, 1000];
    }
    if (total < 500) {
      return [500, 1000, 1500];
    }
    if (total < 1000) {
      return [1000, 1500, 2000];
    }

    // >= 1000：以 500 / 1000 為主的刻度建議，並持續以 1000 的倍數補足到三筆。
    final suggestions = <int>{};
    suggestions.add(strictCeilTo(500));
    suggestions.add(strictCeilTo(1000));

    var base1000 = strictCeilTo(1000);
    while (suggestions.length < 3) {
      base1000 += 1000;
      suggestions.add(base1000);
    }

    final sorted = suggestions.where((v) => v > total).toList()..sort();
    return sorted.take(3).toList();
  }
}
