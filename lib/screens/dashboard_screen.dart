import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// اللوحة الرئيسية: إحصائيات المكلفين ثم المبيعات والتحليل.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final dark = context.p.isDark;
    final declines = st.declines().length;
    final monthly = List<double>.generate(
        12, (i) => st.sales.values.fold<double>(0, (a, s) => a + s.monthly[i]));
    final totalYear = monthly.fold<double>(0, (a, v) => a + v);
    final currentMonth = monthly.isEmpty ? 0.0 : monthly[11];
    final avgMonth = totalYear / 12;
    final taxpayerCounts = [
      st.taxpayers.length,
      st.taxpayers.where((t) => t.status == 'فعال').length,
      st.taxpayers.where((t) => t.status == 'متوقف نهائياً').length,
      st.taxpayers.where((t) => t.status == 'متوقف مؤقتاً').length,
    ];

    Widget section(
      String title, {
      String hint = '',
      required Color color,
      required IconData icon,
    }) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: dark ? .2 : .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.p.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );

    Widget iconTile(IconData icon, Color color, {double size = 42}) =>
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? .18 : .11),
              borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(icon, color: color, size: size * .48),
        );

    final now = DateTime.now();
    const months = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول'
    ];
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    final dateLine =
        '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';

    final taxpayerStats = [
      (
        'إجمالي المكلفين',
        taxpayerCounts[0],
        CupertinoIcons.person_3_fill,
        kPrimary
      ),
      (
        'المكلفون الفعالون',
        taxpayerCounts[1],
        CupertinoIcons.checkmark_seal_fill,
        kPrimary2
      ),
      ('المتوقفون مؤقتاً', taxpayerCounts[3], CupertinoIcons.clock_fill, kGold),
      (
        'المتوقفون نهائياً',
        taxpayerCounts[2],
        CupertinoIcons.pause_circle_fill,
        kRed
      ),
    ];

    final dateChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .06)
            : const Color(0xFFEAF3F1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(CupertinoIcons.calendar_today, size: 12, color: kPrimary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(dateLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.p.muted)),
        ),
      ]),
    );

    return PageBody(
      children: [
        // رأس الصفحة: عنوان اللوحة، تاريخ اليوم، وأزرار العمل.
        Container(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF15201E), Color(0xFF0F1615)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF1F7F5)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: context.p.border, width: .6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .28 : .05),
                  blurRadius: 24,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/logos/dept_logo.png',
                  width: 100,
                  height: 82,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('الجمهورية العربية السورية',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: context.p.muted)),
                  const SizedBox(height: 3),
                  const Text('وزارة المالية',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const Text('الهيئة العامة للضرائب والرسوم',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('مديرية مالية اللاذقية',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: dateChip,
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: context.p.border),
            ],
          ),
        ),
        section(
          'إحصائيات المكلفين',
          hint: 'توزيع المكلفين حسب الحالة',
          color: kPrimary,
          icon: CupertinoIcons.person_3_fill,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920
                ? 4
                : constraints.maxWidth >= 550
                    ? 2
                    : 1;
            const spacing = 12.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < taxpayerStats.length; i++)
                  SizedBox(
                    width: width,
                    child: _TaxpayerStatCard(
                      label: taxpayerStats[i].$1,
                      count: taxpayerStats[i].$2,
                      icon: taxpayerStats[i].$3,
                      color: taxpayerStats[i].$4,
                      animationOrder: i,
                    ),
                  ),
              ],
            );
          },
        ),
        section(
          'المبيعات والتحليل',
          hint: 'ملخص الأداء خلال آخر ١٢ شهراً',
          color: kPrimary2,
          icon: CupertinoIcons.chart_bar_alt_fill,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 590
                    ? 2
                    : 1;
            const spacing = 14.0;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final stats = [
              (
                'إجمالي المبيعات',
                money(totalYear),
                CupertinoIcons.money_dollar_circle,
                kPrimary,
              ),
              (
                'مبيعات الشهر الحالي',
                money(currentMonth),
                CupertinoIcons.chart_bar_alt_fill,
                kPrimary2,
              ),
              (
                'المتوسط الشهري',
                money(avgMonth),
                CupertinoIcons.graph_square,
                kGold,
              ),
              (
                'انخفاض المبيعات',
                '$declines مكلف',
                CupertinoIcons.arrow_down_right,
                kRed,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < stats.length; i++)
                  SizedBox(
                    width: width,
                    child: _SalesKpiCard(
                      label: stats[i].$1,
                      value: stats[i].$2,
                      icon: stats[i].$3,
                      color: stats[i].$4,
                      animationOrder: i,
                    ),
                  ),
              ],
            );
          },
        ),
        AppCard(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LayoutBuilder(
              builder: (c, cons) {
                final title = Row(children: [
                  iconTile(CupertinoIcons.chart_bar_alt_fill, kPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('حركة المبيعات الشهرية',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2)),
                          const SizedBox(height: 4),
                          Text(
                              'إجمالي مبيعات المكلفين لكل شهر (بيانات تجريبية)',
                              style: TextStyle(
                                  color: context.p.muted, fontSize: 12)),
                        ]),
                  ),
                ]);
                final declineBadge = declines > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF4A1F22)
                                : const Color(0xFFFDE7E9),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$declines انخفاض',
                            style: TextStyle(
                                color: dark
                                    ? const Color(0xFFFFB4AB)
                                    : const Color(0xFFB3261E),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      )
                    : const SizedBox.shrink();
                return cons.maxWidth < 600
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            title,
                            if (declines > 0) ...[
                              const SizedBox(height: 12),
                              declineBadge,
                            ],
                          ])
                    : Row(children: [
                        Expanded(child: title),
                        if (declines > 0) ...[
                          const SizedBox(width: 12),
                          declineBadge,
                        ],
                      ]);
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
              decoration: BoxDecoration(
                  color: context.p.surfaceAlt,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: context.p.border.withValues(alpha: .7),
                  )),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: context.p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.p.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: kGold.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${DateTime.now().month}',
                              style: const TextStyle(
                                color: kGold,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'آخر شهر مسجل',
                                style: TextStyle(
                                  color: context.p.muted,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                money(monthly[11]),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AnimatedSalesChart(monthly),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 8, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: kPrimary2,
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('ارتفاع عن الشهر السابق',
                    style: TextStyle(color: context.p.muted, fontSize: 11.5)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: kRed, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('انخفاض عن الشهر السابق',
                    style: TextStyle(color: context.p.muted, fontSize: 11.5)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: kGold.withValues(alpha: .6)),
                    )),
                const SizedBox(width: 6),
                Text('الشهر الحالي',
                    style: TextStyle(color: context.p.muted, fontSize: 11.5)),
              ]),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _TaxpayerStatCard extends StatefulWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final int animationOrder;

  const _TaxpayerStatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.animationOrder,
  });

  @override
  State<_TaxpayerStatCard> createState() => _TaxpayerStatCardState();
}

