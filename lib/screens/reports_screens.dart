import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/attachments_ui.dart';
import '../widgets/common.dart';
import 'pdf_service.dart';

const kReportStatuses = [
  'مسودة',
  'بانتظار رئيس الشعبة',
  'بانتظار رئيس الدائرة',
  'معتمد',
  'مقفل',
  'ملغى'
];

/// سطر وصفي قصير يظهر أعلى نافذة معاينة المحضر.
String _previewSubtitle(Report r, Taxpayer? t) {
  final name = t?.name.trim() ?? '';
  final division = kDivisions[r.division] ?? '';
  return [
    if (r.serial.trim().isNotEmpty) 'رقم المحضر ${r.serial.trim()}',
    if (name.isNotEmpty) name,
    if (division.isNotEmpty) division,
  ].join(' · ');
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final q = TextEditingController();
  String status = '';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final nq = normAr(q.text);
    final list = st.reports
        .where((r) =>
            (status.isEmpty || r.status == status) &&
            (nq.isEmpty ||
                normAr('${r.serial} ${st.tp(r.taxpayerId)?.name ?? ''}')
                    .contains(nq)))
        .toList();
    return PageBody(children: [
      PageHeader('المحاضر', subtitle: 'محاضر ضبط المخالفات', actions: [
        if (st.can('reports.create'))
          FilledButton.icon(
              onPressed: () => context.go('/reports/new'),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('إنشاء محضر جديد')),
      ]),
      AppCard(
          child: rowOf([
        Expanded(
            flex: 3,
            child: TextField(
                controller: q,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'بحث برقم المحضر أو اسم المنشأة',
                    prefixIcon: Icon(CupertinoIcons.search)))),
        Drop(
            'الحالة',
            status,
            {'': 'الكل', for (final s in kReportStatuses) s: s},
            (v) => setState(() => status = v))
      ])),
      GridTable(
        heads: const [
          'الرقم',
          'المنشأة',
          'التاريخ',
          'قيمة الضبط',
          'الحالة',
          ''
        ],
        flex: const [1, 3, 2, 2, 3, 1],
        rows: [
          for (final r in list)
            [
              cellText(r.serial.isEmpty ? '—' : r.serial, bold: true),
              cellText(st.tp(r.taxpayerId)?.name ?? ''),
              cellText(fmtDate(r.date)),
              cellText(money(r.total)),
              StatusBadge(r.status),
              TextButton(
                  onPressed: () => context.go('/reports/${r.id}'),
                  child: const Text('عرض'))
            ]
        ],
        empty: 'لا توجد محاضر',
      ),
    ]);
  }
}

class ReportFormScreen extends StatefulWidget {
  final String? id, taxpayerId;
  const ReportFormScreen({super.key, this.id, this.taxpayerId});
  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  late Report r;
  bool editable = true, dirty = false;
  String? err;
  String saved = '';
  Timer? timer;
  final serial = TextEditingController(),
      orderNo = TextEditingController(),
      orderDate = TextEditingController(),
      lateCtl = TextEditingController();
  final sName = TextEditingController(),
      sCap = TextEditingController(),
      sFather = TextEditingController(),
      sMother = TextEditingController(),
      sNat = TextEditingController();
  final inspectorControllers = <TextEditingController>[];
  final fieldHead = TextEditingController(), deptHead = TextEditingController();

