import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

String pctText(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%';

Widget deltaText(double v) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(v >= 0 ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right, size: 16, color: v >= 0 ? kPrimary : kRed),
      const SizedBox(width: 4),
      Text(pctText(v), style: TextStyle(color: v >= 0 ? kPrimary : kRed, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);

/// لوحة مبيعات مكلف: يومي وشهري وسنوي. البيانات من واجهة الـ API.
class SalesPanel extends StatefulWidget {
  final Taxpayer taxpayer;
  const SalesPanel({super.key, required this.taxpayer});
  @override
  State<SalesPanel> createState() => _SalesPanelState();
}

class _SalesPanelState extends State<SalesPanel> {
  String view = 'monthly';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final s = st.salesOf(widget.taxpayer.id);
    if (s == null) return const AppCard(child: Text('جارٍ جلب بيانات المبيعات من الواجهة…'));
    final m = s.monthly;
    final dPrev = m[10] == 0 ? 0.0 : (m[11] - m[10]) / m[10] * 100;
    final dYear = s.prevYear[11] == 0 ? 0.0 : (m[11] - s.prevYear[11]) / s.prevYear[11] * 100;
    final ytd = m.fold<double>(0, (a, b) => a + b);
    final dec = st.declineOf(widget.taxpayer);
    Widget chart;
    String title;
    if (view == 'daily') {
      title = 'المبيعات اليومية (آخر 30 يوماً)';
      chart = BarChart(s.daily, labelEvery: 5, color: const Color(0xFF8E8E93));
    } else if (view == 'yearly') {
      title = 'المبيعات السنوية (آخر 5 سنوات)';
      chart = BarChart(s.yearly, height: 200);
    } else {
      title = 'المبيعات الشهرية: هذه السنة (أخضر) مقابل السنة الماضية (رمادي)';
      chart = LineChart([m, s.prevYear], colors: [dec != null ? kRed : kPrimary2, const Color(0xFFC7C7CC)]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (dec != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8E3E3), border: Border.all(color: const Color(0xFFE7B9B9)), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: kRed),
            const SizedBox(width: 10),
            Expanded(child: Text('انخفضت مبيعات هذا المكلف: ${pctText(dec.vsPrev)} عن الشهر السابق، ${pctText(dec.vsYear)} عن نفس الشهر من العام الماضي، ${pctText(dec.vs3)} عن متوسط 3 أشهر', style: const TextStyle(color: Color(0xFF6E1D1D)))),
            StatusBadge(sevLabel(dec.severity)),
          ]),
        ),
      Row(children: [
        Expanded(child: StatCard('مبيعات الشهر الحالي', m[11].toStringAsFixed(0), CupertinoIcons.chart_bar)),
        const SizedBox(width: 12),
        Expanded(child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مقارنة بالشهر السابق', style: TextStyle(color: context.p.muted, fontSize: 13)), const SizedBox(height: 8), deltaText(dPrev)]))),
        const SizedBox(width: 12),
        Expanded(child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مقارنة بالسنة الماضية', style: TextStyle(color: context.p.muted, fontSize: 13)), const SizedBox(height: 8), deltaText(dYear)]))),
        const SizedBox(width: 12),
        Expanded(child: StatCard('مبيعات 12 شهراً', ytd.toStringAsFixed(0), CupertinoIcons.calendar)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Seg(const ['يومي', 'شهري', 'سنوي'], const ['daily', 'monthly', 'yearly'].indexOf(view), (i) => setState(() => view = const ['daily', 'monthly', 'yearly'][i])),
        const Spacer(),
        Text('الوحدة: ألف ل.س (بيانات تجريبية)', style: TextStyle(color: context.p.muted, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10), chart])),
    ]);
  }
}

class SalesOverviewScreen extends StatefulWidget {
  const SalesOverviewScreen({super.key});
  @override
  State<SalesOverviewScreen> createState() => _SalesOverviewScreenState();
}

class _SalesOverviewScreenState extends State<SalesOverviewScreen> {
  final q = TextEditingController();
  String cat = '';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final list = st.searchTaxpayers(q: q.text, cat: cat).where((t) => st.sales.containsKey(t.id)).toList();
    final total = st.sales.values.fold<double>(0, (a, s) => a + s.monthly[11]);
    return PageBody(children: [
      PageHeader('مبيعات المكلفين', subtitle: 'بيانات المبيعات الواردة من واجهة الـ API', actions: [OutlinedButton.icon(onPressed: () async {
            st.sales.clear();
            await st.loadSales();
          }, icon: const Icon(CupertinoIcons.arrow_clockwise), label: const Text('مزامنة الآن'))]),
      Row(children: [
        Expanded(child: StatCard('إجمالي مبيعات الشهر', total.toStringAsFixed(0), CupertinoIcons.chart_bar)),
        const SizedBox(width: 12),
        Expanded(child: StatCard('مكلفون انخفضت مبيعاتهم', '${st.declines().length}', CupertinoIcons.arrow_down_right, warn: true)),
      ]),
      AppCard(child: rowOf([Expanded(flex: 3, child: TextField(controller: q, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'بحث بالاسم أو الرقم الضريبي', prefixIcon: Icon(CupertinoIcons.search)))), Drop('الفئة', cat, {'': 'الكل', for (final c in kCategories) c: c}, (v) => setState(() => cat = v))])),
      GridTable(
        heads: const ['المنشأة', 'الفئة', 'مبيعات الشهر', 'التغيّر عن الشهر السابق', 'آخر 12 شهراً', 'الحالة', ''],
        flex: const [3, 2, 2, 2, 2, 2, 1],
        rows: [
          for (final t in list)
            () {
              final s = st.sales[t.id]!;
              final d = st.declineOf(t);
              final dp = s.monthly[10] == 0 ? 0.0 : (s.monthly[11] - s.monthly[10]) / s.monthly[10] * 100;
              return [
                cellText(t.name, bold: true),
                cellText(t.category),
                cellText(s.monthly[11].toStringAsFixed(0)),
                deltaText(dp),
                LineChart([s.monthly], height: 26, mini: true, colors: [d != null ? kRed : kPrimary2]),
                d == null ? const StatusBadge('مستقر') : StatusBadge('انخفاض ${sevLabel(d.severity)}'),
                TextButton(onPressed: () => context.go('/analytics/${t.id}'), child: const Text('عرض')),
              ];
            }(),
        ],
      ),
    ]);
  }
}