class _SalesKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final int animationOrder;

  const _SalesKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.animationOrder,
  });

  @override
  State<_SalesKpiCard> createState() => _SalesKpiCardState();
}

class _SalesKpiCardState extends State<_SalesKpiCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.p;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Interval(
          widget.animationOrder * .09,
          1,
          curve: Curves.easeOutCubic,
        ).transform(_controller.value);
        final scale = .97 + .03 * Curves.easeOutBack.transform(progress);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: Transform.scale(
              scale: scale,
              child: Container(
                constraints: const BoxConstraints(minHeight: 142),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      palette.surface,
                      Color.lerp(
                        palette.surface,
                        widget.color,
                        palette.isDark ? .09 : .045,
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color
                          .withValues(alpha: palette.isDark ? .12 : .08),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: -62,
                      end: -54,
                      child: Container(
                        width: 138,
                        height: 138,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: .055),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: widget.color.withValues(
                                    alpha: palette.isDark ? .2 : .12),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(widget.icon,
                                  color: widget.color, size: 21),
                            ),
                            const Spacer(),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSalesChart extends StatefulWidget {
  final List<double> values;

  const _AnimatedSalesChart(this.values);

  @override
  State<_AnimatedSalesChart> createState() => _AnimatedSalesChartState();
}

class _AnimatedSalesChartState extends State<_AnimatedSalesChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  String _compactValue(double value) {
    final absolute = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absolute >= 1000000) {
      return '$sign${(absolute / 1000000).toStringAsFixed(1)}M';
    }
    if (absolute >= 1000) {
      return '$sign${(absolute / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final values = widget.values.reversed.toList();
          final currentMonth = DateTime.now().month - 1;
          final labels = List.generate(
            values.length,
            (i) => '${((currentMonth - i) % 12 + 12) % 12 + 1}',
          );
          final valueLabels = values.map(_compactValue).toList();
          final trendColors = List.generate(values.length, (i) {
            final monthIndex = widget.values.length - 1 - i;
            if (monthIndex <= 0) return context.p.muted;
            final current = widget.values[monthIndex];
            final previous = widget.values[monthIndex - 1];
            if (current > previous) return kPrimary2;
            if (current < previous) return kRed;
            return context.p.muted;
          });
          return BarChart(
            values,
            height: 230,
            highlightLast: false,
            highlightIndex: 0,
            labels: labels,
            valueLabels: valueLabels,
            barColors: trendColors,
            interactive: true,
            progress: Curves.easeOutCubic.transform(_controller.value),
          );
        },
      );
}

class _TaxpayerStatCardState extends State<_TaxpayerStatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.p;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Interval(
          widget.animationOrder * .08,
          1,
          curve: Curves.easeOutCubic,
        ).transform(_controller.value);
        final scale =
            .96 + .04 * Curves.easeOutBack.transform(_controller.value);
        return Opacity(
          key: ValueKey('taxpayer-stat-card-${widget.animationOrder}'),
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - progress)),
            child: Transform.scale(
              scale: scale,
              child: Container(
                constraints: const BoxConstraints(minHeight: 116),
                padding: const EdgeInsets.all(18),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      palette.surface,
                      Color.lerp(
                        palette.surface,
                        widget.color,
                        palette.isDark ? .045 : .025,
                      )!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color
                          .withValues(alpha: palette.isDark ? .13 : .09),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: -50,
                      end: -44,
                      child: Container(
                        width: 116,
                        height: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: .045),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Transform.scale(
                          scale: .9 +
                              .1 *
                                  Curves.easeOutBack.transform(
                                    _controller.value,
                                  ),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: widget.color.withValues(
                                  alpha: palette.isDark ? .20 : .12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(widget.icon,
                                color: widget.color, size: 23),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: palette.muted, fontSize: 12),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${(widget.count * progress).round()}',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