  @override
  void initState() {
    super.initState();
    final st = context.read<AppStore>();
    final ex = widget.id == null ? null : st.report(widget.id!);
    if (ex != null) {
      r = ex;
      editable = ex.status == 'مسودة';
    } else {
      r = Report(
          id: newId(),
          serial: st.settings['serialMode'] == 'auto' ? st.nextSerial() : '',
          taxpayerId: widget.taxpayerId ?? '',
          date: DateTime.now(),
          createdBy: st.me?.name ?? '',
          division: st.me?.division ?? '',
          lateFeePct: (st.settings['lateFeePct'] as num));
    }
    serial.text = r.serial;
    orderNo.text = r.orderNo;
    orderDate.text = r.orderDate;
    lateCtl.text = '${r.lateFeePct}';
    sName.text = r.servedName;
    sCap.text = r.servedCapacity;
    sFather.text = r.servedFather;
    sMother.text = r.servedMother;
    sNat.text = r.servedNationalNo;
    final divisionHeads = st.users
        .where((user) =>
            user.active && user.role == 'fieldHead' && user.division == 'field')
        .toList();
    r.fieldHead = divisionHeads.isEmpty ? '' : divisionHeads.first.name;
    final departmentHeads = st.users
        .where((user) => user.active && user.role == 'deptHead')
        .toList();
    r.deptHead = departmentHeads.isEmpty ? '' : departmentHeads.first.name;
    inspectorControllers.addAll(
      r.inspectors
          .split(RegExp(r'[,،;\n]+'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .map((name) => TextEditingController(text: name)),
    );
    if (inspectorControllers.isEmpty) {
      inspectorControllers.add(TextEditingController());
    }
    fieldHead.text = r.fieldHead;
    deptHead.text = r.deptHead;
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _autosave());
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final controller in inspectorControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _collect() {
    r.serial = serial.text.trim();
    r.orderNo = orderNo.text.trim();
    r.orderDate = orderDate.text.trim();
    r.lateFeePct = num.tryParse(lateCtl.text) ?? 0;
    r.servedName = sName.text.trim();
    r.servedCapacity = sCap.text.trim();
    r.servedFather = sFather.text.trim();
    r.servedMother = sMother.text.trim();
    r.servedNationalNo = sNat.text.trim();
    r.inspectors = inspectorControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .join('، ');
    r.fieldHead = fieldHead.text.trim();
    r.deptHead = deptHead.text.trim();
  }

  Future<void> _addInspector() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مراقب'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.pop(ctx, value.trim());
            },
            decoration: const InputDecoration(labelText: 'اسم المراقب'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    inspectorControllers.add(TextEditingController(text: name));
    _touch();
  }

  void _removeInspector(int index) {
    if (index == 0) return;
    final controller = inspectorControllers.removeAt(index);
    controller.dispose();
    _touch();
  }

  /// حفظ تلقائي كمسودة كل بضع ثوانٍ عند وجود تغيير.
  void _autosave() {
    if (!mounted || !editable || !dirty) return;
    final st = context.read<AppStore>();
    _collect();
    if (r.taxpayerId.isEmpty ||
        st.validateSerial(r.serial, exceptId: r.id) != null) {
      return;
    }
    st.saveReport(r);
    dirty = false;
    setState(() => saved = fmtDT(DateTime.now()));
  }

  void _touch() {
    dirty = true;
    _collect();
    if (mounted) setState(() {});
  }

  Future<void> _pick(AppStore st) async {
    final q = TextEditingController();
    final t = await showDialog<Taxpayer>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final l = st.searchTaxpayers(q: q.text);
          return AlertDialog(
            title: const Text('اختيار المكلف'),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(children: [
                TextField(
                    controller: q,
                    onChanged: (_) => set(() {}),
                    decoration: const InputDecoration(
                        labelText: 'بحث بالاسم أو الرقم الضريبي',
                        prefixIcon: Icon(CupertinoIcons.search))),
                const SizedBox(height: 8),
                Expanded(
                    child: ListView(children: [
                  for (final t in l)
                    ListTile(
                        title: Text(t.name),
                        subtitle: Text('${t.category} · ${t.taxNo}'),
                        trailing: StatusBadge(t.status),
                        onTap: () => Navigator.pop(ctx, t))
                ])),
              ]),
            ),
          );
        },
      ),
    );
    if (t != null) {
      r.taxpayerId = t.id;
      _touch();
    }
  }

  Future<void> _addItem(AppStore st) async {
    final types = st.violationTypes;
    var sel = types.isEmpty ? '' : types.first['name'] as String;
    final art = TextEditingController();
    final fine = TextEditingController(
        text: types.isEmpty ? '' : '${types.first['fine']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('إضافة مخالفة'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Drop(
                    'نوع المخالفة',
                    sel,
                    {
                      for (final t in types)
                        t['name'] as String: t['name'] as String
                    },
                    (v) => set(() {
                          sel = v;
                          final m = types.firstWhere((t) => t['name'] == v);
                          art.text = '${m['article']}';
                          fine.text = '${m['fine']}';
                        }))
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Field('المادة من المرسوم', ctl: art),
                const SizedBox(width: 10),
                Field('الغرامة (ل.س)', ctl: fine, type: TextInputType.number)
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إضافة'))
          ],
        ),
      ),
    );
    if (ok == true && sel.isNotEmpty) {
      r.items.add(Violation(
          type: sel,
          article: art.text.trim(),
          fine: num.tryParse(fine.text) ?? 0));
      _touch();
    }
  }

  void _save(AppStore st, {required bool submit}) {
    _collect();
    final e = st.validateSerial(r.serial, exceptId: r.id);
    if (e != null) return setState(() => err = e);
    if (r.taxpayerId.isEmpty) return setState(() => err = 'اختر المكلف');
    if (submit && r.items.isEmpty) {
      return setState(() => err = 'أضف مخالفة واحدة على الأقل');
    }
    st.saveReport(r);
    if (submit) st.submit(r);
    context.go('/reports/${r.id}');
  }

  Future<void> _preview(AppStore st) async {
    _collect();
    try {
      final t = st.tp(r.taxpayerId);
      final bytes = await buildReportPdf(r, t);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ReportPreviewDialog(
          serial: r.serial,
          title: 'محضر ضبط مخالفة',
          subtitle: _previewSubtitle(r, t),
          bytes: bytes,
          allowPrinting: true,
        ),
      );
    } catch (error) {
      if (mounted) toast(context, 'تعذرت معاينة المحضر: $error');
    }
  }

  Widget _formSection({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Widget? action,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.p.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _emptyBlock({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: context.p.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.p.border),
      ),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: .08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: kPrimary, size: 26),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.p.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        action,
      ]),
    );
  }

  Widget _autosaveBadge() {
    final done = saved.isNotEmpty;
    final color = done ? kPrimary : kGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.clock,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          done ? 'حُفظت المسودة · $saved' : 'حفظ تلقائي كل 5 ثوانٍ',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }

  List<Widget> _progressChips() {
    final steps = [
      ('بيانات المحضر', serial.text.trim().isNotEmpty),
      ('المنشأة', r.taxpayerId.isNotEmpty),
      ('المخالفات', r.items.isNotEmpty),
      ('التبليغ', sName.text.trim().isNotEmpty),
    ];
    return [
      for (var i = 0; i < steps.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: steps[i].$2
                ? kPrimary.withValues(alpha: .1)
                : context.p.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: steps[i].$2
                  ? kPrimary.withValues(alpha: .35)
                  : context.p.border,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: steps[i].$2 ? kPrimary : context.p.border,
                shape: BoxShape.circle,
              ),
              child: steps[i].$2
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        color: context.p.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              steps[i].$1,
              style: TextStyle(
                fontSize: 11,
                color: steps[i].$2 ? kPrimary : context.p.muted,
                fontWeight: steps[i].$2 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ]),
        ),
    ];
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .65),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _signatoryCard(String role, String name, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.p.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.p.border),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: kPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(color: context.p.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? '—' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppStore>();
    final t = st.tp(r.taxpayerId);
    final auto = st.settings['serialMode'] == 'auto';
    final availableMonitors = st.users
        .where((user) =>
            user.active &&
            user.role == 'monitor' &&
            user.division == r.division)
        .map((user) => user.name)
        .toSet()
        .toList()
      ..sort();
    final divisionHeads = st.users
        .where((user) =>
            user.active && user.role == 'fieldHead' && user.division == 'field')
        .toList();
    final divisionHeadName =
        divisionHeads.isEmpty ? '' : divisionHeads.first.name;
    final departmentHeads = st.users
        .where((user) => user.active && user.role == 'deptHead')
        .toList();
    final departmentHeadName =
        departmentHeads.isEmpty ? '' : departmentHeads.first.name;
    if (r.fieldHead != divisionHeadName) {
      r.fieldHead = divisionHeadName;
      fieldHead.text = divisionHeadName;
      if (editable) dirty = true;
    }
    if (r.deptHead != departmentHeadName) {
      r.deptHead = departmentHeadName;
      deptHead.text = departmentHeadName;
      if (editable) dirty = true;
    }
    final backLocation = widget.id != null
        ? '/reports/${widget.id}'
        : widget.taxpayerId != null
            ? '/taxpayers/${widget.taxpayerId}'
            : '/reports';
    Widget responsiveFieldRows(List<Widget> fields) => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 640) return rowOf(fields);
            final rows = <Widget>[];
            for (var i = 0; i < fields.length; i += 2) {
              if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
              rows.add(rowOf(fields.skip(i).take(2).toList()));
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
          },
        );
    final today = DateUtils.dateOnly(DateTime.now());
    final orderDateOptions = List.generate(4, (index) {
      final date = today.subtract(Duration(days: index));
      final dayLabel = switch (index) {
        0 => 'اليوم',
        1 => 'أمس',
        _ => 'قبل $index أيام',
      };
      final formattedDate = fmtDate(date);
      return MapEntry(formattedDate, '$dayLabel · $formattedDate');
    });
    if (!editable) {
      return PageBody(children: [
        BackBreadcrumb(
          parent: 'المحاضر',
          current: 'محضر ${r.serial.isEmpty ? '—' : r.serial}',
          fallbackLocation: backLocation,
        ),
        const PageHeader('المحضر غير قابل للتعديل',
            subtitle:
                'يمكن تعديل المسودات فقط. التصحيح يكون بإلغاء المحضر وإنشاء بديل.'),
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
                onPressed: () => context.go('/reports/${r.id}'),
                child: const Text('عرض المحضر'))),
      ]);
    }
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                kPrimary.withValues(alpha: .1),
                context.p.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kPrimary.withValues(alpha: .18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: .25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.doc_text,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إنشاء محضر ضبط مخالفة',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المرسوم التشريعي 11/2015 · محضر ${r.serial.isEmpty ? 'جديد' : 'رقم ${r.serial}'}',
                          style: TextStyle(
                            color: context.p.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _autosaveBadge(),
                  ..._progressChips(),
                ],
              ),
            ],
          ),
        ),
        if (err != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kRed.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kRed.withValues(alpha: .25)),
            ),
            child: Row(children: [
              const Icon(CupertinoIcons.exclamationmark_circle_fill,
                  color: kRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  err!,
                  style: const TextStyle(
                    color: kRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
          ),
        ],
        if (r.returnNote != null && r.returnNote!.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Row(children: [
              const Icon(CupertinoIcons.arrow_uturn_left_circle,
                  color: kRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'أُعيد للتعديل: ${r.returnNote}',
                  style: const TextStyle(
                    color: kRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        _formSection(
          icon: CupertinoIcons.doc_text,
          color: kGold,
          title: 'بيانات المحضر',
          subtitle: 'الرقم والتاريخ والأمر الإداري',
          children: [
            responsiveFieldRows([
              Field(
                  auto ? 'الرقم التسلسلي (تلقائي)' : 'الرقم المطبوع على الورقة',
                  ctl: serial,
                  readOnly: auto,
                  onChanged: (_) => _touch()),
              Field('التاريخ والساعة',
                  ctl: TextEditingController(text: fmtDT(r.date)),
                  readOnly: true),
              Field('رقم الأمر الإداري',
                  ctl: orderNo, onChanged: (_) => _touch()),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'تاريخ الأمر'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: orderDateOptions
                              .any((option) => option.key == orderDate.text)
                          ? orderDate.text
                          : null,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('اختر التاريخ'),
                      items: [
                        for (final option in orderDateOptions)
                          DropdownMenuItem(
                              value: option.key, child: Text(option.value)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        orderDate.text = value;
                        _touch();
                      },
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        _formSection(
          icon: CupertinoIcons.briefcase,
          color: const Color(0xFF7FB8FF),
          title: 'المنشأة',
          subtitle: t == null
              ? 'لم يتم اختيار المكلف بعد'
              : 'بيانات المكلف المرتبط بالمحضر',
          action: OutlinedButton.icon(
            onPressed: () => _pick(st),
            icon: Icon(t == null
                ? CupertinoIcons.search
                : CupertinoIcons.arrow_2_circlepath),
            label: Text(t == null ? 'اختيار' : 'تغيير'),
          ),
          children: [
            if (t == null)
              _emptyBlock(
                icon: CupertinoIcons.briefcase,
                title: 'اختر المكلف',
                message: 'ابحث بالاسم أو الرقم الضريبي لربط المحضر بالمنشأة.',
                action: FilledButton.icon(
                  onPressed: () => _pick(st),
                  icon: const Icon(CupertinoIcons.search, size: 18),
                  label: const Text('اختيار المكلف'),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.p.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.p.border),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        const Color(0xFF7FB8FF).withValues(alpha: .18),
                    child: const Icon(CupertinoIcons.briefcase,
                        color: Color(0xFF2F6B4A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${t.category} · ${t.taxNo}',
                          style: TextStyle(
                            color: context.p.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(t.status),
                ]),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 4,
                children: [
                  SizedBox(
                    width: 250,
                    child: Column(children: [
                      kv('الرقم الضريبي', t.taxNo),
                      kv('العنوان', t.address),
                    ]),
                  ),
                  SizedBox(
                    width: 250,
                    child: Column(children: [
                      kv('المالك المسجل', t.owner),
                      kv('المهنة', t.profession),
                    ]),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _formSection(
          icon: CupertinoIcons.exclamationmark_triangle,
          color: kRed,
          title: 'المخالفات المضبوطة',
          subtitle: r.items.isEmpty
              ? 'أضف المخالفات المرصودة في المحضر'
              : '${r.items.length} مخالفة · ${money(r.total)} ل.س',
          action: OutlinedButton.icon(
            onPressed: () => _addItem(st),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('إضافة'),
          ),
          children: [
            if (r.items.isEmpty)
              _emptyBlock(
                icon: CupertinoIcons.exclamationmark_triangle,
                title: 'لم تُضف مخالفات بعد',
                message: 'اختر نوع المخالفة والمادة لتسجيل قيمة الضبط.',
                action: FilledButton.icon(
                  onPressed: () => _addItem(st),
                  icon: const Icon(CupertinoIcons.add, size: 18),
                  label: const Text('إضافة مخالفة'),
                ),
              )
            else
              for (var i = 0; i < r.items.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.p.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.p.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kRed.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: kRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.items[i].type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'المادة: ${r.items[i].article.isEmpty ? '—' : r.items[i].article}',
                            style: TextStyle(
                              color: context.p.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${money(r.items[i].fine)} ل.س',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            r.items.removeAt(i);
                            _touch();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              CupertinoIcons.trash,
                              size: 15,
                              color: kRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 12),
            responsiveFieldRows([
              Field('غرامة التأخير شهرياً %',
                  ctl: lateCtl,
                  type: TextInputType.number,
                  onChanged: (_) => _touch()),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kRed.withValues(alpha: .2)),
              ),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(CupertinoIcons.tag, size: 16, color: kRed),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'قيمة الضبط الإجمالية',
                    style: TextStyle(color: context.p.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${money(r.total)} ل.س',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _formSection(
          icon: CupertinoIcons.person_2,
          color: const Color(0xFF8B7FD1),
          title: 'التبليغ والضابطة',
          subtitle: 'بيانات المتبلغ والمراقبين والتوقيعات',
          children: [
            responsiveFieldRows([
              Field('المتبلغ', ctl: sName, onChanged: (_) => _touch()),
              Field('صفته', ctl: sCap, onChanged: (_) => _touch()),
              Field('اسم الأب', ctl: sFather, onChanged: (_) => _touch()),
              Field('اسم الأم', ctl: sMother, onChanged: (_) => _touch()),
              Field('الرقم الوطني', ctl: sNat, onChanged: (_) => _touch())
            ]),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(
                child: Text(
                  'المراقبون',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addInspector,
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: const Text('إضافة مراقب'),
              ),
            ]),
            if (inspectorControllers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'لم يُضف مراقبون بعد',
                  style: TextStyle(color: context.p.muted, fontSize: 12),
                ),
              )
            else
              for (var i = 0; i < inspectorControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7FD1).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Color(0xFF6C5FC0),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InputDecorator(
                        decoration:
                            InputDecoration(labelText: 'المراقب ${i + 1}'),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: availableMonitors
                                    .contains(inspectorControllers[i].text)
                                ? inspectorControllers[i].text
                                : null,
                            isDense: true,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(16),
                            hint: const Text('اختر المراقب'),
                            items: [
                              for (final name in availableMonitors)
                                DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              if (inspectorControllers[i].text.isNotEmpty &&
                                  !availableMonitors
                                      .contains(inspectorControllers[i].text))
                                DropdownMenuItem(
                                  value: inspectorControllers[i].text,
                                  child: Text(inspectorControllers[i].text),
                                ),
                            ],
                            onChanged: (name) {
                              if (name == null) return;
                              inspectorControllers[i].text = name;
                              _touch();
                            },
                          ),
                        ),
                      ),
                    ),
                    if (i > 0)
                      IconButton(
                        tooltip: 'حذف المراقب',
                        onPressed: () => _removeInspector(i),
                        icon: const Icon(CupertinoIcons.trash),
                      )
                    else
                      const SizedBox(width: 48),
                  ]),
                ),
            const SizedBox(height: 16),
            _signatoryCard(
              'رئيس الشعبة الميدانية',
              fieldHead.text,
              CupertinoIcons.person_crop_circle,
            ),
            const SizedBox(height: 8),
            _signatoryCard(
              'رئيس دائرة الإنفاق الإستهلاكي',
              deptHead.text,
              CupertinoIcons.person_crop_circle_fill,
            ),
          ],
        ),
      ],
    );

    final summary = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1B6157), Color(0xFF0C352F)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(CupertinoIcons.doc_text,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص المحضر',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    r.status,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قيمة الضبط الإجمالية',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${money(r.total)} ل.س',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 23,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('عدد المخالفات', '${r.items.length}'),
          _summaryRow('غرامة التأخير',
              lateCtl.text.trim().isEmpty ? '—' : '${lateCtl.text}%'),
          _summaryRow('المنشأة', t?.name ?? '—'),
          _summaryRow(
              'المتبلغ', sName.text.trim().isEmpty ? '—' : sName.text.trim()),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: .14), height: 1),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _preview(st),
            icon: const Icon(CupertinoIcons.printer, size: 18),
            label: const Text('معاينة وطباعة'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0C352F),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _save(st, submit: false),
            icon: const Icon(CupertinoIcons.checkmark_alt, size: 18),
            label: const Text('حفظ كمسودة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: .45)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _save(st, submit: true),
            icon: const Icon(CupertinoIcons.paperplane, size: 18),
            label: const Text('إرسال للاعتماد'),
            style: FilledButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: const Color(0xFF3A2C05),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            onPressed: () => context.go('/reports'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: .75),
            ),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المحاضر',
        current: 'محضر ${r.serial.isEmpty ? 'جديد' : r.serial}',
        fallbackLocation: backLocation,
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1024) {
            return Column(children: [
              form,
              const SizedBox(height: 16),
              summary,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: form),
            const SizedBox(width: 20),
            SizedBox(width: 300, child: summary),
          ]);
        },
      ),
    ]);
  }
}

class ReportViewScreen extends StatelessWidget {
  final String id;
  const ReportViewScreen({super.key, required this.id});

  Future<void> _preview(BuildContext context, AppStore st, Report r) async {
    try {
      final t = st.tp(r.taxpayerId);
      final bytes = await buildReportPdf(r, t);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ReportPreviewDialog(
          serial: r.serial,
          title: 'محضر ضبط مخالفة',
          subtitle: _previewSubtitle(r, t),
          bytes: bytes,
          allowPrinting: true,
        ),
      );
    } catch (error) {
      if (context.mounted) toast(context, 'تعذرت معاينة المحضر: $error');
    }
  }

  Future<void> _export(BuildContext context, AppStore st, Report r) async {
    try {
      final bytes = await buildReportPdf(r, st.tp(r.taxpayerId));
      final saved = await saveAttachmentFile('محضر-${r.serial}.pdf', bytes);
      if (saved && context.mounted) {
        toast(context, 'تم حفظ المحضر بصيغة PDF');
      }
    } catch (error) {
      if (context.mounted) toast(context, 'تعذر تصدير المحضر: $error');
    }
  }

  Future<void> _print(BuildContext context, AppStore st, Report r,
      {required bool lock}) async {
    final t = st.tp(r.taxpayerId);
    if (lock) st.lock(r);
    final bytes = await buildReportPdf(r, t);
    await printReportPdf(bytes, 'محضر-${r.serial}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final r = st.report(id);
    if (r == null) return const Center(child: Text('المحضر غير موجود'));
    final t = st.tp(r.taxpayerId);
    final me = st.me!;
    final sameDivision =
        !isDivisionHeadRole(me.role) || me.division == r.division;
    final actions = <Widget>[];
    if (r.status == 'مسودة' && st.can('reports.create')) {
      actions.add(OutlinedButton(
          onPressed: () => context.go('/reports/${r.id}/edit'),
          child: const Text('تعديل')));
    }
    if (st.can('reports.print')) {
      actions.add(OutlinedButton.icon(
        onPressed: () => _preview(context, st, r),
        icon: const Icon(CupertinoIcons.doc_text_search),
        label: const Text('معاينة المحضر'),
      ));
      actions.add(OutlinedButton.icon(
        onPressed: () => _export(context, st, r),
        icon: const Icon(CupertinoIcons.arrow_down_doc),
        label: const Text('تصدير PDF'),
      ));
    }
    if (r.status == 'بانتظار رئيس الشعبة' &&
        st.can('reports.approve') &&
        sameDivision) {
      actions.add(FilledButton(
          onPressed: () => st.approveDivision(r), child: const Text('اعتماد')));
      actions.add(OutlinedButton(
          onPressed: () async {
            final n = await askText(context, 'إرجاع المحضر للتعديل',
                label: 'ملاحظات الإرجاع (إلزامي)');
            if (n != null) st.sendBack(r, n);
          },
          child: const Text('إرجاع')));
    }
    if (r.status == 'بانتظار رئيس الدائرة' && st.can('reports.endorse')) {
      actions.add(FilledButton(
          onPressed: () => st.endorse(r), child: const Text('تصديق')));
      actions.add(OutlinedButton(
          onPressed: () async {
            final n = await askText(context, 'إرجاع المحضر للتعديل',
                label: 'ملاحظات الإرجاع (إلزامي)');
            if (n != null) st.sendBack(r, n);
          },
          child: const Text('إرجاع')));
    }
    if (r.status == 'معتمد' && st.can('reports.print')) {
      actions.add(FilledButton.icon(
        onPressed: () async {
          if (await confirmDialog(context, 'طباعة وقفل',
                  'سيُقفل المحضر بعد الطباعة ولا يمكن تعديله. المتابعة؟') &&
              context.mounted) {
            await _print(context, st, r, lock: true);
          }
        },
        icon: const Icon(CupertinoIcons.printer),
        label: const Text('طباعة وقفل'),
      ));
    }
    if (r.status == 'مقفل') {
      if (st.can('reports.print')) {
        actions.add(OutlinedButton.icon(
            onPressed: () => _print(context, st, r, lock: false),
            icon: const Icon(CupertinoIcons.printer),
            label: const Text('طباعة نسخة')));
      }
    }
    if ((r.status == 'مقفل' || r.status == 'معتمد') &&
        st.can('reports.cancel')) {
      actions.add(FilledButton(
        style: FilledButton.styleFrom(backgroundColor: kRed),
        onPressed: () async {
          final n = await askText(context, 'إلغاء المحضر',
              label: 'سبب الإلغاء (إلزامي). لن يُحذف المحضر.');
          if (n != null) st.cancel(r, n);
        },
        child: const Text('إلغاء المحضر'),
      ));
    }
    if (r.status == 'ملغى' && st.can('reports.create')) {
      actions.add(FilledButton(
        onPressed: () {
          final n = Report(
              id: newId(),
              serial:
                  st.settings['serialMode'] == 'auto' ? st.nextSerial() : '',
              taxpayerId: r.taxpayerId,
              date: DateTime.now(),
              createdBy: me.name,
              division: me.division,
              items: r.items
                  .map((e) =>
                      Violation(type: e.type, article: e.article, fine: e.fine))
                  .toList(),
              lateFeePct: r.lateFeePct,
              orderNo: r.orderNo,
              orderDate: r.orderDate,
              inspectors: r.inspectors,
              fieldHead: r.fieldHead,
              deptHead: r.deptHead);
          st.saveReport(n);
          context.go('/reports/${n.id}/edit');
        },
        child: const Text('إنشاء محضر بديل'),
      ));
    }
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المحاضر',
        current: t?.name ?? 'محضر ${r.serial.isEmpty ? '—' : r.serial}',
        fallbackLocation: '/reports',
      ),
      PageHeader('محضر ${r.serial.isEmpty ? '—' : r.serial}',
          subtitle: t?.name ?? '', actions: actions),
      Row(children: [
        StatusBadge(r.status),
        const SizedBox(width: 10),
        if (r.locked)
          Text('مقفل: لا تعديل. التصحيح بالإلغاء ثم بديل',
              style: TextStyle(color: context.p.muted, fontSize: 12))
      ]),
      if (r.status == 'ملغى')
        AppCard(
            child: Text('ملغى. السبب: ${r.cancelReason}',
                style: const TextStyle(color: kRed))),
      if (r.returnNote != null &&
          r.returnNote!.isNotEmpty &&
          r.status == 'مسودة')
        AppCard(child: Text('أُعيد للتعديل: ${r.returnNote}')),
      AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              kv('التاريخ والساعة', fmtDT(r.date)),
              kv('الأمر الإداري', '${r.orderNo} ${r.orderDate}'),
              kv('المنشأة', t?.name ?? ''),
              kv('العنوان', t?.address ?? ''),
              kv('المالك المسجل', t?.owner ?? ''),
              const Divider(),
              for (final i in r.items)
                kv('${i.type}  (المادة ${i.article.isEmpty ? '—' : i.article})',
                    money(i.fine)),
              kv('غرامة التأخير شهرياً', '${r.lateFeePct}%'),
              kv('قيمة الضبط', '${money(r.total)} ل.س'),
              const Divider(),
              kv('المتبلغ', '${r.servedName} (${r.servedCapacity})'),
              kv('الرقم الوطني', r.servedNationalNo),
              kv('المفتشون', r.inspectors),
              kv('رئيس دائرة الإنفاق الإستهلاكي', r.deptHead),
              kv('أنشأه', '${r.createdBy} · ${kDivisions[r.division] ?? ''}'),
            ]),
          ),
          if (r.locked) ...[
            const SizedBox(width: 20),
            Column(children: [
              QrImageView(data: st.qrPayload(r), size: 150),
              Text('رمز التحقق',
                  style: TextStyle(color: context.p.muted, fontSize: 12)),
              SelectableText(st.qrPayload(r),
                  style: const TextStyle(fontSize: 10)),
            ]),
          ],
        ]),
      ),
      AppCard(
        child: AttachmentList(
          items: r.attachments,
          canEdit: r.status != 'مقفل' &&
              r.status != 'ملغى' &&
              st.can('reports.create'),
          emptyText:
              'لا مرفقات. يمكن للمفتش إضافة صور المخالفة قبل الاعتماد، ويمكن للأرشيف بعد القفل.',
          onAdd: () => addPickedFilesToReport(context, st, r),
          onDelete: (a) => st.removeReportAttachment(r, a),
        ),
      ),
      if (r.locked)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/archive/${r.id}'),
            icon: const Icon(CupertinoIcons.archivebox),
            label: const Text('فتح في الأرشيف'),
          ),
        ),
    ]);
  }
}

