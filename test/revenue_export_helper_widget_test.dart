import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevenueExportHelper mask rendering (simplified)', () {
    testWidgets('masked shows 💰, unmasked shows numbers', (tester) async {
      String money(int v) => v.toString();
      String mask(int v, bool show) => show ? money(v) : '💰';

      Widget panel(bool showNumbers) => MaterialApp(
        home: Material(
          child: Column(
            children: [
              Text(mask(12345, showNumbers), key: const Key('total')),
              Text(mask(100, showNumbers), key: const Key('cash')),
            ],
          ),
        ),
      );

      await tester.pumpWidget(panel(false));
      expect(find.byKey(const Key('total')), findsOneWidget);
      expect(find.text('💰'), findsNWidgets(2));

      await tester.pumpWidget(panel(true));
      await tester.pump();
      expect(find.text('12345'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('💰'), findsNothing);
    });
  });
}
