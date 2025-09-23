# Changelog

All notable changes to this project will be documented in this file.

## Unreleased
- 移除：BackupService 與對應測試（保持核心精簡）
- 新增：`PaymentMethod` enum 與 `ReceiptIdGenerator`，統一付款代碼與每日序號邏輯
- 強化：SalesExport 測試（付款代碼欄位、特殊商品 CSV 僅含特殊）
- 強化：ProductSorter 大型資料 (>200) 排序穩定性測試
- 抽取：`AppStrings.receiptStatisticsTitle` 避免硬編碼
- 新增：集中式主題與深色模式 `AppTheme` / `AppColors`，商品卡片與文字顏色調整確保黑色背景下對比可讀
- 重構：`ShoppingCartWidget` 顏色改用語意色（success / error / preorder / discount / neutral），準備後續統一
- 新增：抽象 `EmptyState` 元件並套用於 `ProductListWidget` 空清單
- 重構：`ReceiptListScreen` 無收據與商品未找到對話框視覺統一改用 EmptyState 風格
- 重構：分頁標籤英文化 (product / search) 並統一黑色背景與語意主題色（移除硬編碼 Colors.*）
- 重構：銷售商品列表與搜尋頁面背景改為黑色 (darkScaffold/darkCard) 並語意化篩選按鈕顏色
- 重構：付款對話框快速金額按鈕與「找零」顯示改用語意色 (primary / success / error / onDarkSecondary)
- 強化：商品卡庫存顏色註解與語意（綠>0 / 黃=0 / 紅<0）標示更明確，快速金額文字改用 info 色系與數字鍵盤區隔
- 新增：商品清單可選擇依庫存量排序（保留『今日售出置前 / 特殊置頂』大類順序，再於群內按庫存高→低）
- 變更：商品清單與搜尋結果預設即啟用庫存排序（無需切換），未使用每日排序時也改為庫存高→低 + 名稱
 - 調整：庫存排序規則改為「特殊商品永遠置頂（預購優先於折扣），其後為今日售出的一般商品（最新→最舊），最後其餘一般商品依庫存高→低 + 名稱」。
 - 移除：`ProductListWidget.applyDailySort` 參數（排序策略固定：特殊置頂 > 今日售出一般 > 其它依庫存）。
 - 清理：全面替換舊版 `withOpacity` 為 `withValues(alpha: ...)` 並補齊 flow control if 大括號以符合 lint。
 - UI：主頁 AppBar 改為綠色(AppColors.success) 並暫時置中標題，避免與系統列藍色融合。
 - 重構：抽出 `PrimaryAppBar` 與 `UiTokens`（emoji/spacing），提升視覺元件模組化，可測試性與後續替換 Logo 彈性。
 - 重構：`PosTabBar` 參數化（icon/label 可替換），統一使用 UiTokens。
 - 重構：購物車空狀態改用通用 `EmptyState`（移除客製 Column 重複）。

## 1.0.0 - 2025-09-22
- 專案更名統一為 `cheemeow_pos`
- 清除舊命名殘留及無用檔案
- 導入集中式 `AppLogger` 取代散落的 print/debugPrint
- 匯出功能（營收圖、人氣指數、銷售/特殊商品 CSV）穩定
- 收據儲存與每日排序邏輯完成
- 商品 CSV 匯入與折扣守門檢查完成
- 測試套件通過（核心服務 / 工具 / 控制流程）
