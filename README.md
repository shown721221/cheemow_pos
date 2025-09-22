# CheeMeow POS 系統 🛍️💕

> 2025/09/22 狀態：核心功能穩定，僅接受零星小修；架構已凍結（不再大型重構）。Backup 功能已移除；付款方式改用 enum；新增大型排序壓力測試與 SalesExport 加強驗證；抽出 `AppStrings` 常數。

## ✅ 功能完成里程碑（截至 2025/09/22）
1. 銷售 / 購物車 / 結帳（含預購商品、折扣商品、退貨標記）
2. 收據系統：儲存、今日/關鍵字/付款方式/退貨篩選、金額顯示、更新付款方式
3. 匯出：
   - 營收圖片（闆娘心情指數）
   - 人氣圖片（寶寶人氣指數）
   - 銷售 CSV（排除特殊商品）
   - 特殊商品 CSV（預購 + 折扣獨立）
   - 全部統一路徑：`Downloads/cheemeow_pos/YYYY-MM-DD/`（Android MediaStore / 桌面一致）
   - 檔案覆寫策略：事前清除可能的 (1)(2)… 重複 + 直接覆寫
4. 零用金：每日跨日自動重置、PIN 保護設定、顯示於匯出圖/主畫面
5. 商品每日智能排序：特殊商品 > 今日售出(新→舊) > 其餘按名稱
6. 結帳後購物車保留快照（任一互動清除）
7. 條碼鍵盤掃描（系統層級事件攔截）
8. 所有 SnackBar / 文案集中：`lib/config/app_messages.dart`
9. 匯出銷售 CSV 保留商品代碼 / 條碼前導 0（前置單引號）
10. 付款方式代碼（1=現金 / 2=轉帳 / 3=LinePay）統一於匯出（移除其他代碼）— 現在以 `PaymentMethod` enum 驗證
11. 移除原先備份（BackupService）試驗性功能，保持精簡
12. 大型資料排序測試（>200 筆）驗證特殊置頂 + 今日售出排序 + 穩定性
13. SalesExport 測試強化：付款代碼欄位、特殊 CSV 僅含特殊商品
14. UI 零散字串開始集中（`AppStrings`）

## 🧱 架構與可維護性更新（近期）
 - ProductUpdateService（`lib/services/product_update_service.dart`）
    - 目的：集中「結帳後」對商品資料的更新（扣庫存、最後結帳時間、依規則重新排序並持久化）。
    - 介面摘要：
       - `compute(products, cartItems, {now}) → ProductUpdateOutcome`
       - `applyCheckout({products, cartItems, now}) → Future<ProductUpdateOutcome>`（含持久化）
    - 回傳 `ProductUpdateOutcome`：`updatedProducts`、`resortedProducts`、`updatedCount`、`quantityByBarcode`。
 - BarcodeScanHelper（`lib/services/barcode_scan_helper.dart`）
    - 目的：將條碼掃描的決策抽離 UI，回傳純結果以供主畫面採取後續行為。
    - 結果列舉：`foundNormal`（直接加入）、`foundSpecialNeedsPrice`（需輸入價格）、`notFound`（查無）。
    - 介面摘要：
       - `decideFromProducts(barcode, products) → ScanAddDecision`（純函數）
       - `decideFromDatabase(barcode) → Future<ScanAddDecision>`
 - 常數集中（`lib/config/constants.dart`）
    - `AppConstants`：特殊條碼（預購、折扣）、特殊分類名。
    - `PaymentMethods`：`cash` / `transfer` / `linePay`，統一於對話框、收據、報表與匯出。
    - 好處：移除魔術字串、降低漂移風險，並改善測試可讀性。

小提醒：時間來源統一由 TimeService 提供（測試可注入固定 now），以確保排序與統計在測試與實機一致。

