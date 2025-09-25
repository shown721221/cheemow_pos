import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/config/filter_rules.dart';

void main() {
  group('FilterRules location', () {
    test('東京 matches any keyword', () {
      for (final kw in FilterRules.location['東京']!) {
        expect(FilterRules.matchLocation('東京', kw), isTrue, reason: kw);
      }
      expect(FilterRules.matchLocation('東京', 'osaka'), isFalse);
    });
  });

  group('FilterRules characters', () {
    test('GelaToni keyword', () {
      expect(FilterRules.matchCharacter('GelaToni', 'xxgelatoniyy'), isTrue);
      expect(FilterRules.matchCharacter('GelaToni', 'random'), isFalse);
    });
  });

  group('FilterRules types', () {
    test('其他吊飾 must include 吊飾 and not 站姿/坐姿', () {
      expect(FilterRules.matchType('其他吊飾', '夢幻吊飾版'), isTrue);
      expect(FilterRules.matchType('其他吊飾', '夢幻站姿吊飾'), isFalse);
      expect(FilterRules.matchType('其他吊飾', '夢幻坐姿吊飾'), isFalse);
      expect(FilterRules.matchType('其他吊飾', '沒有關鍵詞'), isFalse);
    });
  });

  group('FilterRules other角色', () {
    test('其他角色 true when no known character keywords present', () {
      expect(FilterRules.isKnownCharacterName('superduper'), isFalse);
      expect(FilterRules.isKnownCharacterName('hellogelatoniworld'), isTrue);
    });
  });
}
