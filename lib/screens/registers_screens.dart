import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

const kCommittees = {
  '': 'غير محال',
  'القضائية': 'اللجنة القضائية',
  'تقدير البيانات': 'لجنة تقدير البيانات والإجراءات اللاحقة'
};

class ViolationsScreen extends StatelessWidget {
  const ViolationsScreen({super.key});

  Future<void> _edit(BuildContext context, AppStore st, Report r) async {
    final served = TextEditingController(text: r.servedDate),
        objNo = TextEditingController(text: r.objectionNo),
        objDate = TextEditingController(text: r.objectionDate);
    final refDate = TextEditingController(text: r.referralDate),
        refVal = TextEditingController(
            text: r.referralValue == 0 ? '' : '${r.referralValue}');
    var committee = r.committee;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('سجل المخالفات: محضر ${r.serial}'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              rowOf([
                Field('تاريخ التبليغ (yyyy/mm/dd)', ctl: served),
                Field('رقم الاعتراض', ctl: objNo),
                Field('تاريخ الاعتراض', ctl: objDate)
              ]),
              const SizedBox(height: 12),
              rowOf([
                Drop('الإحالة إلى', committee, kCommittees,
                    (v) => set(() => committee = v),
                    flex: 2),
                Field('تاريخ الإحالة', ctl: refDate),
                Field('قيمة الإحالة', ctl: refVal, type: TextInputType.number)
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'))
          ],
        ),
      ),
    );
    if (ok == true) {
      r.servedDate = served.text.trim();
      r.objectionNo = objNo.text.trim();
      r.objectionDate = objDate.text.trim();
      r.referralDate = refDate.text.trim();
      r.committee = committee;
      r.referralValue = num.tryParse(refVal.text) ?? 0;
      st.saveRegisterFields(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final list = st.reports
        .where((r) =>
            r.status == 'مقفل' || r.status == 'معتمد' || r.status == 'ملغى')
        .toList();
    return PageBody(children: [
      PageHeader('سجل مخالفات قانون الرسم',
          subtitle: 'يُملأ من المحاضر المعتمدة والمقفلة',
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final rows = [
                      'الرقم\tالمنشأة\tالمحضر\tالمخالفة\tالتبليغ\tالاعتراض\tالإحالة\tالغرامة'
                    ] +
                    list
                        .map((r) =>
                            '${r.serial}\t${st.tp(r.taxpayerId)?.name ?? ''}\t${fmtDate(r.date)}\t${r.items.map((e) => e.type).join('، ')}\t${r.servedDate}\t${r.objectionNo}\t${r.referralDate}\t${r.total}')
                        .toList();
                await Clipboard.setData(ClipboardData(text: rows.join('\n')));
                if (context.mounted) {
                  toast(context, 'نُسخ السجل. الصقه في Excel');
                }
              },
              icon: const Icon(CupertinoIcons.arrow_down_doc),
              label: const Text('تصدير'),
            ),
          ]),
      GridTable(
        heads: const [
          'الرقم',
          'المخالف / المنشأة',
          'المحضر وتاريخه',
          'المخالفة',
          'التبليغ',
          'الاعتراض',
          'الإحالة',
          'الغرامة',
          ''
        ],
        flex: const [1, 3, 2, 3, 2, 2, 2, 2, 2],
        rows: [
          for (final r in list)
            [
              InkWell(
                  onTap: () => context.go('/reports/${r.id}'),
                  child: cellText(r.serial, bold: true)),
              cellText(st.tp(r.taxpayerId)?.name ?? ''),
              cellText(fmtDate(r.date)),
              cellText(r.items.map((e) => e.type).join('، ')),
              cellText(r.servedDate),
              cellText(r.objectionNo),
              cellText(r.referralDate),
              cellText(money(r.total)),
              st.can('registers.edit') && r.status != 'ملغى'
                  ? TextButton(
                      onPressed: () => _edit(context, st, r),
                      child: const Text('تعديل'))
                  : (r.status == 'ملغى'
                      ? const StatusBadge('ملغى')
                      : const SizedBox()),
            ],
        ],
        empty: 'لا توجد مخالفات معتمدة بعد',
      ),
    ]);
  }
}

class FollowupScreen extends StatelessWidget {
  const FollowupScreen({super.key});

  static const _keys = {
    'judicialNo': 'رقم قرار القضائية',
    'judicialDate': 'تاريخه',
    'judicialContent': 'محتوى قرار القضائية',
    'estimationNo': 'رقم قرار تقدير البيانات',
    'estimationDate': 'تاريخه',
    'estimationContent': 'محتوى قرار تقدير البيانات',
    'feesRealized': 'الرسوم المحققة',
    'finesRealized': 'الغرامات المحققة',
    'receiptNo': 'رقم الإيصال',
    'notes': 'ملاحظات',
  };

