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
  static String checkoutDone(Object total, String method) =>
      '結帳完成！總金額 $total ，($method)';

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
  static String discountOverLimitBody(int discount, int currentTotal) =>
      '折扣金額 ($discount 元) 不能大於目前購物車商品總金額 ($currentTotal 元)。\n請調整折扣或商品數量後再試。';
  static String productNotFoundTitle = '商品未找到';
  static String productNotFoundMessage(String barcode) =>
      '條碼: $barcode\n\n此商品尚未在系統中註冊。';

  // 價格 / 折扣輸入驗證
  static const String invalidNumber = '請輸入有效的數字';
  static const String enterPrice = '請輸入價格';
  static String discountExceed(int discount, int currentTotal) =>
      '折扣金額 ($discount 元) 不能大於目前購物車總金額 ($currentTotal 元)';
  static const String invalidPrice = '請輸入有效的價格';

  // 價格輸入對話框與提示
  static String priceInputTitle(String name) => '輸入 $name 的價格';
  static const String labelPrice = '價格';
  static const String tagPreorder = '預約商品';
  static const String tagDiscount = '特價商品';
  static const String preorderInputNote = '這是預購商品，請輸入實際價格';
  static const String discountInputNote = '這是折扣商品，輸入金額會自動轉為負數';
  static const String enterPreorderPrice = '輸入預購價格';
  static const String enterDiscountMagic = '輸入奇妙數字';

  // 常用按鈕文字
  static const String confirm = '確認';
  static const String cancel = '取消';
  static const String ok = '瞭解';
  static const String clear = '清除';
  static const String reset = '重選';

  // 共同 UI
  static const String menuTooltip = '功能選單';
  static const String menuImport = '上架寶貝們';
  static const String menuSalesExport = '匯出小幫手表格';
  static const String menuReceipts = '收據清單';
  static const String menuRevenue = '闆娘心情指數';
  static const String menuPopularity = '寶寶人氣指數';
  static const String menuPettyCash = '設定零用金';
  static const String clearCartTooltip = '清空購物車';
  static const String cartEmptyTitle = '帶寶寶回家吧';
  static const String appTitle = 'CheeMeow POS';
  static const String salesTabLabel = '銷售';
  static const String revenueTodayTitle = '今日營收';

  // 商品列表（空狀態 / 庫存）
  static const String productListEmptyTitle = '暫無商品資料';
  static const String productListEmptyHint = '請匯入CSV檔案';
  static String stockLabel(int stock) => '庫存: $stock';
  static const String stockOk = '充足';
  static const String stockLow = '偏低';
  static const String stockOut = '缺貨';
  static const String stockNegative = '負庫存';
  static const String typeNormal = '一般';

  // 搜尋
  static const String searchLabel = '搜尋';
  static const String searchProductsHint = '搜尋奇妙寶貝';
  static const String filterResultPrefix = '篩選結果';
  static const String filterHasStock = '有庫存';
  static String filterResultLabel(List<String> filters) =>
      '$filterResultPrefix (${filters.join(', ')})';

  // 收據清單
  static const String receiptListTitle = '🧾 收據清單';
  static const String clearReceiptsTooltip = '清空收據';
  static const String warningClearReceipts = '⚠️ 這會清空所有收據';
  static String onlyTodayLabel(int total) => '僅顯示今日 ($total)';
  static String allReceiptsLabel(int total) => '全部收據 ($total)';
  static const String noReceipts = '沒有符合條件的收據';
  static const String receiptSearchHint = '搜尋商品名稱';
  // 收據篩選用標籤（使用 emoji 與文字分離於 UI, 仍保留整體字串供其他情境需要）
  static const String chipDiscount = '💸 折扣';
  static const String chipPreorder = '📦 預購商品';
  static const String chipRefund = '♻️ 退貨';
  static const String refundDialogTitle = '是否要退貨';
  static String refundDialogMessage(String name, int qty) =>
      '要退貨「$name」嗎？（數量：$qty）';
  static const String refundTooltip = '退貨';
  static const String totalQuantityLabel = '合計件數';
  static const String confirmDeleteTitle = '確認刪除';
  static const String confirmDeleteMessage = '此動作無法復原，確定要永久刪除所有收據嗎？';
  static const String confirmDelete = '確認刪除';

  // 付款方式顯示
  // 現金：改為英文顯示，保留錢幣 emoji。若需更換可用：💰, �, 💶, 💷, 💴（目前採用通用 �）。
  static const String cashLabel = '\$ Cash'; // 產出字串 "$ Cash"
  static const String transferLabel = '🏦';
  static const String linePayLabel = '📲 LinePay';
  static const String enterPaidAmount = '輸入實收金額';
  static const String changeLabel = '找零';
  static const String insufficient = '不足';
  static const String confirmPayment = '確認付款';
  static const String paymentTransferPlaceholder = '預留：轉帳帳號圖片/資訊';
  static const String paymentLinePayPlaceholder = '預留：LinePay QR Code 圖片';

  // 報表指標標籤
  static const String totalRevenueLabel = '總營收';
  static const String metricCash = '現金';
  static const String metricTransfer = '轉帳';
  static const String metricTotalQty = '總件數';
  static const String metricNormalQty = '一般件數';
  static const String metricLinePay = 'LinePay';
  static const String metricPreorderSubtotal = '預購小計';
  static const String metricDiscountSubtotal = '折扣小計';
  static const String metricPreorderQty = '預購件數';
  static const String metricDiscountQty = '折扣件數';
  static const String qtyLabel = '數量';
  static const String subtotalLabel = '小計';
  static const String cartItemsCountLabel = '商品數量';
  static const String totalAmountLabel = '總金額';
  static const String checkoutLabel = '結帳';
  static const String checkoutConfirmTitle = '確認結帳';
  static const String receiptDetailsTitle = '收據明細';
  static const String checkoutFinishedTitle = '結帳完成';
  static const String receiptIdLabel = '收據編號';
  static const String dateLabel = '日期';

  // 零用金
  static const String setPettyCash = '💰 設定零用金';
  static String pettyCashCurrent(int amount) => '目前零用金：\$$amount';
  static const String unknownPaymentMethod = '未知方式';

  // PIN 對話框
  static const String pinTitleMagic = '✨ 請輸入奇妙數字 ✨';
  static const String changePaymentPinWarning = '確定要變更付款方式嗎 ?';
  static const String pinWrong = '密碼錯誤，請再試一次';

  // 匯入
  static const String importing = '匯入中...';
  static const String processing = '處理中...';
  static const String importFailed = '匯入失敗';
  static const String unknownError = '未知錯誤';
  static const String importSuccessTitle = '匯入成功';
  static const String importCancelled = '匯入已取消';
  static String importSuccessSummary(int imported, int total) =>
      '成功匯入 $imported / $total 個商品';
  static String importHasErrors(int n) => '$n 個商品匯入時發生問題';
  static const String errorDetails = '錯誤詳情：';
  static String moreErrors(int n) => '... 還有 $n 個錯誤';
  static const String csvHelpTitle = 'CSV 檔案格式說明';
  static const String csvHelpMustContain = 'CSV 檔案必須包含以下欄位（第一行為標題）：';
  static const String csvHelpRequiredFields = '必要欄位：';
  static const String csvHelpSample = '範例：';
  static const String csvHelpSpecialTitle = '🧸 特殊商品免匯入';
  static const String csvHelpSpecialLine1 =
      '系統內建「預購」與「折扣」兩個特殊商品，會自動存在且不受匯入檔影響。';
  static const String csvHelpSpecialLine2 = '請不要把它們放進 CSV；匯入時也不會覆蓋這兩個項目。';
  static const String csvHelpEncoding = '注意：檔案編碼請使用 UTF-8';

  // CSV 欄位說明子彈點
  static List<String> csvHelpFieldBullets() => const [
    '   • id: 商品唯一識別碼',
    '   • name: 商品名稱',
    '   • barcode: 商品條碼',
    '   • price: 價格（整數，單位：台幣元）',
    '   • category: 商品分類',
    '   • stock: 庫存數量（整數）',
  ];

  // 即將推出
  static const String comingSoonTitle = '即將推出';
  static String comingSoonContent(String feature) => '$feature 功能正在開發中，敬請期待！';

  // CSV 匯入／驗證訊息集中
  static const String csvReadFailed = '無法讀取檔案內容，請確認檔案格式正確';
  static String filePickFailed(Object e) => '檔案選擇失敗: $e';
  static const String csvEmpty = 'CSV檔案是空的';
  static String csvHeaderCountError(
    int expectedCount,
    List<String> expected,
    int actualCount,
    List<String> actual,
  ) =>
      'CSV欄位數量錯誤\n期望 $expectedCount 個欄位: ${expected.join(', ')}\n實際 $actualCount 個欄位: ${actual.join(', ')}';
  static String csvHeaderNameError(int index, String expected, String actual) =>
      'CSV欄位名稱錯誤\n第 ${index + 1} 個欄位期望: $expected\n第 ${index + 1} 個欄位實際: $actual';
  static String csvRowFieldCountInsufficient(int row) => '第$row 行：欄位數量不足';
  static String csvRowRequiredEmpty(int row) => '第$row 行：ID、條碼或商品名稱不能為空';
  static String csvRowPriceInvalid(int row, String value) =>
      '第$row 行：價格格式錯誤 ($value)';
  static String csvRowStockInvalid(int row, String value) =>
      '第$row 行：庫存格式錯誤 ($value)';
  static String csvRowParseError(int row, Object e) => '第$row 行：解析錯誤 - $e';
  static const String csvNoValidProducts = '沒有有效的商品資料';
  static String csvDuplicateId(String id) => 'ID重複: $id';
  static String csvDuplicateBarcode(String barcode) => '條碼重複: $barcode';
  static String csvParseFailed(Object e) => 'CSV解析失敗: $e';
  static String csvFoundErrors(int n) => '發現 $n 個錯誤:';
  static String csvFoundWarnings(int n) => '發現 $n 個警告:';
  static String importStatusSummary(int imported, int total) =>
      '成功匯入 $imported/$total 筆商品';
  static String importStatusProblems(int n) => '發現 $n 個問題';
}