// ألوان نافذة المعاينة: أخضر مزرق داكن مع لمسات ذهبية.
const _previewBg = Color(0xFF071714);
const _previewPanel = Color(0xFF0C221E);
const _previewText = Color(0xFFF2F7F5);
const _previewMuted = Color(0xFF9FB8B2);
const _previewGoldLight = Color(0xFFD8B97B);

enum _PreviewFitMode { page, width }

class _ReportPreviewDialog extends StatelessWidget {
  final String serial;
  final String title;
  final String subtitle;
  final Uint8List bytes;
  final bool allowPrinting;

  const _ReportPreviewDialog({
    required this.serial,
    required this.bytes,
    this.title = 'محضر ضبط مخالفة',
    this.subtitle = '',
    this.allowPrinting = false,
  });

  String get _fileName =>
      'محضر-${serial.trim().isEmpty ? 'بدون-رقم' : serial.trim()}.pdf';

  String get _displaySubtitle {
    if (subtitle.trim().isNotEmpty) return subtitle.trim();
    return serial.trim().isEmpty
        ? 'معاينة المحضر قبل الطباعة'
        : 'رقم المحضر ${serial.trim()}';
  }

  Future<void> _print(BuildContext context) async {
    try {
      await printReportPdf(bytes, _fileName);
    } catch (error) {
      if (context.mounted) toast(context, 'تعذرت طباعة المحضر: $error');
    }
  }

