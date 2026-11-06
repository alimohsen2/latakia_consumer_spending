import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class ReportsCenterScreen extends StatefulWidget {
  const ReportsCenterScreen({super.key});
  @override
  State<ReportsCenterScreen> createState() => _ReportsCenterScreenState();
}

class _ReportsCenterScreenState extends State<ReportsCenterScreen> {
  int tab = 0;
  String ym = ymOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final now = DateTime.now();
    final months = {for (var i = 0; i < 12; i++) ymOf(DateTime(now.year, now.month - i, 1)): ymOf(DateTime(now.year, now.month - i, 1))};
    Widget body;
    if (tab == 0) {
      final l = st.nonSubmitters(ym);
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppCard(child: rowOf([Drop('الشهر', ym, months, (v) => setState(() => ym = v)), OutlinedButton.icon(
          onPressed: () async {
            final rows = ['المنشأة\tالفئة\tالرقم الضريبي'] + l.map((t) => '${t.name}\t${t.category}\t${t.taxNo}').toList();
            await Clipboard.setData(ClipboardData(text: rows.join('\n')));
            if (context.mounted) toast(context, 'نُسخ التقرير. الصقه في Excel');
          },
          icon: const Icon(CupertinoIcons.arrow_down_doc),
          label: const Text('تصدير'),
        )])),
        const SizedBox(height: 6),
        Text('يُستثنى المكلفون المتوقفون.', style: TextStyle(color: context.p.muted, fontSize: 12)),
        const SizedBox(height: 8),
        GridTable(heads: const ['المنشأة', 'الفئة', 'الرقم الضريبي', 'الحالة'], flex: const [3, 2, 2, 2], rows: [for (final t in l) [cellText(t.name, bold: true), cellText(t.category), cellText(t.taxNo), StatusBadge(t.status)]], empty: 'قدّم الجميع بياناتهم لهذا الشهر'),
      ]);
    } else {
      final cats = {for (final t in st.taxpayers) t.category};
      body = GridTable(
        heads: const ['الفئة', 'عدد المحاضر', 'عدد المخالفات', 'الغرامات المقررة', 'الغرامات المحققة'],
        flex: const [2, 2, 2, 2, 2],
        rows: [
          for (final c in cats)
            () {
              final rs = st.reports.where((r) => st.tp(r.taxpayerId)?.category == c && r.status != 'ملغى' && r.status != 'مسودة').toList();
              final fines = rs.fold<num>(0, (a, r) => a + r.total);
              final real = rs.fold<num>(0, (a, r) => a + (num.tryParse(st.followUpFor(r.id).data['finesRealized'] ?? '') ?? 0));
              return [cellText(c, bold: true), cellText('${rs.length}'), cellText('${rs.fold<int>(0, (a, r) => a + r.items.length)}'), cellText(money(fines)), cellText(money(real))];
            }(),
        ],
      );
    }
    return PageBody(children: [
      const PageHeader('التقارير'),
      Seg(const ['غير المقدمين للبيانات الشهرية', 'المخالفات حسب الفئة'], tab, (i) => setState(() => tab = i)),
      body,
    ]);
  }
}

/// صفحة التحقق من المحضر. لا تحتاج تسجيل دخول. تُلصق فيها قراءة رمز QR.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final ctl = TextEditingController();
  VerifyResult? res;
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من محضر'), leading: IconButton(icon: const Icon(CupertinoIcons.chevron_right), onPressed: () => context.go(st.loggedIn ? '/' : '/login'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('الصق محتوى رمز QR المطبوع على المحضر', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(controller: ctl, decoration: const InputDecoration(hintText: 'LTX1|…')),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => setState(() => res = st.verifyPayload(ctl.text)), child: const Text('تحقق')),
              if (res != null) ...[
                const SizedBox(height: 18),
                AppCard(
                  child: Column(children: [
                    Icon(res!.ok ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill, size: 56, color: res!.ok ? kPrimary : kRed),
                    const SizedBox(height: 8),
                    Text(res!.msg, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: res!.ok ? kPrimary : kRed)),
                    if (res!.report != null) ...[const Divider(), kv('رقم المحضر', res!.report!.serial), kv('التاريخ', fmtDate(res!.report!.date)), kv('الحالة', res!.report!.status)],
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Text('تظهر هنا بيانات التحقق فقط، دون تفاصيل المخالفة.', textAlign: TextAlign.center, style: TextStyle(color: context.p.muted, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
