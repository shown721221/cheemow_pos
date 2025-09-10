/// MoneyUtil: 金錢相關的純函式工具
class MoneyUtil {
  /// 依台幣常見面額（50/100/500/1000）計算
  /// 大於應收金額的「三個」建議實收金額（不含剛好）。
  /// 規則：
  /// - 小額以 50/100/500 為主，逐步放大至 1000。
  /// - 500~999 以 [1000, 1500, 2000]。
  /// - 1000~1499 期間避免 100 的細刻度，使用 [1500, 2000, 3000]。
  /// - >=1500 時，以 100/500/1000 的嚴格進位為基礎，若已出現「千位整數」則視為最後一個快速按鈕不再補充，
  ///   否則以 500/1000 的步進向上補足到三個。
  ///
  /// 實作概念：先建立「候選集合」＝ { total, ceil(50), ceil(100), ceil(500), ceil(1000) }，
  /// 取出大於 total 的升冪唯一列表後，依上述規則過濾或補齊數量。
  static List<int> suggestCashOptions(int total) {
  if (total <= 0) return [];
  // 千元整數不提供快速金額（已是整數面額的終點）。
  if (total % 1000 == 0) return [];
    int strictCeilTo(int base) {
      if (base <= 0) return total;
      final m = total % base;
      return m == 0 ? total + base : total + (base - m);
    }

    // 小額區間直接回傳固定三筆建議（皆為「嚴格進位」後的刻度）。
    // < 1000：以 50/100/500/1000 的嚴格進位建立候選，
    //        遇到第一個 1000 的整數階（含本身）即停止，並取最小三筆。
    int ceilTo(int base) {
      final m = total % base;
      return m == 0 ? total : total + (base - m);
    }
    if (total < 1000) {
      final c50 = ceilTo(50);
      final c100 = ceilTo(100);
      final c500 = ceilTo(500);
      final c1000 = ceilTo(1000);
      final set = <int>{c50, c100, c500, c1000};
      final list = set.where((v) => v > total).toList()..sort();
      final cut = list.where((v) => v <= c1000).toList();
      return cut.take(3).toList();
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
