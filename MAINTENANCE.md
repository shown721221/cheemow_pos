# 維護說明 (Maintenance)

本專案為個人自用 POS，核心功能已穩定，不再進行大型重構；後續僅針對實際使用時遇到的問題做最小修正。

## 版本與標記
- 建議在重大修正（例如資料結構或排序策略調整）後打上 Git Tag，例如：`v1-stable`、`v1.1-fix-sort`。
- 若僅 UI 調整或文案更新，可不打 Tag。

## 變更原則
| 類型 | 是否允許 | 說明 |
| ---- | -------- | ---- |
| 修 bug | ✅ | 立即修，補測試或調整既有測試預期 |
| 小功能微調 | ✅ | 依實際操作痛點（例如快捷金額邏輯）|
| 付款方式新增 | ⚠️ | 需同步更新 enum / 匯出 / 測試 |
| 資料模型新增欄位 | ⚠️ | 確認 JSON 序列化兼容；必要時加版本欄位 |
| 大型重構 / 分層重整 | ❌ | 不再進行（維持簡潔降低理解成本）|

## 既有測試覆蓋範圍
| 模組 | 測試 | 重點 |
| ---- | ---- | ---- |
| 排序 | `product_sorter_test.dart` | 特殊商品置頂 / 今日售出時間序 |
| 結帳後重排 | `post_checkout_reorder_test.dart` | 售出商品移前 / 特殊穩定 |
| 收據編號 | `receipt_id_generator_test.dart` | 每日序號遞增 / 跨日重置 |
| 收據統計 | `receipt_statistics_test.dart` | 今日 / 本月 / 全部數量與金額 |
| 商品儲存 | `product_repository_test.dart` | CRUD 與 stock 更新 |
| 動作服務 | `pos_actions_service_test.dart` | 統計對話對話框顯示 |
| 搜尋 / 篩選 | `search_filter_manager_test.dart` | 組合條件與關鍵字 |

新增修正時先確認是否需要新增或更新上述任一測試；保持 `flutter test` 全綠即視為可部署。

## 推薦最小修改流程
1. 建立/調整測試（或在現有測試重現問題）。
2. 進行程式碼修改（保持單一責任、小提交）。
3. 執行：`flutter test` 確保綠燈。
4. （可選）打 Tag。
5. 手動驗證：啟動 App，操作新增/受影響功能。

## 常見調整參考
| 需求 | 可能動到檔案 |
| ---- | ------------ |
| 調整商品初始排序 | `product_sorter.dart` / `post_checkout_reorder.dart` |
| 新增付款方式 | `payment_method.dart` / `receipt_id_generator.dart` / `sales_export_service.dart` |
| 修改匯出 CSV 欄位 | `sales_export_service.dart` |
| 調整預購/折扣邏輯 | `local_database_service.dart` (特殊商品建立) |
| 修改結帳流程提示 | `app_messages.dart` / `payment_dialog.dart` |

## 日誌策略
- 保留：錯誤 (`AppLogger.w`)、重要成功資訊（儲存收據、刪除收據）。
- 可移除：大量重複的 debug 排序輸出（已逐步清理）。

## 未來如需要「資料還原」
- 可新增：`restore_from_backup(jsonString)`（目前無此需求故未實作）。

## Flutter / Dart 升級策略
- 非必要不升級（維持穩定）。
- 若升級：先 `flutter upgrade`，再跑 `flutter test`；若失敗檢視破壞性變更。

## 風險備忘
- SharedPreferences 沒有 schema 版本：若模型改動需檢查舊資料解析是否安全。
- 收據序號依賴「計算當日已有收據數」：大量歷史資料（>數千）時可能影響生成速度（目前量級安全）。

---
最後：保持簡單，維護成本最低。祝使用順利 🐾
