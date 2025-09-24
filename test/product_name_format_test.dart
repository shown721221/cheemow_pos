import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_style_utils.dart';

void main() {
  group('formatProductNameForMainCard', () {
    test('任意位置的「Disney限定」應替換為「..」', () {
      const input = '東京Disney限定 達菲20週年 LinaBell 站姿吊飾';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, '東京.. 達菲20週年 LinaBell 站姿吊飾');
    });

    test('不含Disney限定，維持原樣', () {
      const input = '東京 海外特典 史迪奇抱枕';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, input);
    });

    test('非東京開頭，維持原樣', () {
      const input = '大阪限定 小熊維尼鑰匙圈';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, input);
    });

    test('僅「東京」兩字，維持原樣', () {
      const input = '東京';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, input);
    });

    test('只有Disney限定一詞時，替換為「..」', () {
      const input = 'Disney限定';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, '..');
    });

    test('多次出現Disney限定皆替換為「..」並壓平多空白', () {
      const input = '大阪 Disney限定 特別版 Disney限定 造型';
      final out = ProductStyleUtils.formatProductNameForMainCard(input);
      expect(out, '大阪 .. 特別版 .. 造型');
    });
  });
}