  Future<void> _edit(BuildContext context, AppStore st, Report r) async {
    final f = st.followUpFor(r.id);
    final ctl = {
      for (final k in _keys.keys)
        k: TextEditingController(text: f.data[k] ?? '')
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سجل المتابعة: محضر ${r.serial}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(children: [
              for (final k in _keys.keys)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                        controller: ctl[k],
                        decoration: InputDecoration(labelText: _keys[k]))),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'))
        ],
      ),
    );
    if (ok == true) {
      for (final k in _keys.keys) {
        f.data[k] = ctl[k]!.text.trim();
      }
      st.saveFollowUp(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final list = st.reports
        .where((r) => r.referralDate.isNotEmpty && r.status != 'ملغى')
        .toList();
    return PageBody(children: [
      const PageHeader('سجل المتابعة',
          subtitle: 'قرارات اللجان والتحصيل للمخالفات المحالة'),
      GridTable(
        heads: const [
          'المحضر',
          'الإحالة',
          'القيمة',
          'قرار القضائية',
          'قرار تقدير البيانات',
          'رسوم',
          'غرامات',
          'مخالفات سابقة',
          ''
        ],
        flex: const [1, 2, 2, 3, 3, 2, 2, 2, 2],
        rows: [
          for (final r in list)
            () {
              final d = st.followUpFor(r.id).data;
              final prev = st.reports
                  .where((x) =>
                      x.taxpayerId == r.taxpayerId &&
                      x.date.isBefore(r.date) &&
                      x.status != 'ملغى')
                  .length;
              return [
                cellText(r.serial, bold: true),
                cellText(
                    '${r.referralDate}\n${kCommittees[r.committee] ?? ''}'),
                cellText(money(r.referralValue)),
                cellText(
                    '${d['judicialNo'] ?? ''} ${d['judicialDate'] ?? ''}\n${d['judicialContent'] ?? ''}'),
                cellText(
                    '${d['estimationNo'] ?? ''} ${d['estimationDate'] ?? ''}\n${d['estimationContent'] ?? ''}'),
                cellText(d['feesRealized'] ?? ''),
                cellText(d['finesRealized'] ?? ''),
                cellText('$prev'),
                st.can('registers.edit')
                    ? TextButton(
                        onPressed: () => _edit(context, st, r),
                        child: const Text('تعديل'))
                    : const SizedBox(),
              ];
            }(),
        ],
        empty: 'لا توجد مخالفات محالة للجان',
      ),
    ]);
  }
}

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});
  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  String ym = ymOf(DateTime.now());
  final q = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final now = DateTime.now();
    final months = {
      for (var i = 0; i < 12; i++)
        ymOf(DateTime(now.year, now.month - i, 1)):
            ymOf(DateTime(now.year, now.month - i, 1))
    };
    final list =
        st.searchTaxpayers(q: q.text).where((t) => t.status == 'فعال').toList();
    final done = list.where((t) => st.submitted(t.id, ym)).length;
    return PageBody(children: [
      PageHeader('البيانات الشهرية',
          subtitle:
              'سجّل من قدّم بيانه. المتوقفون لا يظهرون هنا ولا في تقرير غير المقدمين'),
      AppCard(
          child: rowOf([
        Drop('الشهر', ym, months, (v) => setState(() => ym = v)),
        Expanded(
            flex: 2,
            child: TextField(
                controller: q,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'بحث بالاسم أو الرقم الضريبي',
                    prefixIcon: Icon(CupertinoIcons.search))))
      ])),
      Row(children: [
        StatusBadge('مقدّم: $done'),
        const SizedBox(width: 8),
        StatusBadge('غير مقدّم: ${list.length - done}')
      ]),
      GridTable(
        heads: const [
          'المنشأة',
          'الرقم الضريبي',
          'الفئة',
          'تاريخ التقديم',
          'تم التقديم'
        ],
        flex: const [3, 2, 2, 2, 1],
        rows: [
          for (final t in list)
            [
              cellText(t.name, bold: true),
              cellText(t.taxNo),
              cellText(t.category),
              cellText(st.statements
                  .where((s) => s.taxId == t.id && s.ym == ym && s.submitted)
                  .map((s) => s.date)
                  .join()),
              Checkbox(
                  value: st.submitted(t.id, ym),
                  onChanged: (v) => st.setSubmitted(t.id, ym, v ?? false)),
            ],
        ],
      ),
    ]);
  }
}
