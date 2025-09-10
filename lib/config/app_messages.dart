// 集中管理全域 SnackBar 與提示文字
// 後續若要做多語系或客製，只需調整此處
import '../utils/money_formatter.dart';

class AppMessages {
  // 私有工具：將完整路徑轉成檔名（跨平台）
  static String _basename(String path) {
    final norm = path.replaceAll('\\', '/');
    final i = norm.lastIndexOf('/');
    return i >= 0 ? norm.substring(i + 1) : norm;
  }
  static List<String> _basenames(Iterable<String> paths) =>
      paths.map(_basename).toList(growable: false);
  // 匯出相關
  static const String autoExportRevenueSuccess = '啟動自動匯出營收完成';
  static const String autoExportRevenueFailure = '啟動自動匯出營收失敗';
  static String exportRevenueSuccess(String paths) {
    final lines = paths.split('\n').where((e) => e.trim().isNotEmpty);
    final names = _basenames(lines);
    final payload = names.isEmpty ? paths : names.join('\n');
    return '已匯出闆娘心情指數\n$payload';
  }

  static String exportRevenueFailure(Object e) => '匯出營收圖失敗: $e';
  static String popularityExportSuccess(String path) {
    return '已匯出寶寶人氣指數：${_basename(path)}';
  }

  static const String popularityExportFailure = '匯出失敗';
  static String popularityExportError(Object e) => '人氣指數匯出錯誤：$e';

  // 零用金
  static String pettyCashSet(int amount) =>
      '零用金已設定為 ${MoneyFormatter.symbol(amount)}';

  // 購物車 / 結帳
  static String removedItem(String name) => '已移除 $name';
  static String checkoutCash(String method, int change, int updated) =>
      '結帳完成（$method）。找零 ${MoneyFormatter.symbol(change)}，已更新 $updated 個商品排序';
  static String checkoutOther(String method, int updated) =>
      '結帳完成（$method），已更新 $updated 個商品排序';

  // 搜尋 / 篩選
  static String searchResultCount(int count) => '找到 $count 項商品';

  // 收據
  static const String clearedReceipts = '已清空收據清單';

  // 銷售資料匯出
  static const String salesExportNoData = '沒有可匯出的銷售資料';
  static String salesExportSuccess(List<String> paths) {
    final names = _basenames(paths);
    return '已匯出銷售資料\n${names.join('\n')}';
  }

  static String salesExportFailure(Object e) => '匯出銷售資料失敗: $e';

  // 對話框文案（集中管理，便於維護與測試）
  static const String discountOverLimitTitle = '折扣超過上限';
  static String productNotFoundTitle = '商品未找到';
  static String productNotFoundMessage(String barcode) =>
      '條碼: $barcode\n\n此商品尚未在系統中註冊。';

  // 價格 / 折扣輸入驗證
  static const String invalidNumber = '請輸入有效的數字';
  static const String enterPrice = '請輸入價格';
  static String discountExceed(int discount, int currentTotal) =>
      '折扣金額 ($discount 元) 不能大於目前購物車總金額 ($currentTotal 元)';
  static const String invalidPrice = '請輸入有效的價格';
}
