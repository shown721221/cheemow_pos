import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/mood_helper.dart';

void main() {
  group('MoodHelper.moodEmoji', () {
    test('sad boundary', () {
      expect(MoodHelper.moodEmoji(0), '😿');
      expect(MoodHelper.moodEmoji(MoodHelper.sadUpper), '😿');
    });
    test('happy boundary range', () {
      expect(MoodHelper.moodEmoji(MoodHelper.sadUpper + 1), '😻');
      expect(MoodHelper.moodEmoji(MoodHelper.happyUpper), '😻');
    });
    test('rich beyond happyUpper', () {
      expect(MoodHelper.moodEmoji(MoodHelper.happyUpper + 1), '🤑');
    });
  });
}