### 目前主要模組簡述
| 模組 | 目的 | 位置 |
| ---- | ---- | ---- |
| 商品排序 ProductSorter | 每日 / 特殊商品置頂策略 | `lib/utils/product_sorter.dart` |
| 結帳流程 CheckoutController | 結帳整合、重排、快照 | `lib/controllers/checkout_controller.dart` |
| 收據服務 ReceiptService | 儲存 / 統計 / 編號委派 | `lib/services/receipt_service.dart` |
| 編號產生 ReceiptIdGenerator | 付款方式代碼 + 每日序號 | `lib/services/receipt_id_generator.dart` |
| 銷售 / 特殊 CSV 匯出 | 分離特殊商品記錄 & 付款代碼 | `lib/services/sales_export_service.dart` |
| 動作聚合 PosActionsService | 主畫面功能選單操作 | `lib/services/pos_actions_service.dart` |
| 條碼掃描 BarcodeScanCoordinator | 鍵盤/藍牙掃描整合 | `lib/managers/barcode_scan_coordinator.dart` |
| 零用金調度 PettyCashScheduler | 跨日自動重置 | `lib/managers/petty_cash_scheduler.dart` |

### 測試覆蓋範疇摘要（精選）
| 類別 | 內容 | 代表測試 |
| ---- | ---- | ---- |
| 排序 | 特殊置頂/今日售出排序 / 大量資料穩定性 | `product_sorter_test.dart` / `product_sorter_large_dataset_test.dart` |
| 結帳後重排 | 售出商品移至前段 | `post_checkout_reorder_test.dart` |
| 收據編號 | 每日遞增/跨日重置 | `receipt_id_generator_test.dart` |
| 收據服務 | 統計/序號使用 | `receipt_service_test.dart` |
| 產品儲存 | CRUD + stock 更新 | `product_repository_test.dart` |
| 動作服務 | 統計對話框顯示（使用常數標題） | `pos_actions_service_test.dart` |
| 搜尋/篩選 | 關鍵字與條件組合 | `search_filter_manager_test.dart` |

---

## 🎯 後續僅保留的小修方向（如有需要）
- 個別文案 / 視覺微調（集中於 `app_messages.dart` / `app_strings.dart`）
- 金額格式 util（千分位 / 統一符號）
- 匯出欄位若有新需求再行擴充
- 減少日誌輸出（目前僅偵錯用途，可保留）

## 🧪 測試執行快速指引
全部：
```
flutter test
```
單檔：
```
flutter test test/receipt_id_generator_test.dart
```
新增測試時原則：
1. 優先純邏輯 / 無 I/O。
2. 與時間相關行為注入 `now`（`TimeService`）。
3. 新增導出的驗證要檢查：欄位順序、前導 0、付款代碼、特殊 vs 一般分離。

## 🧪 測試指引（Unit Tests）
- 執行全部測試：
   - `flutter test`
- 執行單一測試檔：
   - `flutter test test/product_update_service_test.dart`
- 重點測試範疇：
   - ProductUpdateService：庫存扣減、`lastCheckoutTime` 設定、排序結果回傳。
   - BarcodeScanHelper：三種掃描結果決策（一般 / 特殊需輸價 / 查無）。
   - SearchFilterManager：關鍵字 / 篩選條件的純邏輯。
   - 匯出服務：CSV 欄位、付款代碼、前導 0 保留。
- 測試技巧：
   - 盡量以純函數/服務做單元測試，避免直接觸碰平台 I/O。
   - 與時間相關的行為，透過 TimeService 注入固定時間，讓測試具可預期性。

## 📌 維護策略
本專案為個人自用：避免過度工程；僅針對真實痛點調整。重大異動前跑全測試確保綠燈；無新大型重構計畫。

---

---

以下為早期歷史內容（保留參考，未再主動維護，可視需要裁剪）：

## 專案概述
CheeMeow POS 是一個專為平板設計的橫向銷售點系統，具有溫馨可愛的界面設計。

## 🎯 專案定位與技術方針

### 核心原則

### 技術決策理念

## 🚀 最新進度更新 (2025年9月9日)

### 本日重點增強
1. 匯出圖片（營收 / 熱門度）統一存放於每日日期資料夾：`Downloads/cheemeow_pos/YYYY-MM-DD/`
2. 收據清單新增「退貨」篩選籤（顯示為 `退貨`），並在每筆列表項目顯示該筆總金額（含預購 / 折扣計算後）。
3. 新增「設定零用金」功能（💰）：
   - 透過功能選單操作
   - 變更需輸入 PIN（目前：`0203`）
   - 零用金顯示於營收匯出圖片日期下方（方便人工對帳）
