/// 輕量 UI 共用常數/emoji，避免散落 magic number / 字串。
class UiTokens {
  UiTokens._();
  // Emojis
  static const productTabEmoji = '🧸';
  static const searchTabEmoji = '🔎';
  static const cartEmptyEmoji = '🛍️';

  // Spacing (若與 StyleConfig 重疊，後續可合併；此處僅放視覺精簡需求)
  static const gap4 = 4.0;
  static const gap8 = 8.0;
  static const gap12 = 12.0;
  static const gap16 = 16.0;
  static const gap20 = 20.0;
}
