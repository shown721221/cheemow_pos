import 'package:flutter/material.dart';
import 'package:cheemeow_pos/services/report_service.dart';
import 'package:cheemeow_pos/services/export_service.dart';
import 'package:cheemeow_pos/utils/capture_util.dart';
import 'package:cheemeow_pos/config/app_messages.dart';
import 'package:cheemeow_pos/services/time_service.dart';
import 'package:cheemeow_pos/config/style_config.dart';
import 'package:cheemeow_pos/utils/date_util.dart';
import 'package:cheemeow_pos/widgets/export_panel.dart';
import 'package:cheemeow_pos/config/character_catalog.dart';

class PopularityExportHelper {
  PopularityExportHelper._();

  static Future<void> exportTodayPopularityImage(BuildContext context) async {
    try {
      final pop = await ReportService.computeTodayPopularityStats();
      // 以集中定義的角色清單初始化映射
      final Map<String, int> baseMap = {for (final c in CharacterCatalog.ordered) c: 0};
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
      // 角色顯示用 emoji 已轉為垂直圖內純文字 (若需回復再加入)。

      final popularityColors = CharacterCatalog.colors;
      final now = TimeService.now();
      final dateStr = DateUtil.ymd(now);

      // 移除舊 metricChip；改由新 statCard 系統。

      // 移除舊 categoryBar 邏輯，改為垂直圖。

      Widget popularityWidget({Key? key}) => ExportPanel(
        repaintBoundaryKey: key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header（與營收面板統一字級，改成獎台風格圖示）
            Row(
              children: [
                const Text(
                  '🥇🥈🥉 寶寶人氣指數',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(dateStr, style: StyleConfig.revenueDateTextStyle),
              ],
            ),
            const SizedBox(height: 14),
            // 統計摘要：強制單行（與面板同寬 800 − padding），以 Row+Expanded 平均分配避免換行。
            Row(
              children: [
                _StatSummaryTile(
                  label: '交易筆數',
                  value: pop.receiptCount,
                  color: Colors.indigo[600]!,
                ),
                const SizedBox(width: 10),
                _StatSummaryTile(
                  label: AppMessages.metricTotalQty,
                  value: pop.totalQty,
                  color: Colors.teal[700]!,
                ),
                const SizedBox(width: 10),
                _StatSummaryTile(
                  label: AppMessages.metricNormalQty,
                  value: pop.normalQty,
                  color: Colors.blue[600]!,
                ),
                const SizedBox(width: 10),
                _StatSummaryTile(
                  label: AppMessages.metricPreorderQty,
                  value: pop.preorderQty,
                  color: Colors.purple[600]!,
                ),
                const SizedBox(width: 10),
                _StatSummaryTile(
                  label: AppMessages.metricDiscountQty,
                  value: pop.discountQty,
                  color: Colors.orange[700]!,
                ),
              ],
            ),
            const SizedBox(height: 18),
            // 垂直統計圖：以柱狀圖方式顯示各角色佔比
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _VerticalPopularityChart(
                  data: sortable,
                  colors: popularityColors,
                  total: totalAll,
                  pct: pct,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppMessages.appTitle,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ),
          ],
        ),
      );

      if (context.mounted) {
        // 預覽與營收面板統一對話框限制（maxWidth 720）
        // ignore: unawaited_futures
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (ctx, cons) => ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(child: popularityWidget()),
                ),
              ),
            ),
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

/// 垂直柱狀統計圖：依 value 排序後由左到右顯示。
class _StatSummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatSummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = HSLColor.fromColor(color)
        .withLightness(
          (HSLColor.fromColor(color).lightness * 0.55).clamp(0.0, 1.0),
        )
        .toColor();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              alignment: Alignment.centerLeft,
              child: Text(
                '$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalPopularityChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  final Map<String, Color> colors;
  final int total;
  final String Function(int) pct;
  const _VerticalPopularityChart({
    required this.data,
    required this.colors,
    required this.total,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('無資料', style: TextStyle(color: Colors.black54)),
      );
    }
    final maxVal =
        (data.map((e) => e.value).fold<int>(0, (p, v) => v > p ? v : p)).clamp(
          1,
          999999,
        );
    return LayoutBuilder(
      builder: (ctx, cons) {
        final barWidth = (cons.maxWidth - (data.length - 1) * 12) / data.length;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < data.length; i++) ...[
              _VerticalBar(
                label: data[i].key,
                value: data[i].value,
                percent: pct(data[i].value),
                color: colors[data[i].key] ?? Colors.blueGrey,
                max: maxVal,
                width: barWidth,
                rank: i,
              ),
              if (i != data.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _VerticalBar extends StatelessWidget {
  final String label;
  final int value;
  final String percent;
  final Color color;
  final int max;
  final double width;
  final int rank; // 0,1,2 冠亞季
  const _VerticalBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.max,
    required this.width,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = value / max;
    final double barHeight = (ratio * 180)
        .clamp(4, 180)
        .toDouble(); // 固定最大高度 180
    final dark = HSLColor.fromColor(color)
        .withLightness(
          (HSLColor.fromColor(color).lightness * 0.55).clamp(0.0, 1.0),
        )
        .toColor();
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            percent,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [color.withValues(alpha: 0.85), color],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: dark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
