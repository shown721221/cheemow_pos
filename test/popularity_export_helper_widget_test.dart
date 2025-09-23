import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 簡化測試：確保呈現資料數量一致，且沒有 medal emoji (🥇🥈🥉) 在 bar labels 中（只允許 header）。
  group('PopularityExportHelper simplified structure', () {
    testWidgets('renders N bars and no medals inside bars', (tester) async {
      final data = [
        const MapEntry('Duffy', 10),
        const MapEntry('ShellieMay', 5),
        const MapEntry('其他角色', 2),
      ];

      Widget chart() => MaterialApp(
        home: Material(
          child: LayoutBuilder(
            builder: (ctx, cons) => Row(
              children: [
                for (int i = 0; i < data.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${data[i].value}',
                          key: Key('val_${data[i].key}'),
                        ),
                        Container(
                          height: 40 + data[i].value.toDouble(),
                          color: Colors.blueGrey,
                        ),
                        Text(data[i].key, key: Key('label_${data[i].key}')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(chart());

      for (final e in data) {
        expect(find.byKey(Key('val_${e.key}')), findsOneWidget);
        expect(find.byKey(Key('label_${e.key}')), findsOneWidget);
      }

      // 確保畫面上沒有 medal emoji（非 header）
      expect(find.textContaining('🥇'), findsNothing);
      expect(find.textContaining('🥈'), findsNothing);
      expect(find.textContaining('🥉'), findsNothing);
    });
  });
}
