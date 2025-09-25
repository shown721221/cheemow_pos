/// 字體設定集中：避免硬字串散落。
class FontConfig {
  FontConfig._();
  static const productFontFamily = 'SourceHanSansTC';
  // Debug 用：快速驗證是否真的套用到商品卡文字。完成確認後可改為 false 或移除。
  static const enableProductFontDebugVisual = false; // 已驗證字體載入，恢復正常
  // 後續若要全域套用，可在 AppTheme 中引用此常數。
  // 後續若要全域套用，可在 AppTheme 中引用此常數。
}
