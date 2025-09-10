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

    // 1000 <= total < 1500：偏好 500/1000 的整數級距，避免 1100/1200/1300 這類過細的級距。
    if (total < 1500) {
      final c500 = strictCeilTo(500);   // >= 1000 時最小也會是 1500
      final c1000 = strictCeilTo(1000); // 會是 2000
      return [c500, c1000, c1000 + 1000];
    }

    // >= 1500：以 [ceil100, ceil500, ceil1000] 為基礎，不足三筆再以 500/1000 遞增補足。
    final set = <int>{
      strictCeilTo(100),
      strictCeilTo(500),
      strictCeilTo(1000),
    };

    var next500 = strictCeilTo(500);
    var next1000 = strictCeilTo(1000);
    List<int> over() => set.where((v) => v > total).toList()..sort();

    // 若已包含千位整數，視為最後一個快速按鈕，直接回傳（不再補更多）。
    final initial = over();
    if (initial.any((v) => v % 1000 == 0)) {
      return initial.take(3).toList();
    }

    while (over().length < 3) {
      next500 += 500;
      set.add(next500);
      if (over().length >= 3) break;
      next1000 += 1000;
      set.add(next1000);
    }

    final sorted = over();
    return sorted.take(3).toList();
  }
}
