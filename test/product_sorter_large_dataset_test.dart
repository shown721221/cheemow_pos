import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/utils/product_sorter.dart';
import 'package:cheemeow_pos/models/product.dart';

void main() {
  group('ProductSorter.sortDaily large dataset', () {
    test(
      'stable ordering with >200 items; specials pinned; today sold recent first',
      () {
        final now = DateTime(2025, 9, 10, 12, 0, 0);
        final yesterday = now.subtract(const Duration(days: 1));

        int counter = 0;
        Product buildNormal({DateTime? last}) {
          final id = 'N$counter';
          final nameNumber = counter.toString().padLeft(3, '0');
          final p = Product(
            id: id,
            barcode: 'bn$counter',
            name: '普通商品$nameNumber',
            price: 50,
            lastCheckoutTime: last,
          );
          counter++;
          return p;
        }

        // 生成 220 筆普通商品，其中 15 筆為今日售出 (分佈不同時間) 。
        final normals = <Product>[];
        for (var i = 0; i < 205; i++) {
          DateTime? time;
          if (i < 15) {
            // 今日售出時間遞增，最後生成的時間最新
            time = now.subtract(Duration(minutes: i * 3));
          } else {
            time = yesterday.subtract(Duration(minutes: i));
          }
          normals.add(buildNormal(last: time));
        }

        // 特殊商品：預購 3 筆，折扣 2 筆（全部未售出）
        final specialPreorders = List.generate(
          3,
          (i) => Product(
            id: 'PPO$i',
            barcode: '19920203',
            name: '預購$i',
            price: 0,
            lastCheckoutTime: yesterday,
          ),
        );
        final specialDiscounts = List.generate(
          2,
          (i) => Product(
            id: 'PDC$i',
            barcode: '88888888',
            name: '折扣$i',
            price: -10,
            lastCheckoutTime: yesterday,
          ),
        );

        final all = [...normals, ...specialDiscounts, ...specialPreorders];

        final result = ProductSorter.sortDaily(
          all,
          now: now,
          forcePinSpecial: true,
        );

        // 1) 特殊商品應全部置頂，且預購在折扣之前
        final topFive = result.take(5).toList();
        expect(topFive.where((p) => p.id.startsWith('PPO')).length, 3);
        expect(topFive.where((p) => p.id.startsWith('PDC')).length, 2);
        expect(topFive.map((p) => p.id).toList(), [
          'PPO0',
          'PPO1',
          'PPO2',
          'PDC0',
          'PDC1',
        ]);

        // 2) 接下來的 15 筆應為今日售出 (normals 中 i < 15)
        final nextFifteen = result.skip(5).take(15).toList();
        expect(nextFifteen.length, 15);
        expect(
          nextFifteen.every((p) => p.lastCheckoutTime!.day == now.day),
          isTrue,
        );

        // 3) 今日售出部分必須按時間新->舊 排序 (第一筆 minutes 最少)
        for (var i = 0; i < nextFifteen.length - 1; i++) {
          final a = nextFifteen[i];
          final b = nextFifteen[i + 1];
          expect(
            a.lastCheckoutTime!.isAfter(b.lastCheckoutTime!) ||
                a.lastCheckoutTime!.isAtSameMomentAs(b.lastCheckoutTime!),
            isTrue,
            reason: '今日售出列表未按時間遞減排序',
          );
        }

        // 4) 其餘未售出普通商品應依名稱字典序（已零填補）遞增。
        final remaining = result
            .skip(5 + 15)
            .where((p) => p.id.startsWith('N'))
            .toList();
        for (var i = 0; i < remaining.length - 1; i++) {
          expect(
            remaining[i].name.compareTo(remaining[i + 1].name) <= 0,
            isTrue,
            reason: '未售出普通商品名稱排序錯誤於 index $i',
          );
        }

        // 5) 簡單效能：確保總數不變 且排序未產生重複或遺失
        expect(result.length, all.length);
        expect(result.toSet().length, all.length);
      },
    );
  });
}
