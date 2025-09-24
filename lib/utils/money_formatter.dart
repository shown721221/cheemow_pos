/// MoneyFormatter: 統一金額顯示（含千分位與符號）
class MoneyFormatter {
  /// 轉換數字為千分位字串（不加符號）
  static String thousands(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i - 1;
      buf.write(s[i]);
      final remain = reverseIndex;
      if (remain % 3 == 0 && reverseIndex != 0) buf.write(',');
    }
    final base = buf.toString();
    return amount < 0 ? '-$base' : base;
  }

  /// 前面加上 $ 符號（避免 emoji 相容性問題）
  static String symbol(int amount) => '\$ ${thousands(amount)}';
}
