import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';

void _text(Canvas c, String t, Offset o, Color color) {
  final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(fontSize: 10, color: color)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, Offset(o.dx - tp.width / 2, o.dy));
}

/// أعمدة: الفهرس 0 (الأقدم) في اليمين ليتوافق مع اتجاه القراءة العربي.
class BarChart extends StatefulWidget {
  final List<double> values;
  final Color color;
  final bool highlightLast;
  final int labelEvery;
  final double height;
  final double progress;
  final List<String>? labels;
  final List<String>? valueLabels;
  final List<Color>? barColors;
  final bool interactive;
  final int? highlightIndex;
  const BarChart(this.values,
      {super.key,
      this.color = kPrimary2,
      this.highlightLast = true,
      this.labelEvery = 1,
      this.height = 170,
      this.progress = 1,
      this.labels,
      this.valueLabels,
      this.barColors,
      this.interactive = false,
      this.highlightIndex});

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _selectionController;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_handleSelectionAnimation);
  }

  void _handleSelectionAnimation() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _selectionController.removeListener(_handleSelectionAnimation);
    _selectionController.dispose();
    super.dispose();
  }

  void _selectAt(Offset position, double width) {
    if (widget.values.isEmpty || width <= 0) return;
    final barWidth = width / widget.values.length;
    final index = ((width - position.dx) / barWidth)
        .floor()
        .clamp(0, widget.values.length - 1)
        .toInt();
    setState(() => _selectedIndex = index);
    _selectionController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final chart = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = _BarsPainter(
            widget.values,
            widget.color,
            widget.highlightLast,
            widget.labelEvery,
            context.p.muted,
            context.p.grid,
            widget.progress,
            labels: widget.labels,
            valueLabels: widget.valueLabels,
            barColors: widget.barColors,
            selectedIndex: _selectedIndex,
            selectionProgress: _selectionController.value,
            highlightIndex: widget.highlightIndex,
          );
          final paint = CustomPaint(
            size: Size(constraints.maxWidth, widget.height),
            painter: painter,
          );
          if (!widget.interactive) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _selectAt(details.localPosition, constraints.maxWidth),
            child: paint,
          );
        },
      ),
    );
    if (!widget.interactive) return chart;
    final selected = _selectedIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chart,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: selected == null
              ? const SizedBox(
                  key: ValueKey('chart-selection-hint'),
                  height: 34,
                )
              : Padding(
                  key: ValueKey('chart-selection-$selected'),
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 14,
                        color: widget.barColors?[selected] ?? widget.color,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${widget.labels != null && selected < widget.labels!.length ? widget.labels![selected] : selected + 1}  ·  ${widget.values[selected].toStringAsFixed(0)}',
                        style: TextStyle(
                          color: context.p.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final bool hlLast;
  final int every;
  final Color labelColor, gridColor;
  final double progress;
  final List<String>? labels;
  final List<String>? valueLabels;
  final List<Color>? barColors;
  final int? selectedIndex;
  final int? highlightIndex;
  final double selectionProgress;
  _BarsPainter(this.v, this.color, this.hlLast, this.every, this.labelColor,
      this.gridColor, this.progress,
      {this.labels,
      this.valueLabels,
      this.barColors,
      this.selectedIndex,
      this.highlightIndex,
      this.selectionProgress = 0});
  @override
  void paint(Canvas c, Size s) {
    if (v.isEmpty) return;
    final maximum = v.reduce(max);
    final mx = maximum <= 0 ? 1.0 : maximum * 1.1;
    final animation = progress.clamp(0.0, 1.0);
    final w = s.width / v.length;
    final h = s.height - (valueLabels == null ? 22 : 42);
    final barWidth = w * .58;
    final barInset = (w - barWidth) / 2;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var k = 0; k < 3; k++) {
      final y = 8 + k * (h - 8) / 2;
      c.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    if (hlLast || highlightIndex != null) {
      final index = highlightIndex ?? v.length - 1;
      final x = s.width - (index + 1) * w + barInset / 2;
      final highlight = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 3, w - barInset, h + 8),
        const Radius.circular(14),
      );
      c.drawRRect(
        highlight,
        Paint()
          ..color =
              (highlightIndex != null ? kGold : color).withValues(alpha: .07),
      );
    }
    c.drawLine(
      Offset(0, h),
      Offset(s.width, h),
      Paint()
        ..color = gridColor.withValues(alpha: .9)
        ..strokeWidth = 1.2,
    );
    for (var i = 0; i < v.length; i++) {
      final selected = selectedIndex == i;
      final selectedScale =
          selected ? 1 + .12 * sin(pi * selectionProgress) : 1.0;
      final bh = v[i] / mx * (h - 8) * animation * selectedScale;
      final x = s.width - (i + 1) * w + barInset;
      if (bh > 0) {
        if (selected) {
          final halo = RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 5, h - bh - 6, barWidth + 10, bh + 12),
            const Radius.circular(12),
          );
          c.drawRRect(
            halo,
            Paint()
              ..color = (barColors != null && i < barColors!.length
                      ? barColors![i]
                      : color)
                  .withValues(alpha: .13 * selectionProgress),
          );
        }
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h - bh, barWidth, bh),
          Radius.circular(barWidth / 2 < 9 ? barWidth / 2 : 9),
        );
        final highlighted =
            (hlLast && i == v.length - 1) || highlightIndex == i;
        final barColor = barColors != null && i < barColors!.length
            ? barColors![i]
            : highlighted
                ? kGold
                : color;
        final path = Path()..addRRect(r);
        c.drawShadow(path, barColor.withValues(alpha: .2), 5, false);
        c.drawRRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(barColor, Colors.white, .18)!,
                barColor,
              ],
            ).createShader(r.outerRect),
        );
      }
      if (every > 0 && (i % every == 0 || i == v.length - 1)) {
        final label =
            labels != null && i < labels!.length ? labels![i] : '${i + 1}';
        final isLatest =
            selected || (hlLast && i == v.length - 1) || highlightIndex == i;
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: labels == null ? 10 : 9,
              fontWeight: isLatest ? FontWeight.w700 : FontWeight.w400,
              color: selected
                  ? (barColors != null && i < barColors!.length
                      ? barColors![i]
                      : color)
                  : labelColor,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout();
        text.paint(
          c,
          Offset(x + (barWidth - text.width) / 2, h + 5),
        );
        if (valueLabels != null && i < valueLabels!.length) {
          final valueText = TextPainter(
            text: TextSpan(
              text: valueLabels![i],
              style: TextStyle(
                fontSize: 8,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (barColors != null && i < barColors!.length
                        ? barColors![i]
                        : color)
                    : labelColor,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            ellipsis: '…',
          )..layout(maxWidth: w - 2);
          valueText.paint(
            c,
            Offset(s.width - (i + .5) * w - valueText.width / 2, h + 18),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter o) =>
      o.v != v ||
      o.color != color ||
      o.hlLast != hlLast ||
      o.every != every ||
      o.gridColor != gridColor ||
      o.labelColor != labelColor ||
      o.progress != progress ||
      o.labels != labels ||
      o.valueLabels != valueLabels ||
      o.barColors != barColors ||
      o.selectedIndex != selectedIndex ||
      o.highlightIndex != highlightIndex ||
      o.selectionProgress != selectionProgress;
}

class LineChart extends StatelessWidget {
  final List<List<double>> series;
  final List<Color> colors;
  final double height;
  final bool mini;
  const LineChart(this.series,
      {super.key,
      this.colors = const [kPrimary2, Color(0xFFC7C7CC)],
      this.height = 200,
      this.mini = false});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: height,
      width: mini ? 90 : double.infinity,
      child: CustomPaint(
          painter: _LinePainter(
              series, colors, mini, context.p.muted, context.p.grid)));
}

class _LinePainter extends CustomPainter {
  final List<List<double>> series;
  final List<Color> colors;
  final bool mini;
  final Color labelColor, gridColor;
  _LinePainter(
      this.series, this.colors, this.mini, this.labelColor, this.gridColor);
  @override
  void paint(Canvas c, Size s) {
    final all = series.expand((e) => e).toList();
    if (all.isEmpty) return;
    final mx = all.reduce(max) * 1.1;
    final mn = mini ? all.reduce(min) * .9 : 0.0;
    final h = s.height - (mini ? 4 : 22);
    if (!mini) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var k = 0; k < 4; k++) {
        final y = 6 + k * (h - 6) / 3;
        c.drawLine(Offset(0, y), Offset(s.width, y), grid);
      }
    }
    for (var si = series.length - 1; si >= 0; si--) {
      final v = series[si];
      if (v.length < 2) continue;
      Offset pt(int i) => Offset(
          s.width - 6 - i * (s.width - 12) / (v.length - 1),
          h - (v[i] - mn) / (mx - mn) * (h - 8));
      final path = Path()..moveTo(pt(0).dx, pt(0).dy);
      for (var i = 1; i < v.length; i++) {
        path.lineTo(pt(i).dx, pt(i).dy);
      }
      final col = colors[si % colors.length];
      if (si == 0 && !mini) {
        final fill = Path.from(path)
          ..lineTo(pt(v.length - 1).dx, h)
          ..lineTo(pt(0).dx, h)
          ..close();
        c.drawPath(fill, Paint()..color = col.withValues(alpha: .12));
      }
      c.drawPath(
          path,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = si == 0 ? 3 : 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      if (si == 0) c.drawCircle(pt(v.length - 1), 4, Paint()..color = col);
      if (!mini && si == 0) {
        for (var i = 0; i < v.length; i += max(1, v.length ~/ 12)) {
          _text(c, '${i + 1}', Offset(pt(i).dx, h + 4), labelColor);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter o) =>
      o.series != series ||
      o.gridColor != gridColor ||
      o.labelColor != labelColor;
}
