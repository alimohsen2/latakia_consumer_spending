import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/store.dart';

/// بطاقة بحواف مستمرة (squircle) وظل ناعم كما في تطبيقات أبل.
/// عند تمرير [onTap] تتحول لبطاقة تفاعلية: ظل بارز وحدود مميزة عند التحويم
/// ومؤشر نقر، وتنفذ النقر عند الضغط.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.onTap});
  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final lifted = interactive && _hover;
    return MouseRegion(
      onEnter:
          interactive ? (_) => setState(() => _hover = true) : null,
      onExit:
          interactive ? (_) => setState(() => _hover = false) : null,
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: interactive ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0)
            ..multiply(Matrix4.diagonal3Values(
                lifted ? 1.015 : 1.0, lifted ? 1.015 : 1.0, 1.0)),
          transformAlignment: Alignment.center,
          padding: widget.padding,
          decoration: ShapeDecoration(
            color: lifted
                ? Color.alphaBlend(
                    kGold.withValues(alpha: .07), context.p.surface)
                : context.p.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: lifted
                    ? kGold.withValues(alpha: .9)
                    : context.p.border,
                width: lifted ? 1.6 : .5,
              ),
            ),
            shadows: [
              BoxShadow(
                color: lifted
                    ? kGold.withValues(
                        alpha: context.p.isDark ? .30 : .38)
                    : (context.p.isDark
                        ? const Color(0x33000000)
                        : const Color(0x0F000000)),
                blurRadius: lifted ? 28 : 10,
                offset: lifted ? const Offset(0, 14) : const Offset(0, 2),
              )
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// زر تبديل الوضع الفاتح/الداكن.
class ThemeToggle extends StatelessWidget {
  final bool compact;
  const ThemeToggle({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final dark = st.darkMode;
    final tip = dark ? 'الوضع الفاتح' : 'الوضع الداكن';
    return IconButton(
      tooltip: tip,
      onPressed: st.toggleDarkMode,
      icon: Icon(dark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
          size: compact ? 20 : 22),
    );
  }
}

/// صفحة قابلة للتمرير بعرض أقصى مريح ومسافات موحّدة.
class PageBody extends StatelessWidget {
  final List<Widget> children;

  /// خلفية اختيارية للصفحة (تُستخدم للوحة الرئيسية الزيتية).
  final Color? background;

  /// أقصى عرض للمحتوى؛ القيمة `double.infinity` تمدده لكامل الشاشة.
  final double contentMaxWidth;
  const PageBody(
      {super.key,
      required this.children,
      this.background,
      this.contentMaxWidth = 1240});
  @override
  Widget build(BuildContext context) {
    final l = <Widget>[];
    for (final c in children) {
      if (l.isNotEmpty) l.add(const SizedBox(height: 18));
      l.add(c);
    }
    final content = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: l),
        ),
      ),
    );
    return ColoredBox(color: background ?? context.p.bg, child: content);
  }
}

class BackBreadcrumb extends StatelessWidget {
  final String parent, current, fallbackLocation;
  const BackBreadcrumb({
    super.key,
    required this.parent,
    required this.current,
    required this.fallbackLocation,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        TextButton.icon(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallbackLocation);
            }
          },
          icon: const Icon(Icons.chevron_right, size: 22),
          label: const Text('رجوع'),
        ),
        const SizedBox(width: 4),
        Text(parent, style: TextStyle(color: context.p.muted, fontSize: 13)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child:
              Text('/', style: TextStyle(color: context.p.muted, fontSize: 13)),
        ),
        Flexible(
          child: Text(current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.p.muted, fontSize: 13)),
        ),
      ]);
}

/// عنوان كبير بأسلوب iOS Large Title.
class PageHeader extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  final Color? titleColor, subtitleColor;
  const PageHeader(this.title,
      {super.key,
      this.subtitle = '',
      this.actions = const [],
      this.titleColor,
      this.subtitleColor});
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: titleColor ?? context.p.text)),
            if (subtitle.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle,
                      style: TextStyle(
                          color: subtitleColor ?? context.p.muted,
                          fontSize: 14))),
          ]),
        ),
        const SizedBox(width: 12),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ]);
}

(Color, Color) badgeColors(String t) {
  const green = (Color(0xFFEDF3EF), Color(0xFF2F6B4A));
  const amber = (Color(0xFFFFF1D6), Color(0xFF8A5A00));
  const red = (Color(0xFFFDE7E9), Color(0xFFB3261E));
  const grey = (Color(0xFFEEEEF0), Color(0xFF48484A));
  if (['فعال', 'معتمد', 'مقفل', 'مقدّم', 'مفعّل', 'سليم', 'صحيح', 'مستقر']
      .contains(t)) {
    return green;
  }
  if (['نهائي', 'مغلق', 'ملغى', 'حرج', 'معطّل', 'غير مقدّم', 'يحتاج مراجعة']
      .any((k) => t.contains(k))) {
    return red;
  }
  if (['مؤقت', 'بانتظار', 'مسودة', 'متوسط', 'مرتفع', 'انخفاض']
      .any((k) => t.contains(k))) {
    return amber;
  }
  return grey;
}

