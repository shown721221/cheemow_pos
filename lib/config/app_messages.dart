// 集中管理全域 SnackBar 與提示文字
// 後續若要做多語系或客製，只需調整此處
class AppMessages {
  // 匯出相關
  static const String autoExportRevenueSuccess = '啟動自動匯出營收完成';
  static const String autoExportRevenueFailure = '啟動自動匯出營收失敗';
  static String exportRevenueSuccess(String paths) => '已匯出闆娘心情指數\n$paths';
  static String exportRevenueFailure(Object e) => '匯出營收圖失敗: $e';
  static String popularityExportSuccess(String path) => '已匯出寶寶人氣指數：$path';
  static const String popularityExportFailure = '匯出失敗';
  static String popularityExportError(Object e) => '人氣指數匯出錯誤：$e';

  // 零用金
  static String pettyCashSet(int amount) => '零用金已設定為 💲$amount';

  // 購物車 / 結帳
  static String removedItem(String name) => '已移除 $name';
  static String checkoutCash(String method, int change, int updated) =>
      '結帳完成（$method）。找零 💲$change，已更新 $updated 個商品排序';
  static String checkoutOther(String method, int updated) =>
      '結帳完成（$method），已更新 $updated 個商品排序';

  // 搜尋 / 篩選
  static String searchResultCount(int count) => '找到 $count 項商品';

  // 收據
  static const String clearedReceipts = '已清空收據清單';

    // 銷售資料匯出
    static const String salesExportNoData = '沒有可匯出的銷售資料';
    static String salesExportSuccess(List<String> paths) => '已匯出銷售資料\n${paths.join('\n')}';
    static String salesExportFailure(Object e) => '匯出銷售資料失敗: $e';

  // 價格 / 折扣輸入驗證
  static const String invalidNumber = '請輸入有效的數字';
  static const String enterPrice = '請輸入價格';
  static String discountExceed(int discount, int currentTotal) =>
      '折扣金額 ($discount 元) 不能大於目前購物車總金額 ($currentTotal 元)';
  static const String invalidPrice = '請輸入有效的價格';
}
