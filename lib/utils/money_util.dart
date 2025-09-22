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

    // 1000 <= total < 1500：需求調整為顯示「下一個百、下一個 500、下一個 1000」
    // 例如：1050 -> 1100,1500,2000；1150 -> 1200,1500,2000；1499 -> 1500,2000,3000
    if (total < 1500) {
      int h = strictCeilTo(100); // 下一個百
      int five = strictCeilTo(500); // 1500
      int thou = strictCeilTo(1000); // 2000
      final ordered = <int>{h, five, thou}.where((v) => v > total).toList()
        ..sort();
      return ordered; // 可能是 2 或 3 筆，允許少於 3
    }

    // >= 1500：以 [ceil100, ceil500, ceil1000] 為基礎，不足三筆再以 500/1000 遞增補足。
    final set = <int>{strictCeilTo(100), strictCeilTo(500), strictCeilTo(1000)};

    var next500 = strictCeilTo(500);
    var next1000 = strictCeilTo(1000);
    List<int> over() => set.where((v) => v > total).toList()..sort();

    // 若已包含千位整數，視為最後一個快速按鈕，直接回傳（不再補更多）。
    final initial = over();
    if (initial.any((v) => v % 1000 == 0)) {
      var trimmed = initial.take(3).toList();
      // 若包含剛好 total，移除它（例如 total=2500 初步集合可能含 2500）
      trimmed.removeWhere((v) => v == total);
      // 需求：像 2500 僅顯示 3000，不顯示 2600（因 2600 只是 +100，不是常見收款面額）
      if (total % 500 == 0) {
        trimmed.removeWhere((v) => v == total + 100);
      }
      return trimmed;
    }

    while (over().length < 3) {
      next500 += 500;
      set.add(next500);
      if (over().length >= 3) break;
      next1000 += 1000;
      set.add(next1000);
    }

    final sorted = over();
    var top = sorted.take(3).where((v) => v != total).toList();
    if (total % 500 == 0) {
      top.removeWhere((v) => v == total + 100);
    }
    return top;
  }
}
