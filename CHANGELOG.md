# Changelog

All notable changes to this project will be documented in this file.

## Unreleased
- 移除：BackupService 與對應測試（保持核心精簡）
- 新增：`PaymentMethod` enum 與 `ReceiptIdGenerator`，統一付款代碼與每日序號邏輯
- 強化：SalesExport 測試（付款代碼欄位、特殊商品 CSV 僅含特殊）
- 強化：ProductSorter 大型資料 (>200) 排序穩定性測試
- 抽取：`AppStrings.receiptStatisticsTitle` 避免硬編碼

## 1.0.0 - 2025-09-22
- 專案更名統一為 `cheemeow_pos`
- 清除舊命名殘留及無用檔案
- 導入集中式 `AppLogger` 取代散落的 print/debugPrint
- 匯出功能（營收圖、人氣指數、銷售/特殊商品 CSV）穩定
- 收據儲存與每日排序邏輯完成
- 商品 CSV 匯入與折扣守門檢查完成
- 測試套件通過（核心服務 / 工具 / 控制流程）