class TaxpayerSalesScreen extends StatelessWidget {
  final String id;
  const TaxpayerSalesScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final t = st.tp(id);
    if (t == null) return const Center(child: Text('المكلف غير موجود'));
    final d = st.declineOf(t);
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'مبيعات المكلفين',
        current: t.name,
        fallbackLocation: '/analytics',
      ),
      PageHeader('مبيعات ${t.name}', subtitle: 'الرقم الضريبي ${t.taxNo} · ${t.category}', actions: [
        OutlinedButton(onPressed: () => context.go('/taxpayers/${t.id}'), child: const Text('ملف المكلف')),
        if (d != null)
          FilledButton.icon(
            onPressed: () async {
              final n = await askText(context, 'إرسال تنبيه الانخفاض', label: 'ملاحظة مرفقة (اختيارية)', required: false);
              if (n != null && context.mounted) {
                st.sendDeclineAlert(d, n);
                toast(context, 'أُرسل التنبيه إلى المستلمين الذين حددهم المدير');
              }
            },
            icon: const Icon(CupertinoIcons.paperplane),
            label: const Text('إرسال تنبيه'),
          ),
      ]),
      SalesPanel(taxpayer: t),
    ]);
  }
}

class DeclinesScreen extends StatefulWidget {
  const DeclinesScreen({super.key});
  @override
  State<DeclinesScreen> createState() => _DeclinesScreenState();
}

class _DeclinesScreenState extends State<DeclinesScreen> {
  String sev = '';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final all = st.declines();
    final list = all.where((d) => sev.isEmpty || d.severity == sev).toList();
    return PageBody(children: [
      const PageHeader('مكلفون انخفضت مبيعاتهم', subtitle: 'يُرصد تلقائياً من بيانات الـ API. تُضبط العتبات من الإعدادات، والمستلمون يحددهم المدير'),
      Row(children: [for (final s in const ['critical', 'high', 'medium']) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: StatusBadge('${sevLabel(s)}: ${all.where((d) => d.severity == s).length}'))]),
      AppCard(child: rowOf([Drop('الخطورة', sev, const {'': 'الكل', 'critical': 'حرج', 'high': 'مرتفع', 'medium': 'متوسط'}, (v) => setState(() => sev = v))])),
      GridTable(
        heads: const ['المنشأة', 'الفئة', 'عن الشهر السابق', 'عن السنة الماضية', 'عن متوسط 3 أشهر', 'آخر 12 شهراً', 'الخطورة', ''],
        flex: const [3, 2, 2, 2, 2, 2, 2, 3],
        rows: [
          for (final d in list)
            [
              cellText(d.t.name, bold: true),
              cellText(d.t.category),
              deltaText(d.vsPrev),
              deltaText(d.vsYear),
              deltaText(d.vs3),
              LineChart([st.sales[d.t.id]!.monthly], height: 26, mini: true, colors: const [kRed]),
              StatusBadge(sevLabel(d.severity)),
              Wrap(spacing: 4, children: [
                TextButton(onPressed: () => context.go('/analytics/${d.t.id}'), child: const Text('فتح')),
                TextButton(
                  onPressed: () async {
                    final n = await askText(context, 'إرسال تنبيه', label: 'ملاحظة مرفقة (اختيارية)', required: false);
                    if (n != null && context.mounted) {
                      st.sendDeclineAlert(d, n);
                      toast(context, 'أُرسل التنبيه');
                    }
                  },
                  child: const Text('إرسال تنبيه'),
                ),
              ]),
            ],
        ],
        empty: 'لا توجد انخفاضات مرصودة',
      ),
    ]);
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final list = st.alertsFor(st.me!);
    return PageBody(children: [
      const PageHeader('التنبيهات والمواعيد', subtitle: 'تصلك التنبيهات التي حدد المدير أنك مستلمها'),
      if (list.isEmpty) AppCard(child: Text('لا توجد تنبيهات', style: TextStyle(color: context.p.muted))),
      for (final a in list)
        AppCard(
          child: ListTile(
            leading: Icon(CupertinoIcons.bell_fill, color: a.severity == 'critical' || a.severity == 'high' ? kRed : kGold),
            title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${kAlertTypes[a.type] ?? a.type} · ${a.detail}'),
            trailing: StatusBadge(sevLabel(a.severity)),
            onTap: a.link == null ? null : () => context.go(a.link!),
          ),
        ),
    ]);
  }
}
