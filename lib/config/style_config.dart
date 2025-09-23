import 'package:flutter/material.dart';
import 'app_theme.dart';

/// 集中顏色 / 樣式，避免重複硬編。
class StyleConfig {
  static const preorderColor = Color(0xFF7E57C2); // 預購（紫）
  static const discountColor = Color(0xFFFB8C00); // 折扣（橘）
  static const normalTextColor = Color(0xFF37474F); // 一般字色（藍灰深）

  // 常用間距（集中調整）
  static const double gap8 = 8;
  static const double gap12 = 12;
  static const double gap16 = 16;

  // 主動作按鈕顏色
  static const Color primaryActionColor = Color(0xFF2E7D32); // 綠
  static const Color primaryOnColor = Colors.white;

  // 常用按鈕樣式（供 Dialog/支付對話框共用）
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: primaryActionColor,
    foregroundColor: primaryOnColor,
  );

  static ButtonStyle payOptionSelectedStyle = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: AppColors.primaryContainer, // 淺色底
    foregroundColor: AppColors.primary, // 文字 / 圖片主色
    padding: const EdgeInsets.symmetric(horizontal: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: AppColors.primary.withValues(alpha: .35),
        width: 1,
      ),
    ),
  );

  static ButtonStyle payOptionUnselectedStyle = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(44),
    backgroundColor: AppColors.subtleBg, // 更淺的底
    foregroundColor: AppColors.normalText,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    side: BorderSide(
      color: AppColors.neutralBorder.withValues(alpha: .4),
      width: 1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  // 營收卡顏色主題（集中管理）
  static const revenueBgPreorder = Color(0xFFFFF0F6); // 粉
  static const revenueBgLinePay = Color(0xFFE8F5FF); // 淡藍
  static const revenueBgCash = Color(0xFFEFFFF2); // 淡綠
  static const revenueBgTransfer = Color(0xFFFFF9E6); // 淡黃

  // 營收卡日期樣式（可在此統一調整）
  static const TextStyle revenueDateTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.black54,
  );

  // 匯出面板固定尺寸（以營收圖為基準）
  static const double exportPanelWidth = 800;
  // 統一匯出面板高度（以目前營收面板自然高度為基準，留少許緩衝）
  // 若日後內容增減可調整此值。Popularity 面板會以此高度顯示（內容較少則底部留白）。
  // 440 會在有零用金列時略微 overflow，調升到 470 保留約 10~15px 緩衝
  static const double exportPanelHeight = 470;
  // 高度若未指定則以內容撐開；如需硬指定可另外加 exportPanelRevenueHeight 等。
  static const EdgeInsets exportPanelPadding = EdgeInsets.fromLTRB(
    28,
    28,
    28,
    24,
  );

  static TextStyle badgeText(Color c) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c);

  static BoxDecoration tagBox(Color c) => BoxDecoration(
    color: c.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: c.withValues(alpha: .5)),
  );
}