  Future<void> _save(BuildContext context) async {
    try {
      final saved = await saveAttachmentFile(_fileName, bytes);
      if (saved && context.mounted) toast(context, 'تم حفظ المحضر بصيغة PDF');
    } catch (error) {
      if (context.mounted) toast(context, 'تعذر حفظ المحضر: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog.fullscreen(
        backgroundColor: _previewBg,
        child: Scaffold(
          backgroundColor: _previewBg,
          body: SafeArea(
            child: Column(
              children: [
                _PreviewTopBar(
                  title: title,
                  subtitle: _displaySubtitle,
                  onClose: () => Navigator.of(context).pop(),
                  onSave: () => _save(context),
                  onPrint: allowPrinting ? () => _print(context) : null,
                ),
                Expanded(
                  child: PdfPreview.builder(
                    build: (_) async => bytes,
                    pdfFileName: _fileName,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: false,
                    allowSharing: false,
                    useActions: false,
                    canDebug: false,
                    padding: EdgeInsets.zero,
                    loadingWidget: const _PreviewLoading(),
                    onError: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'تعذر عرض المعاينة: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _previewMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    pagesBuilder: (context, pages) =>
                        _ReportPdfPageViewer(pages: pages),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final VoidCallback? onPrint;

  const _PreviewTopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onSave,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A241F), Color(0xFF145046)],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0x55A98545)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return Row(
            children: [
              _PreviewIconButton(
                icon: CupertinoIcons.xmark,
                tooltip: 'إغلاق المعاينة (Esc)',
                onTap: onClose,
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0x33A98545), Color(0x11A98545)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x88A98545)),
                ),
                child: const Icon(
                  CupertinoIcons.doc_text,
                  color: _previewGoldLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _previewText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _previewMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (compact) ...[
                _PreviewIconButton(
                  icon: CupertinoIcons.arrow_down_doc,
                  tooltip: 'حفظ نسخة PDF',
                  onTap: onSave,
                ),
                if (onPrint != null) ...[
                  const SizedBox(width: 6),
                  _PreviewIconButton(
                    icon: CupertinoIcons.printer,
                    tooltip: 'طباعة المحضر',
                    onTap: onPrint!,
                    highlight: true,
                  ),
                ],
              ] else ...[
                _PreviewTextButton(
                  icon: CupertinoIcons.arrow_down_doc,
                  label: 'حفظ PDF',
                  onTap: onSave,
                ),
                if (onPrint != null) ...[
                  const SizedBox(width: 8),
                  _PreviewPrimaryButton(
                    icon: CupertinoIcons.printer,
                    label: 'طباعة المحضر',
                    onTap: onPrint!,
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PreviewIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlight;

  const _PreviewIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlight
            ? kGold.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
            color: highlight
                ? kGold.withValues(alpha: .62)
                : Colors.white.withValues(alpha: .12),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 18,
              color: highlight ? _previewGoldLight : _previewText,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PreviewTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: Colors.white.withValues(alpha: .14)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: _previewText),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: _previewText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PreviewPrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kGold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF0B211D)),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0B211D),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _previewGoldLight,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'جارٍ تجهيز معاينة المحضر…',
            style: TextStyle(color: _previewMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ReportPdfPageViewer extends StatefulWidget {
  final List<PdfPreviewPageData> pages;

  const _ReportPdfPageViewer({required this.pages});

  @override
  State<_ReportPdfPageViewer> createState() => _ReportPdfPageViewerState();
}

class _ReportPdfPageViewerState extends State<_ReportPdfPageViewer> {
  final _transformation = TransformationController();
  final _focusNode = FocusNode(debugLabel: 'report-preview');
  int _pageIndex = 0;
  double _zoom = 1;
  Size _viewport = Size.zero;
  _PreviewFitMode _fitMode = _PreviewFitMode.page;
  bool _applyingZoom = false;

  static const double _minZoom = .4;
  static const double _maxZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransformation);
  }

  @override
  void didUpdateWidget(covariant _ReportPdfPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageIndex >= widget.pages.length) {
      _pageIndex = widget.pages.isEmpty ? 0 : widget.pages.length - 1;
      _scheduleReset();
    }
  }

  @override
  void dispose() {
    _transformation.removeListener(_onTransformation);
    _transformation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformation() {
    if (_applyingZoom) return;
    final scale = _transformation.value.getMaxScaleOnAxis();
    if ((scale - _zoom).abs() > .005 &&
        scale >= _minZoom &&
        scale <= _maxZoom) {
      setState(() => _zoom = scale);
    }
  }

  Size _baseSize(Size viewport, PdfPreviewPageData page) {
    final padding = viewport.width < 640 ? 18.0 : 34.0;
    final availableWidth = math.max(1.0, viewport.width - padding * 2);
    final availableHeight = math.max(1.0, viewport.height - padding * 2);
    final rawAspect = page.aspectRatio;
    final aspect = rawAspect.isFinite && rawAspect > 0 ? rawAspect : 1.0;
    double width;
    double height;
    if (_fitMode == _PreviewFitMode.page) {
      width = math.min(availableWidth, availableHeight * aspect);
      height = width / aspect;
    } else {
      width = availableWidth;
      height = width / aspect;
    }
    return Size(width, height);
  }

  Size _childSize(Size viewport, Size base) => Size(
        math.max(viewport.width, base.width),
        math.max(viewport.height, base.height),
      );

  void _applyZoom(double value) {
    if (widget.pages.isEmpty || _viewport == Size.zero) return;
    final z = value.clamp(_minZoom, _maxZoom).toDouble();
    final page = widget.pages[_pageIndex.clamp(0, widget.pages.length - 1)];
    final base = _baseSize(_viewport, page);
    final child = _childSize(_viewport, base);
    final dx = (_viewport.width - child.width * z) / 2;
    final dy = (_viewport.height - child.height * z) / 2;
    _applyingZoom = true;
    _transformation.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(z, z, 1, 1);
    _applyingZoom = false;
    setState(() => _zoom = z);
  }

  void _scheduleReset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyZoom(1);
    });
  }

  void _changePage(int delta) {
    if (widget.pages.length < 2) return;
    final next = (_pageIndex + delta).clamp(0, widget.pages.length - 1);
    if (next == _pageIndex) return;
    setState(() => _pageIndex = next);
    _scheduleReset();
  }

  void _setFitMode(_PreviewFitMode mode) {
    if (_fitMode == mode) {
      _scheduleReset();
      return;
    }
    setState(() => _fitMode = mode);
    _scheduleReset();
  }

  void _zoomBy(double delta) => _applyZoom(_zoom + delta);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character == '+' || character == '=') {
      _zoomBy(.2);
      return KeyEventResult.handled;
    }
    if (character == '-') {
      _zoomBy(-.2);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _setFitMode(_PreviewFitMode.page);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyW) {
      _setFitMode(_PreviewFitMode.width);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageDown) {
      _changePage(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageUp) {
      _changePage(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const _PreviewLoading();

    final index = _pageIndex.clamp(0, widget.pages.length - 1);
    final page = widget.pages[index];

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          _buildToolbar(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final changed = viewport != _viewport;
                _viewport = viewport;
                final base = _baseSize(viewport, page);
                final child = _childSize(viewport, base);
                if (changed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _applyZoom(_zoom);
                  });
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.35,
                          colors: [Color(0xFF123B34), _previewBg],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _transformation,
                        constrained: false,
                        minScale: _minZoom,
                        maxScale: _maxZoom,
                        boundaryMargin: const EdgeInsets.all(280),
                        child: SizedBox(
                          width: child.width,
                          height: child.height,
                          child: Center(
                            child: SizedBox(
                              width: base.width,
                              height: base.height,
                              child: _pageCard(page),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageCard(PdfPreviewPageData page) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kGold.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .55),
            blurRadius: 34,
            spreadRadius: 4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRect(
        child: Image(
          image: page.image,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final hasPages = widget.pages.length > 1;
    return Container(
      decoration: const BoxDecoration(
        color: _previewPanel,
        border: Border(
          bottom: BorderSide(color: Color(0x33A98545)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 780;
          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              if (hasPages) ...[
                _toolIcon(
                  icon: CupertinoIcons.chevron_right,
                  tooltip: 'الصفحة السابقة',
                  onTap: _pageIndex > 0 ? () => _changePage(-1) : null,
                ),
                _pill('${_pageIndex + 1} / ${widget.pages.length}'),
                _toolIcon(
                  icon: CupertinoIcons.chevron_left,
                  tooltip: 'الصفحة التالية',
                  onTap: _pageIndex < widget.pages.length - 1
                      ? () => _changePage(1)
                      : null,
                ),
                _toolDivider(),
              ],
              _toolIcon(
                icon: Icons.zoom_out,
                tooltip: 'تصغير (-)',
                onTap: _zoom > _minZoom ? () => _zoomBy(-.2) : null,
              ),
              SizedBox(
                width: compact ? 110 : 150,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kGold,
                    inactiveTrackColor: Colors.white.withValues(alpha: .14),
                    thumbColor: _previewGoldLight,
                    overlayColor: kGold.withValues(alpha: .18),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    min: _minZoom,
                    max: _maxZoom,
                    value: _zoom.clamp(_minZoom, _maxZoom),
                    onChanged: _applyZoom,
                  ),
                ),
              ),
              _toolIcon(
                icon: Icons.zoom_in,
                tooltip: 'تكبير (+)',
                onTap: _zoom < _maxZoom ? () => _zoomBy(.2) : null,
              ),
              _pill('${(_zoom * 100).round()}%'),
              _toolDivider(),
              _fitButton(
                icon: Icons.fit_screen,
                label: 'ملاءمة الصفحة',
                selected: _fitMode == _PreviewFitMode.page,
                compact: compact,
                onTap: () => _setFitMode(_PreviewFitMode.page),
              ),
              _fitButton(
                icon: Icons.swap_horiz,
                label: 'ملاءمة العرض',
                selected: _fitMode == _PreviewFitMode.width,
                compact: compact,
                onTap: () => _setFitMode(_PreviewFitMode.width),
              ),
              if (!compact) ...[
                _toolDivider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Esc إغلاق · + / - تكبير · 0 صفحة · W عرض',
                    style: TextStyle(color: _previewMuted, fontSize: 10.5),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 17,
              color: onTap == null
                  ? _previewMuted.withValues(alpha: .4)
                  : _previewText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _previewText,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _toolDivider() {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: Colors.white.withValues(alpha: .12),
    );
  }

  Widget _fitButton({
    required IconData icon,
    required String label,
    required bool selected,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: selected
            ? kGold.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected
                    ? kGold.withValues(alpha: .65)
                    : Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? _previewGoldLight : _previewText,
                ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? _previewGoldLight : _previewText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final me = st.me!;
    final list = st.reports.where((r) {
      if (r.status == 'بانتظار رئيس الشعبة') {
        return st.can('reports.approve') &&
            (!isDivisionHeadRole(me.role) || me.division == r.division);
      }
      if (r.status == 'بانتظار رئيس الدائرة') return st.can('reports.endorse');
      return false;
    }).toList();
    return PageBody(children: [
      const PageHeader('اعتماد المحاضر',
          subtitle:
              'المسار: مستخدم ← رئيس الشعبة المختصة ← رئيس دائرة الإنفاق الإستهلاكي ← طباعة وقفل'),
      GridTable(
        heads: const [
          'المحضر',
          'المنشأة',
          'أنشأه',
          'الشعبة',
          'قيمة الضبط',
          'المرحلة',
          ''
        ],
        flex: const [1, 3, 2, 2, 2, 3, 3],
        rows: [
          for (final r in list)
            [
              cellText(r.serial, bold: true),
              cellText(st.tp(r.taxpayerId)?.name ?? ''),
              cellText(r.createdBy),
              cellText(kDivisions[r.division] ?? ''),
              cellText(money(r.total)),
              StatusBadge(r.status),
              Wrap(spacing: 6, children: [
                TextButton(
                    onPressed: () => context.go('/reports/${r.id}'),
                    child: const Text('فتح')),
                FilledButton(
                    onPressed: () => r.status == 'بانتظار رئيس الشعبة'
                        ? st.approveDivision(r)
                        : st.endorse(r),
                    child: const Text('اعتماد'))
              ]),
            ],
        ],
        empty: 'لا توجد محاضر بانتظار اعتمادك',
      ),
    ]);
  }
}
