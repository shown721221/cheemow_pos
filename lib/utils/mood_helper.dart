/// 心情指數門檻與對應 emoji。
class MoodHelper {
  MoodHelper._();
  static const int sadUpper = 70000; // <= 悲傷
  static const int happyUpper = 120000; // <= 開心（介於 sadUpper+1 ~ happyUpper）

  static String moodEmoji(int total) {
    if (total <= sadUpper) return '😿';
    if (total <= happyUpper) return '😻';
    return '🤑';
  }
}
