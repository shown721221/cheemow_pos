import 'package:flutter/material.dart';
import 'package:cheemeow_pos/services/report_service.dart';
import 'package:cheemeow_pos/services/export_service.dart';
import 'package:cheemeow_pos/utils/capture_util.dart';
import 'package:cheemeow_pos/config/app_messages.dart';
import 'package:cheemeow_pos/services/time_service.dart';

class PopularityExportHelper {
  PopularityExportHelper._();

  static Future<void> exportTodayPopularityImage(BuildContext context) async {
    try {
      final pop = await ReportService.computeTodayPopularityStats();
      final fixedCats = [
        'Duffy',
        'ShellieMay',
        'Gelatoni',
        'StellaLou',
        'CookieAnn',
        'OluMel',
        'LinaBell',
      ];
      final Map<String, int> baseMap = {for (final c in fixedCats) c: 0};
      int others = 0;
      pop.categoryCount.forEach((String k, int v) {
        if (baseMap.containsKey(k)) {
          baseMap[k] = baseMap[k]! + v;
        } else {
          others += v;
        }
      });
      final totalAll = pop.totalQty;
      String pct(int v) => pop.totalQty == 0
          ? '0%'
          : '${((v * 1000 / (pop.totalQty == 0 ? 1 : pop.totalQty)).round() / 10).toStringAsFixed(1)}%';
      final sortable = [
        ...baseMap.entries.map((e) => MapEntry(e.key, e.value)),
        MapEntry('其他角色', others),
      ]..sort((a, b) => b.value.compareTo(a.value));
      String deco(String raw) {
        switch (raw) {
          case 'Duffy':
            return '🐻 Duffy';
          case 'ShellieMay':
            return '🐻 ShellieMay';
          case 'Gelatoni':
            return '🐱 Gelatoni';
          case 'StellaLou':
            return '🐰 StellaLou';
          case 'CookieAnn':
            return '🐶 CookieAnn';
          case 'OluMel':
            return '🐢 OluMel';
          case 'LinaBell':
            return '🦊 LinaBell';
          case '其他角色':
            return '🏰 其他角色';
          default:
            return raw;
        }
      }

      final popularityColors = <String, Color>{
        'Duffy': Colors.brown[400]!,
        'ShellieMay': Colors.pink[300]!,
        'Gelatoni': Colors.teal[400]!,
        'StellaLou': Colors.purple[300]!,
        'CookieAnn': Colors.amber[400]!,
        'OluMel': Colors.green[300]!,
        'LinaBell': Colors.pink[200]!,
        '其他角色': Colors.blueGrey[300]!,
      };
      final now = TimeService.now();
      final dateStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      Widget metricChip(String label, int value, Color color) {
        Color darken(Color c) {
          final hsl = HSLColor.fromColor(c);
          final dark = hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0));
          return dark.toColor();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: darken(color))),
              const SizedBox(height: 2),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: darken(color),
                ),
              ),
            ],
          ),
        );
      }

      Widget categoryBar(
        String name,
        int count,
        String percent,
        int total,
        Color barColor, [
        String? medal,
      ]) {
        final ratio = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  medal ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              SizedBox(
                width: 128,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Stack(
                      children: [
                        Container(height: 18, color: Colors.blueGrey[50]),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  barColor.withValues(alpha: 0.85),
                                  barColor,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  percent,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      Widget popularityWidget({Key? key}) => RepaintBoundary(
        key: key,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          width: 560,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    '🍼 寶寶人氣指數',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  metricChip('交易筆數', pop.receiptCount, Colors.indigo[600]!),
                  metricChip(
                    AppMessages.metricTotalQty,
                    pop.totalQty,
                    Colors.teal[700]!,
                  ),
                  metricChip(
                    AppMessages.metricNormalQty,
                    pop.normalQty,
                    Colors.blue[600]!,
                  ),
                  metricChip(
                    AppMessages.metricPreorderQty,
                    pop.preorderQty,
                    Colors.purple[600]!,
                  ),
                  metricChip(
                    AppMessages.metricDiscountQty,
                    pop.discountQty,
                    Colors.orange[700]!,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (int i = 0; i < sortable.length; i++) ...[
                categoryBar(
                  deco(sortable[i].key),
                  sortable[i].value,
                  pct(sortable[i].value),
                  totalAll,
                  popularityColors[sortable[i].key] ?? Colors.blueGrey,
                  i == 0
                      ? '🥇'
                      : i == 1
                      ? '🥈'
                      : i == 2
                      ? '🥉'
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'CheeMeow POS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (context.mounted) {
        // ignore: unawaited_futures
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: SingleChildScrollView(child: popularityWidget()),
          ),
        );
      }
      if (!context.mounted) return;

      final bytes = await CaptureUtil.captureWidget(
        context: context,
        builder: (k) => popularityWidget(key: k),
        pixelRatio: 3.0,
      );

      final fileName = '人氣指數_$dateStr.png';
      final res = await ExportService.instance.savePng(
        fileName: fileName,
        bytes: bytes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success && res.paths.isNotEmpty
                ? AppMessages.popularityExportSuccess(res.paths.first)
                : AppMessages.popularityExportFailure +
                      (res.failure != null ? ' (${res.failure!.message})' : ''),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppMessages.popularityExportError(e))),
      );
    }
  }
}
