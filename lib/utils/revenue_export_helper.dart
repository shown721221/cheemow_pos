import 'package:flutter/material.dart';
import 'package:cheemeow_pos/services/report_service.dart';
import 'package:cheemeow_pos/services/export_service.dart';
import 'package:cheemeow_pos/utils/capture_util.dart';
import 'package:cheemeow_pos/config/app_messages.dart';
import 'package:cheemeow_pos/config/app_config.dart';
import 'package:cheemeow_pos/utils/money_formatter.dart';
import 'package:cheemeow_pos/config/style_config.dart';
import 'package:cheemeow_pos/services/time_service.dart';
import 'package:cheemeow_pos/widgets/export_panel.dart';
import 'package:cheemeow_pos/utils/date_util.dart';

/// 營收匯出版：封裝原先在 PosMainScreen 的巨量方法，減少檔案行數
class RevenueExportHelper {
  RevenueExportHelper._();

  static Future<bool> exportTodayRevenueImage(BuildContext context) async {
    try {
      final summary = await ReportService.computeTodayRevenueSummary();
      final now = TimeService.now();
      final dateStr = DateUtil.ymd(now);

      final tsHeadline = const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
      );
      const gold = Color(0xFFB68600); // 金色
      final tsMetricValueLg = const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: gold,
      );
      final tsMetricValue = const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: gold,
      );

      Widget metricCard({
        String? icon,
        Widget? iconWidget,
        String? title,
        required String value,
        required Color bg,
        Color? valueColor,
        bool large = false,
        bool inline = false,
        TextStyle? titleStyleOverride,
      }) {
        final valueText = Text(
          value,
          style: (large ? tsMetricValueLg : tsMetricValue).copyWith(
            color: valueColor ?? gold,
          ),
          textAlign: TextAlign.center,
        );
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: inline
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (iconWidget != null)
                          SizedBox(height: 24, child: iconWidget)
                        else if (icon != null)
                          Text(icon, style: const TextStyle(fontSize: 22)),
                        if (title != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              style:
                                  titleStyleOverride ??
                                  const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    valueText,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24,
                      child:
                          iconWidget ??
                          (icon != null
                              ? Text(icon, style: const TextStyle(fontSize: 22))
                              : const SizedBox.shrink()),
                    ),
                    if (title != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style:
                            titleStyleOverride ??
                            const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                    ],
                    valueText,
                  ],
                ),
        );
      }

      String money(int v) => MoneyFormatter.thousands(v);
      Color bg1 = StyleConfig.revenueBgPreorder;
      Color bg2 = StyleConfig.revenueBgLinePay;
      Color bg3 = StyleConfig.revenueBgCash;
      Color bg4 = StyleConfig.revenueBgTransfer;
      String mask(int v, bool show) => show ? money(v) : '💰';

      Widget revenueWidget({required bool showNumbers, Key? key}) {
        return ExportPanel(
          repaintBoundaryKey: key,
          constrainMinHeight: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(AppMessages.revenueTodayTitle, style: tsHeadline),
                  const Spacer(),
                  Text(dateStr, style: StyleConfig.revenueDateTextStyle),
                ],
              ),
              if (AppConfig.pettyCash > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '零用金 ${MoneyFormatter.symbol(AppConfig.pettyCash)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    mask(summary.total, showNumbers),
                    style: tsHeadline.copyWith(
                      color: gold,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: metricCard(
                      icon: '�',
                      title: 'Cash',
                      value: mask(summary.cash, showNumbers),
                      bg: bg3,
                      inline: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: metricCard(
                      iconWidget: Image.asset(
                        'assets/images/cathay.png',
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      // no title per requirement
                      title: null,
                      value: mask(summary.transfer, showNumbers),
                      bg: bg4,
                      inline: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: metricCard(
                      iconWidget: Image.asset(
                        'assets/images/linepay.png',
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                      title: null,
                      value: mask(summary.linepay, showNumbers),
                      bg: bg2,
                      inline: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: metricCard(
                      icon: '🎁',
                      title: AppMessages.metricPreorderSubtotal,
                      value: mask(summary.preorder, showNumbers),
                      bg: bg1,
                      inline: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: metricCard(
                      icon: '💸',
                      title: AppMessages.metricDiscountSubtotal,
                      value: mask(summary.discount, showNumbers),
                      bg: const Color(0xFFFFEEF0),
                      valueColor: gold,
                      inline: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
      }

      // 預覽對話框
      if (context.mounted) {
        bool previewShowNumbers = false;
        // ignore: unawaited_futures
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => Dialog(
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
                    child: GestureDetector(
                      onTap: () {
                        previewShowNumbers = !previewShowNumbers;
                        setLocal(() {});
                      },
                      child: revenueWidget(showNumbers: previewShowNumbers),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (!context.mounted) return false;
      final bytes = await CaptureUtil.captureWidget(
        context: context,
        builder: (k) => revenueWidget(showNumbers: true, key: k),
        pixelRatio: 3.0,
      );

      final fileName = '營收_${DateUtil.ymdCompact(now)}.png';
      final res = await ExportService.instance.savePng(
        fileName: fileName,
        bytes: bytes,
      );
      if (!context.mounted) return res.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success
                ? AppMessages.exportRevenueSuccess(res.paths.join('\n'))
                : AppMessages.exportRevenueFailure(
                    res.failure?.message ?? '未知錯誤',
                  ),
          ),
        ),
      );
      return res.success;
    } catch (e) {
      if (!context.mounted) return false;
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppMessages.exportRevenueFailure(e))),
      );
      return false;
    }
  }
}