class StatusBadge extends StatelessWidget {
  final String text;
  const StatusBadge(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = badgeColors(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: c.$1, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: c.$2, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

String sevLabel(String s) => s == 'critical'
    ? 'حرج'
    : s == 'high'
        ? 'مرتفع'
        : s == 'medium'
            ? 'متوسط'
            : s;

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool warn;
  const StatCard(this.label, this.value, this.icon,
      {super.key, this.warn = false});
  @override
  Widget build(BuildContext context) {
    final dark = context.p.isDark;
    final bg = warn
        ? (dark ? kGold.withValues(alpha: .18) : const Color(0xFFFFF5E6))
        : (dark
            ? Colors.white.withValues(alpha: .06)
            : const Color(0xFFF5F5F7));
    final fg = warn
        ? (dark ? const Color(0xFFD9B47A) : const Color(0xFF8A5A00))
        : (dark ? const Color(0xFFF2F2F4) : kPrimary);
    return AppCard(
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: context.p.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w700, height: 1.1)),
          ]),
        ),
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: fg, size: 22)),
      ]),
    );
  }
}

/// قائمة مجمّعة (Inset Grouped) بأعمدة مرنة وفواصل رفيعة.
class GridTable extends StatelessWidget {
  final List<String> heads;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final String empty;
  final double? minWidth;

  /// عند تمريرها تصبح الصفوف تفاعلية: تظليل عند التحويم والنقر هنا ينفذ
  /// [onRowTap] مع رقم الصف.
  final void Function(int index)? onRowTap;

  /// أرقام الأعمدة التي تُوسَّط عناوينها وخلاياها.
  final Set<int> centerColumns;
  const GridTable(
      {super.key,
      required this.heads,
      required this.rows,
      this.flex,
      this.minWidth,
      this.onRowTap,
      this.centerColumns = const {},
      this.empty = 'لا توجد بيانات'});
  @override
  Widget build(BuildContext context) {
    final f = flex ?? List.filled(heads.length, 1);
    final headerStyle = TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14.5,
        letterSpacing: .5,
        color: context.p.isDark
            ? const Color(0xFFBFE9DE)
            : const Color(0xFF17574E));
    final table = Column(children: [
      // رأس الجدول: شريط كريمي بلمسة ذهبية أسفله — مقروء وفخم
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: context.p.surfaceAlt
              .withValues(alpha: context.p.isDark ? .30 : .70),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(27)),
          border: Border(
            bottom: BorderSide(
                color: kGold.withValues(alpha: .55), width: 1.3),
          ),
        ),
        child: Row(children: [
          for (var i = 0; i < heads.length; i++)
            Expanded(
                flex: f[i],
                child: Text(heads[i],
                    textAlign: centerColumns.contains(i)
                        ? TextAlign.center
                        : TextAlign.start,
                    style: headerStyle))
        ]),
      ),
      if (rows.isEmpty)
        Padding(
            padding: const EdgeInsets.all(32),
            child: Text(empty, style: TextStyle(color: context.p.muted))),
      for (var n = 0; n < rows.length; n++) ...[
        _HoverRow(
          onTap: onRowTap == null ? null : () => onRowTap!(n),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              for (var i = 0; i < rows[n].length; i++)
                Expanded(
                    flex: f[i],
                    child: Align(
                        alignment: centerColumns.contains(i)
                            ? AlignmentDirectional.center
                            : AlignmentDirectional.centerStart,
                        child: rows[n][i]))
            ]),
          ),
        ),
        if (n < rows.length - 1)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
      ],
      const SizedBox(height: 4),
    ]);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: minWidth == null
            ? table
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: minWidth, child: table),
              ),
      ),
    );
  }
}

