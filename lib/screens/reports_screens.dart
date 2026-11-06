import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
      final bytes = await buildReportPdf(r, st.tp(r.taxpayerId));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ReportPreviewDialog(
          serial: r.serial,
          bytes: bytes,
          allowPrinting: true,
        ),
      );
    } catch (error) {
      if (mounted) toast(context, 'تعذرت معاينة المحضر: $error');
    }
  }

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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: PageHeader('إنشاء محضر ضبط مخالفة',
                  subtitle: 'المرسوم التشريعي 11/2015'),
            ),
            if (saved.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, size: 14, color: kPrimary),
                  const SizedBox(width: 6),
                  Text('حُفظت المسودة تلقائياً · $saved',
                      style: const TextStyle(
                          color: kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
        if (r.returnNote != null && r.returnNote!.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
              child: Text('أُعيد للتعديل: ${r.returnNote}',
                  style: const TextStyle(color: kRed))),
        ],
        const SizedBox(height: 16),
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('بيانات المحضر',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: kRed)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('المنشأة',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                  onPressed: () => _pick(st),
                  icon: const Icon(CupertinoIcons.search),
                  label: Text(t == null ? 'اختيار المكلف' : 'تغيير المكلف'))
            ]),
            if (t != null) ...[
              kv('المنشأة', t.name),
              kv('العنوان', t.address),
              kv('المالك المسجل', t.owner),
              kv('المهنة', t.profession),
              kv('الحالة', t.status)
            ],
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('المخالفات المضبوطة',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                  onPressed: () => _addItem(st),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('إضافة مخالفة'))
            ]),
            if (r.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text('لم تُضف مخالفات بعد',
                      style: TextStyle(color: context.p.muted)),
                ),
              )
            else
              for (var i = 0; i < r.items.length; i++)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(r.items[i].type),
                    subtitle: Text(
                        'المادة: ${r.items[i].article.isEmpty ? '—' : r.items[i].article}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${money(r.items[i].fine)} ل.س'),
                      IconButton(
                          tooltip: 'حذف المخالفة',
                          icon: const Icon(CupertinoIcons.trash),
                          onPressed: () {
                            r.items.removeAt(i);
                            _touch();
                          })
                    ])),
            const Divider(),
            rowOf([
              Field('غرامة التأخير شهرياً %',
                  ctl: lateCtl,
                  type: TextInputType.number,
                  onChanged: (_) => _touch()),
              Expanded(
                  flex: 2,
                  child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text('قيمة الضبط: ${money(r.total)} ل.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16))))
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('التبليغ والضابطة',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            responsiveFieldRows([
              Field('المتبلغ', ctl: sName, onChanged: (_) => _touch()),
              Field('صفته', ctl: sCap, onChanged: (_) => _touch()),
              Field('اسم الأب', ctl: sFather, onChanged: (_) => _touch()),
              Field('اسم الأم', ctl: sMother, onChanged: (_) => _touch()),
              Field('الرقم الوطني', ctl: sNat, onChanged: (_) => _touch())
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('المراقبون',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _addInspector,
                icon: const Icon(CupertinoIcons.add),
                label: const Text('إضافة مراقب'),
              ),
            ]),
            for (var i = 0; i < inspectorControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
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
            const SizedBox(height: 12),
            responsiveFieldRows([
              Field('رئيس الشعبة الميدانية', ctl: fieldHead, readOnly: true)
            ]),
            const SizedBox(height: 12),
            responsiveFieldRows(
                [Field('رئيس دائرة الإنفاق الإستهلاكي', ctl: deptHead, readOnly: true)]),
          ]),
        ),
      ],
    );

    final summary = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('الملخص',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 12),
          kv('عدد المخالفات', '${r.items.length}'),
          kv('غرامة التأخير شهرياً', '${lateCtl.text}%'),
          const Divider(height: 20),
          kv('قيمة الضبط', '${money(r.total)} ل.س'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _preview(st),
            icon: const Icon(CupertinoIcons.printer),
            label: const Text('معاينة وطباعة'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _save(st, submit: false),
            icon: const Icon(CupertinoIcons.checkmark_alt),
            label: const Text('حفظ كمسودة'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _save(st, submit: true),
            child: const Text('إرسال للاعتماد'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.go('/reports'),
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
          if (constraints.maxWidth < 900) {
            return Column(children: [
              form,
              const SizedBox(height: 16),
              summary,
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: form),
            const SizedBox(width: 16),
            SizedBox(width: 270, child: summary),
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
      final bytes = await buildReportPdf(r, st.tp(r.taxpayerId));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ReportPreviewDialog(
          serial: r.serial,
          bytes: bytes,
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

class _ReportPreviewDialog extends StatelessWidget {
  final String serial;
  final Uint8List bytes;
  final bool allowPrinting;

  const _ReportPreviewDialog({
    required this.serial,
    required this.bytes,
    this.allowPrinting = false,
  });

  Future<void> _print(BuildContext context) async {
    try {
      await printReportPdf(bytes, 'محضر-$serial.pdf');
    } catch (error) {
      if (context.mounted) toast(context, 'تعذرت طباعة المحضر: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('معاينة المحضر $serial'),
            actions: [
              if (allowPrinting)
                IconButton(
                  tooltip: 'طباعة المحضر',
                  onPressed: () => _print(context),
                  icon: const Icon(CupertinoIcons.printer),
                ),
            ],
            leading: IconButton(
              tooltip: 'إغلاق المعاينة',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.xmark),
            ),
          ),
          body: PdfPreview.builder(
            build: (_) async => bytes,
            pdfFileName: 'محضر-$serial.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: allowPrinting,
            allowSharing: false,
            useActions: false,
            padding: EdgeInsets.zero,
            pagesBuilder: (context, pages) =>
                _ReportPdfPageViewer(pages: pages),
          ),
        ),
      );
}

class _ReportPdfPageViewer extends StatefulWidget {
  final List<PdfPreviewPageData> pages;

  const _ReportPdfPageViewer({required this.pages});

  @override
  State<_ReportPdfPageViewer> createState() => _ReportPdfPageViewerState();
}

class _ReportPdfPageViewerState extends State<_ReportPdfPageViewer> {
  final transformationController = TransformationController();
  int pageIndex = 0;
  double zoom = 1;
  Size viewportSize = Size.zero;

  static const minZoom = 0.75;
  static const maxZoom = 4.0;

  @override
  void didUpdateWidget(covariant _ReportPdfPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (pageIndex >= widget.pages.length) {
      pageIndex = widget.pages.isEmpty ? 0 : widget.pages.length - 1;
      _setZoom(1);
    }
  }

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }

  void _setZoom(double value) {
    zoom = value.clamp(minZoom, maxZoom).toDouble();
    final offsetX = viewportSize.width * (1 - zoom) / 2;
    final offsetY = viewportSize.height * (1 - zoom) / 2;
    transformationController.value = transformationController.value.clone()
      ..setIdentity()
      ..translateByDouble(offsetX, offsetY, 0, 1)
      ..scaleByDouble(zoom, zoom, 1, 1);
    setState(() {});
  }

  void _changePage(int delta) {
    final next = (pageIndex + delta).clamp(0, widget.pages.length - 1);
    if (next == pageIndex) return;
    pageIndex = next;
    _setZoom(1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'الصفحة السابقة',
                  onPressed: pageIndex > 0 ? () => _changePage(-1) : null,
                  icon: const Icon(CupertinoIcons.chevron_right),
                ),
                Text('${pageIndex + 1} / ${widget.pages.length}'),
                IconButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: pageIndex < widget.pages.length - 1
                      ? () => _changePage(1)
                      : null,
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'تصغير',
                  onPressed:
                      zoom > minZoom ? () => _setZoom(zoom - 0.25) : null,
                  icon: const Icon(Icons.zoom_out),
                ),
                SizedBox(
                  width: 140,
                  child: Slider(
                    min: minZoom,
                    max: maxZoom,
                    divisions: 13,
                    value: zoom,
                    label: '${(zoom * 100).round()}%',
                    onChanged: _setZoom,
                  ),
                ),
                IconButton(
                  tooltip: 'تكبير',
                  onPressed:
                      zoom < maxZoom ? () => _setZoom(zoom + 0.25) : null,
                  icon: const Icon(Icons.zoom_in),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(zoom * 100).round()}%',
                    textAlign: TextAlign.center,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _setZoom(1),
                  icon:
                      const Icon(CupertinoIcons.arrow_up_left_arrow_down_right),
                  label: const Text('ملاءمة الصفحة'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
              final page = widget.pages[pageIndex];
              final aspectRatio = page.aspectRatio;
              final maxWidth = constraints.maxWidth * 0.96;
              final maxHeight = constraints.maxHeight * 0.96;
              final pageWidth = maxWidth / maxHeight > aspectRatio
                  ? maxHeight * aspectRatio
                  : maxWidth;
              final pageHeight = pageWidth / aspectRatio;

              return ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: InteractiveViewer(
                    transformationController: transformationController,
                    minScale: minZoom,
                    maxScale: maxZoom,
                    boundaryMargin: const EdgeInsets.all(180),
                    child: SizedBox(
                      width: pageWidth,
                      height: pageHeight,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 14,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Image(
                          image: page.image,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
