import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/store.dart';

/// بطاقة بحواف مستمرة (squircle) وظل ناعم كما في تطبيقات أبل.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: ShapeDecoration(
          color: context.p.surface,
          shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: context.p.border, width: .5)),
          shadows: [
            BoxShadow(
                color: context.p.isDark
                    ? const Color(0x33000000)
                    : const Color(0x0F000000),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );
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
  const PageBody({super.key, required this.children, this.background});
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
          constraints: const BoxConstraints(maxWidth: 1240),
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
  const GridTable(
      {super.key,
      required this.heads,
      required this.rows,
      this.flex,
      this.minWidth,
      this.empty = 'لا توجد بيانات'});
  @override
  Widget build(BuildContext context) {
    final f = flex ?? List.filled(heads.length, 1);
    final table = Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          for (var i = 0; i < heads.length; i++)
            Expanded(
                flex: f[i],
                child: Text(heads[i],
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: context.p.muted)))
        ]),
      ),
      const Divider(),
      if (rows.isEmpty)
        Padding(
            padding: const EdgeInsets.all(32),
            child: Text(empty, style: TextStyle(color: context.p.muted))),
      for (var n = 0; n < rows.length; n++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            for (var i = 0; i < rows[n].length; i++)
              Expanded(
                  flex: f[i],
                  child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: rows[n][i]))
          ]),
        ),
        if (n < rows.length - 1)
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20), child: Divider()),
      ],
      const SizedBox(height: 4),
    ]);

    return AppCard(
      padding: EdgeInsets.zero,
      child: minWidth == null
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: table),
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
  const Seg(this.items, this.index, this.onChanged, {super.key});
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text(items[i],
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
          decoration: InputDecoration(labelText: label, enabled: enabled),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.containsKey(value) ? value : items.keys.first,
              isDense: true,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
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