/// صف جدول تفاعلي: يُغلَّف بإطار ذهبي بسيط عند تحويم الفأرة، ومؤشر نقر، وينفذ [onTap].
class _HoverRow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverRow({required this.child, this.onTap});
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final active = enabled && _hover;
    const ease = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 260);
    final scale = active ? 1.015 : 1.0;
    final lift = active ? -4.0 : 0.0;
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: duration,
          curve: ease,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          transform: Matrix4.translationValues(0, lift, 0)
            ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
          transformAlignment: Alignment.center,
          // هامش 8 + حشوة 12 = 20 لتتوازى مع رأس الأعمدة
          decoration: BoxDecoration(
            color: active ? kGold.withValues(alpha: .10) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? kGold.withValues(alpha: .9)
                  : kGold.withValues(alpha: 0),
              width: 1.6,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

Widget cellText(String s, {bool bold = false}) => Text(s,
    style: TextStyle(
        fontSize: 14, fontWeight: bold ? FontWeight.w600 : FontWeight.w400));

/// مفتاح تبويب منزلق بأسلوب iOS Segmented Control.
class Seg extends StatelessWidget {
  final List<String> items;
  final int index;
  final void Function(int) onChanged;

  /// إن مُرّرت أيقونات، تُعرض الأيقونات بدل النصوص (وضع التبديل الأنيق).
  final List<IconData>? icons;
  const Seg(this.items, this.index, this.onChanged, {super.key, this.icons});
  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: index,
            backgroundColor: context.p.surfaceAlt,
            thumbColor: context.p.surface,
            children: {
              for (var i = 0; i < items.length; i++)
                i: Padding(
                    padding: icons != null
                        ? const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 7)
                        : const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                    child: icons != null
                        ? Tooltip(
                            message: items[i],
                            child: Icon(icons![i],
                                size: 18,
                                color: i == index
                                    ? kPrimary2
                                    : context.p.muted))
                        : Text(items[i],
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.p.text)))
            },
            onValueChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        width: 420,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))));

Future<String?> askText(BuildContext c, String title,
    {String label = 'السبب (إلزامي)',
    bool required = true,
    String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.p.surface,
      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(40)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
          width: 420,
          child: TextField(
              controller: ctl,
              maxLines: 3,
              decoration: InputDecoration(labelText: label))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (required && ctl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctl.text.trim());
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDialog(BuildContext c, String title, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.p.surface,
      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(40)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد')),
      ],
    ),
  );
  return r ?? false;
}

class Field extends StatelessWidget {
  final String label;
  final TextEditingController? ctl;
  final bool readOnly;
  final int flex;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? type;
  const Field(this.label,
      {super.key,
      this.ctl,
      this.readOnly = false,
      this.flex = 1,
      this.validator,
      this.onChanged,
      this.type});
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: TextFormField(
            controller: ctl,
            readOnly: readOnly,
            validator: validator,
            onChanged: onChanged,
            keyboardType: type,
            decoration: InputDecoration(
                labelText: label,
                fillColor: readOnly ? context.p.surfaceAlt : null)),
      );
}

Widget gap(double w) => SizedBox(width: w, height: w);

/// مجموعة بطاقات إحصائية تتكيّف مع عرض الشاشة: عمود واحد على الهاتف،
/// وعمودان/ثلاثة/أربعة أعمدة متساوية على العرض الكبير ليملأ المكان كله.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        const spacing = 12.0;
        final count = maxWidth >= 1100
            ? 4
            : maxWidth >= 820
                ? 3
                : maxWidth >= 540
                    ? 2
                    : 1;
        final itemWidth = (maxWidth - spacing * (count - 1)) / count;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      });
}

Widget rowOf(List<Widget> l, {double g = 12}) {
  final out = <Widget>[];
  for (final w in l) {
    if (out.isNotEmpty) out.add(SizedBox(width: g));
    out.add(w);
  }
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
}

/// قائمة منسدلة بسيطة. المفتاح الفارغ يعني «الكل».
class Drop extends StatelessWidget {
  final String label, value;
  final Map<String, String> items;
  final void Function(String) onChanged;
  final int flex;
  const Drop(this.label, this.value, this.items, this.onChanged,
      {super.key, this.flex = 1, this.enabled = true});
  final bool enabled;
  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            filled: true,
            fillColor: context.p.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: kPrimary2.withValues(alpha: .6),
                width: 1.5,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.containsKey(value) ? value : items.keys.first,
              isDense: true,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              items: items.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: enabled
                  ? (v) {
                      if (v != null) onChanged(v);
                    }
                  : null,
            ),
          ),
        ),
      );
}

Widget kv(String k, String v) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: context.p.muted, fontSize: 14)),
          Flexible(
              child: Text(v.isEmpty ? '—' : v,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500))),
        ]),
      ),
    );

/// بطاقة معلومة موحّدة: أيقونة + عنوان + قيمة، بخلفية وحدود متناسقة.
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  final int maxLines;
  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? kPrimary;
    final empty = value.trim().isEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: context.p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.p.border.withValues(alpha: .8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: context.p.isDark ? .22 : .06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                color.withValues(alpha: .22),
                color.withValues(alpha: .09),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.p.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                empty ? '—' : value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: empty ? context.p.muted : context.p.text,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// شبكة متجاوبة لبطاقات [InfoTile]: عمودان على العرض الواسع وعمود واحد على الضيق.
class InfoTileGrid extends StatelessWidget {
  final List<Widget> tiles;
  final double gap;
  final double breakpoint;
  const InfoTileGrid({
    super.key,
    required this.tiles,
    this.gap = 8,
    this.breakpoint = 520,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= breakpoint;
      if (!twoColumns) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
                child: tiles[i],
              ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i += 2)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tiles[i]),
                  SizedBox(width: gap),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}