4. 全面將原本 `NT$` 顯示改為統一貨幣符號 `💲`（付款、收據、輸入框、匯出圖片等）。
5. 數字鍵盤樣式統一：付款、預購 / 折扣價格輸入、零用金設定共用一致視覺與按鍵佈局。
6. 價格顯示色彩規則：
   - 折扣：橘色
   - 預購：紫色
   - 其他（含零用金）：blueGrey
7. 修正方法簽名調整後的執行期例外（冷啟後正常）。
8. 記錄當前環境版本與 Commit 以利跨裝置同步。

### 快速版本 / Commit 快照
| 項目 | 值 |
| ---- | --- |
| Commit Hash | `cc90d4d` |
| Flutter | 3.35.3 (stable) |
| Dart | 3.9.2 |
| Engine | 672c59cfa8 |
| Framework Revision | a402d9a437 |
| SDK constraint (`pubspec.yaml`) | `^3.9.0` |
| 保護 PIN | `0203` |

### 匯出路徑說明
Android（MediaStore）：`Downloads/cheemeow_pos/<YYYY-MM-DD>/`
Desktop / 其他：於使用者下載資料夾下建立相同結構。

### 零用金（Petty Cash）說明
- 目的：記錄每日起始現金 / 找零準備金，協助盤點。
- 存儲：SharedPreferences。
- 變更流程：功能選單 → 輸入 PIN → 自訂數字鍵盤輸入金額。
- 顯示：營收統計區（日期下方）與匯出圖片。

### 待可能優化（尚未實作）
- 金額千分位統一格式化。
- Emoji 若裝置不支援時的替代圖示策略。
- 數字鍵盤抽象為可重用元件。
- 增補零用金與匯出流程的測試。

---

### 結帳體驗與付款介面
   - 新增自訂數字鍵盤（避免平板系統鍵盤無法輸入）
   - 動態「快速金額」三顆，依 50/100/500/1000 進位，永遠取最大三個
   - 快速金額平均分散排列
   - 找零顯示改為「� 金額」，並靠右與金額間距 8px
   - 單行三鍵：現金 / 轉帳 / LinePay（預留圖片/QR 顯示區）
   - 使用 Material bag 圖示（跨裝置顯示穩定）

### 修正

### 下一步：收據系統（本地 + 後續擴充）

### �🔍 搜尋功能大升級 - 「搜尋奇妙寶貝」✨

#### 已完成功能：
1. **雙分頁設計**
   - 銷售分頁：原有商品瀏覽和購物車功能 (購物車圖示)
   - 搜尋分頁：全新快速篩選功能 (放大鏡圖示)

2. **18個智慧快速篩選按鈕** (6行 × 3列，自適應空間)
   - **地區篩選**：東京Disney限定、上海Disney限定、香港Disney限定
     - 🔒 **互斥邏輯**：只能選擇一個地區，選中後其他地區按鈕會禁用變灰
   - **角色篩選**：Duffy、Gelatoni、OluMel、ShellieMay、StellaLou、CookieAnn、LinaBell、其他角色
   - **類型篩選**：娃娃、站姿、坐姿、其他吊飾
   - **庫存篩選**：有庫存
   - **功能按鈕**：重選（清除所有）、確認（執行篩選）

3. **UI/UX 優化**
   - 移除搜尋頁面下方的放大鏡提示圖示，增加按鈕可用空間
   - 按鈕使用 Expanded 充分利用螢幕空間，更適合平板操作
   - 禁用按鈕有明確視覺回饋（灰色顯示）
   - 圓角設計更現代化

4. **智慧篩選演算法**
   - 地區篩選檢查商品名稱包含「XX迪士尼限定」關鍵字
   - 多重條件組合篩選
   - 特殊商品優先排序（預約 > 折扣 > 普通）

### 🔧 技術實現亮點

## 🎯 歷史完成功能
   - 特殊商品優先排序（預約 > 折扣 > 普通）

### 🔧 技術實現亮點


## 🎯 歷史完成功能

### 核心 POS 功能 ✅

### 商品管理 ✅
  1. 特殊商品（預約奇妙 → 祝您有奇妙的一天）
  2. 已結帳商品（按結帳時間降序）
  3. 其他商品（按名稱排序）

### 用戶體驗優化 ✅

### 技術架構 ✅

## 🔧 已知問題

### Samsung Galaxy Tab A9+ 特有問題

## 📋 功能選單架構

已建立完整的功能選單框架（右上角 ⋮ 圖標）：

### 已實現 ✅

### 待開發 🚧

## 🚀 下一步開發計劃

### 優先級 1 - 核心功能完善
1. **匯出功能** - 實現商品資料匯出為 CSV
2. **收據系統** - 儲存和查看交易記錄
3. **營收統計** - 基本的銷售統計功能

### 優先級 2 - 功能增強
1. **商品搜尋** - 在商品列表中搜尋特定商品
2. **庫存管理** - 庫存警示和管理
3. **備份恢復** - 資料備份和恢復功能

### 優先級 3 - 進階功能
1. **多店鋪支援** - 支援多個分店
2. **雲端同步** - 資料雲端備份
3. **更多統計報表** - 詳細的銷售分析

## 🏗️ 技術架構說明

### 核心組件
```
lib/
├── main.dart                 # 應用程式入口點
├── config/
│   └── app_config.dart       # 全域配置（橫向鎖定等）
├── models/
│   ├── product.dart          # 商品資料模型
│   └── cart_item.dart        # 購物車項目模型
├── screens/
│   └── pos_main_screen.dart  # 主 POS 畫面
├── widgets/
│   ├── product_list_widget.dart    # 商品列表組件
│   ├── shopping_cart_widget.dart   # 購物車組件
│   └── price_display.dart          # 價格顯示組件
└── services/
    ├── local_database_service.dart    # 本地資料庫服務
    ├── bluetooth_scanner_service.dart # 掃描器服務
    └── csv_import_service.dart        # CSV 匯入服務
```

### 關鍵技術決策
1. **系統級鍵盤監聽** - 使用 `ServicesBinding.instance.keyboard.addHandler()` 避免焦點問題
2. **StatefulWidget 滾動控制** - ProductListWidget 改為 StatefulWidget 支援滾動控制
3. **商品時間追蹤** - 使用 `lastCheckoutTime` 欄位實現智能排序

## 🔄 Git 工作流程

### 分支策略

### 提交規範
```
✨ feat: 新功能
🐛 fix: 修復 bug
📝 docs: 文件更新
🎨 style: 樣式調整
♻️ refactor: 重構
🚀 perf: 性能優化
```

## 🖥️ 開發環境設置

### Windows 環境（已完成）
1. Flutter SDK
2. VS Code + Flutter 插件
3. Git

### Mac 環境（待設置）
```bash
# 1. Clone 專案
git clone https://github.com/shown721221/cheemeow_pos.git
cd cheemeow_pos

# 2. 安裝依賴
flutter pub get

# 3. 執行開發模式
flutter run

# 4. 建立 Release 版本
flutter build apk --release
```

## 📱 測試裝置

## 💡 設計理念
這個 POS 系統不只是功能性工具，更注重使用者體驗和情感連結：

## 🤖 AI 協作紀錄

### 最後開發狀態（2025年9月9日）

已完成今日重點列表（見上）。系統目前支援：
- 收據列表多條件篩選（含退貨）與總金額顯示。
- 匯出營收 / 熱門度圖片（每日資料夾歸檔）。
- 零用金設定（PIN 保護）並參與人工對帳參考（不併入銷售總額運算邏輯）。
- 預購 / 折扣 / 一般 / 零用金 價格視覺標識統一。
- 貨幣符號統一為 `💲`。

後續若需接續開發，建議優先：
1. 加入金額格式化與測試。
2. README 補充收據資料結構與匯出流程圖。
3. 鍵盤元件化減少重複碼。

### AI 助手續接指南
如果需要 AI 助手繼續協助開發，請參考以下關鍵資訊：

1. **專案特色**：
   - 購物車排序：最新項目在上方（由下往上）
   - 商品列表：智能排序（特殊商品 → 最近結帳 → 其他）
   - 空購物車：❤️ 帶寶寶回家吧 ❤️
   - 結帳後自動滾動到商品列表頂部

2. **技術重點**：
   - 使用系統級鍵盤事件處理條碼掃描
   - ProductListWidget 是 StatefulWidget 支援滾動控制
   - 商品有 lastCheckoutTime 欄位用於排序

3. **待開發功能**：選單中的匯出、收據、營收功能


## 📞 聯絡資訊


*備註：這個 README 會隨著開發進度持續更新*
