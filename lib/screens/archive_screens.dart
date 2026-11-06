import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/attachments_ui.dart';
import '../widgets/common.dart';
import 'pdf_service.dart';

DateTime? _parseDay(String s) {
  final t = s.trim().replaceAll('/', '-');
  if (t.isEmpty) return null;
  return DateTime.tryParse(t);
}

/// البحث في أرشيف المحاضر (المقفلة والمعتمدة والملغاة) مع فلاتر متقدمة.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final q = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  String status = '';
  String div = '';
  String att = 'all';
  String arch = 'all';

  List<Report> _filter(AppStore st) {
    final nq = normAr(q.text);
    final d1 = _parseDay(from.text);
    final d2 = _parseDay(to.text);
    return st.archiveReports().where((r) {
      final t = st.tp(r.taxpayerId);
      if (status.isNotEmpty && r.status != status) return false;
      if (div.isNotEmpty && r.division != div) return false;
      if (att == 'with' && r.attachments.isEmpty) return false;
      if (att == 'without' && r.attachments.isNotEmpty) return false;
      if (arch == 'archived' && !r.archived) return false;
      if (arch == 'unarchived' && r.archived) return false;
      if (d1 != null && r.date.isBefore(DateTime(d1.year, d1.month, d1.day))) {
        return false;
      }
      if (d2 != null &&
          r.date.isAfter(DateTime(d2.year, d2.month, d2.day, 23, 59, 59))) {
        return false;
      }
      if (nq.isEmpty) return true;
      final hay = normAr(
          '${r.serial} ${r.archiveRef} ${r.archiveBox} ${r.servedName} ${t?.name ?? ''} ${t?.taxNo ?? ''} ${r.inspectors}');
      return hay.contains(nq);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Widget _dd(String label, String value, Map<String, String> items,
          ValueChanged<String> onChanged) =>
      SizedBox(
        width: 190,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
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
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final all = st.archiveReports();
    final list = _filter(st);
    final archivedCount = all.where((r) => r.archived).length;
    final missing = all.where((r) => !r.hasArchiveLocation).length;
    final atts = all.fold<int>(0, (a, r) => a + r.attachments.length);
    return PageBody(children: [
      PageHeader('الأرشيف',
          subtitle: 'ملفات المحاضر المقفلة والمعتمدة والملغاة ومرفقاتها',
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                final rows = [
                      'الرقم\tالمنشأة\tالرقم الضريبي\tالتاريخ\tالحالة\tالشعبة\tالمرجع\tالصندوق\tعدد المرفقات\tقيمة الضبط'
                    ] +
                    list.map((r) {
                      final t = st.tp(r.taxpayerId);
                      return '${r.serial}\t${t?.name ?? ''}\t${t?.taxNo ?? ''}\t${fmtDate(r.date)}\t${r.status}\t${kDivisions[r.division] ?? ''}\t${r.archiveRef}\t${r.archiveBox}\t${r.attachments.length}\t${r.total}';
                    }).toList();
                await Clipboard.setData(ClipboardData(text: rows.join('\n')));
                if (context.mounted) {
                  toast(context, 'نُسخ فهرس الأرشيف. الصقه في Excel');
                }
              },
              icon: const Icon(CupertinoIcons.arrow_down_doc),
              label: const Text('تصدير الفهرس'),
            ),
          ]),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
            width: 270,
            child: StatCard('محاضر في الأرشيف', '${all.length}',
                CupertinoIcons.archivebox)),
        SizedBox(
            width: 270,
            child: StatCard(
                'مواقع أرشيف مسجّلة', '$archivedCount', CupertinoIcons.folder)),
        SizedBox(
            width: 270,
            child: StatCard('بانتظار تحديد الموقع', '$missing',
                CupertinoIcons.exclamationmark_triangle,
                warn: missing > 0)),
        SizedBox(
            width: 270,
            child:
                StatCard('مرفقات محفوظة', '$atts', CupertinoIcons.paperclip)),
      ]),
      AppCard(
        child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: q,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText:
                          'بحث: رقم المحضر، المنشأة، الرقم الضريبي، مرجع الملف',
                      prefixIcon: Icon(CupertinoIcons.search)),
                ),
              ),
              _dd(
                  'الحالة',
                  status,
                  {
                    '': 'الكل',
                    'مقفل': 'مقفل',
                    'معتمد': 'معتمد (قبل الطباعة)',
                    'ملغى': 'ملغى'
                  },
                  (v) => setState(() => status = v)),
              _dd(
                  'الشعبة',
                  div,
                  {
                    '': 'الكل',
                    ...kDivisionNames,
                  },
                  (v) => setState(() => div = v)),
              _dd(
                  'المرفقات',
                  att,
                  {'all': 'الكل', 'with': 'بمرفقات', 'without': 'بلا مرفقات'},
                  (v) => setState(() => att = v)),
              _dd(
                  'الموقع الأرشيفي',
                  arch,
                  {
                    'all': 'الكل',
                    'archived': 'مؤرشف',
                    'unarchived': 'غير مؤرشف'
                  },
                  (v) => setState(() => arch = v)),
              SizedBox(
                width: 165,
                child: TextField(
                    controller: from,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'من تاريخ', hintText: 'yyyy/mm/dd')),
              ),
              SizedBox(
                width: 165,
                child: TextField(
                    controller: to,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'إلى تاريخ', hintText: 'yyyy/mm/dd')),
              ),
              TextButton(
                onPressed: () => setState(() {
                  q.clear();
                  from.clear();
                  to.clear();
                  status = '';
                  div = '';
                  att = 'all';
                  arch = 'all';
                }),
                child: const Text('مسح الفلاتر'),
              ),
            ]),
      ),
      GridTable(
        heads: const [
          'الرقم',
          'المنشأة',
          'التاريخ',
          'الحالة',
          'المرجع',
          'الصندوق',
          'المرفقات',
          ''
        ],
        flex: const [1, 3, 2, 2, 2, 1, 1, 1],
        rows: [
          for (final r in list)
            [
              InkWell(
                  onTap: () => context.go('/archive/${r.id}'),
                  child:
                      cellText(r.serial.isEmpty ? '—' : r.serial, bold: true)),
              cellText(st.tp(r.taxpayerId)?.name ?? ''),
              cellText(fmtDate(r.date)),
              StatusBadge(r.status),
              cellText(r.archiveRef.isEmpty ? '—' : r.archiveRef),
              cellText(r.archiveBox.isEmpty ? '—' : r.archiveBox),
              cellText('${r.attachments.length}'),
              TextButton(
                  onPressed: () => context.go('/archive/${r.id}'),
                  child: const Text('فتح')),
            ],
        ],
        empty: 'لا توجد محاضر مطابقة. تظهر هنا المحاضر بعد اعتمادها أو قفلها.',
      ),
    ]);
  }
}

/// بطاقة الأرشيف: بيانات الموقع الورقي + المرفقات + إعادة الطباعة.
class ArchiveDetailScreen extends StatefulWidget {
  final String id;
  const ArchiveDetailScreen({super.key, required this.id});
  @override
  State<ArchiveDetailScreen> createState() => _ArchiveDetailScreenState();
}

class _ArchiveDetailScreenState extends State<ArchiveDetailScreen> {
  final ref = TextEditingController();
  final box = TextEditingController();
  final notes = TextEditingController();
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    final r = context.read<AppStore>().report(widget.id);
    if (r != null) {
      ref.text = r.archiveRef;
      box.text = r.archiveBox;
      notes.text = r.archiveNotes;
    }
    loaded = true;
  }

  Future<void> _printLabel(AppStore st, Report r) async {
    final t = st.tp(r.taxpayerId);
    final bytes = await buildArchiveLabelPdf(r, t, st.qrPayload(r));
    await printReportPdf(bytes, 'بطاقة-أرشيف-${r.serial}.pdf');
  }

  Future<void> _printCopy(AppStore st, Report r) async {
    final t = st.tp(r.taxpayerId);
    final bytes = await buildReportPdf(r, t);
    await printReportPdf(bytes, 'نسخة-محضر-${r.serial}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final r = st.report(widget.id);
    if (r == null) {
      return const Center(child: Text('المحضر غير موجود'));
    }
    final t = st.tp(r.taxpayerId);
    final canEdit = st.canArchiveEdit();
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'الأرشيف',
        current: 'محضر ${r.serial.isEmpty ? '—' : r.serial}',
        fallbackLocation: '/archive',
      ),
      PageHeader('بطاقة أرشيف: ${r.serial.isEmpty ? '—' : r.serial}',
          subtitle: t?.name ?? '',
          actions: [
            OutlinedButton.icon(
                onPressed: () => context.go('/reports/${r.id}'),
                icon: const Icon(CupertinoIcons.doc_text),
                label: const Text('عرض المحضر')),
            OutlinedButton.icon(
                onPressed: () => _printLabel(st, r),
                icon: const Icon(CupertinoIcons.printer),
                label: const Text('طباعة البطاقة')),
            if (st.can('reports.print'))
              OutlinedButton.icon(
                  onPressed: () => _printCopy(st, r),
                  icon: const Icon(CupertinoIcons.doc_on_doc),
                  label: const Text('طباعة نسخة')),
          ]),
      Row(children: [
        StatusBadge(r.status),
        const SizedBox(width: 10),
        if (r.archived)
          StatusBadge('مؤرشف · ${r.archivedBy}')
        else
          const StatusBadge('لم يُسجَّل موقعه'),
      ]),
      AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              kv('المنشأة', t?.name ?? ''),
              kv('الرقم الضريبي', t?.taxNo ?? ''),
              kv('التاريخ', fmtDT(r.date)),
              kv('قيمة الضبط', '${money(r.total)} ل.س'),
              kv('المفتشون', r.inspectors),
              kv('أنشأه', '${r.createdBy} · ${kDivisions[r.division] ?? ''}'),
              kv('عدد المخالفات', '${r.items.length}'),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Column(children: [
              kv('المرجع الأرشيفي', r.archiveRef),
              kv('رقم الصندوق', r.archiveBox),
              kv(
                  'تاريخ الأرشفة',
                  r.archivedAt.isEmpty
                      ? ''
                      : fmtDate(
                          DateTime.tryParse(r.archivedAt) ?? DateTime.now())),
              kv('أُرشف بواسطة', r.archivedBy),
              kv('المرفقات', '${r.attachments.length} ملف'),
              if (r.cancelReason != null && r.cancelReason!.isNotEmpty)
                kv('سبب الإلغاء', r.cancelReason!),
            ]),
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الموقع الأرشيفي الورقي',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              'سجّل رقم الملف/المرجع ورقم الصندوق ليُعرف مكان المحضر عند طلبه. هذه البيانات لا تُغيّر محتوى المحضر ولا بصمته.',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
          const SizedBox(height: 12),
          if (canEdit) ...[
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: 260,
                  child: TextField(
                      controller: ref,
                      decoration: const InputDecoration(
                          labelText: 'مرجع الملف / رقم الحافظة'))),
              SizedBox(
                  width: 220,
                  child: TextField(
                      controller: box,
                      decoration: const InputDecoration(
                          labelText: 'رقم الصندوق / الرف'))),
              SizedBox(
                  width: 420,
                  child: TextField(
                      controller: notes,
                      maxLines: 1,
                      decoration:
                          const InputDecoration(labelText: 'ملاحظات الأرشيف'))),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                onPressed: () {
                  st.setArchiveInfo(r,
                      ref: ref.text, box: box.text, notes: notes.text);
                  toast(context, 'حُفظ موقع الأرشيف');
                },
                icon: const Icon(CupertinoIcons.checkmark_alt),
                label: const Text('حفظ الموقع'),
              ),
              if (r.archived)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: kRed),
                  onPressed: () async {
                    if (await confirmDialog(context, 'إلغاء موقع الأرشيف',
                            'ستُمسح بيانات المرجع والصندوق. المتابعة؟') &&
                        context.mounted) {
                      st.clearArchiveInfo(r);
                      ref.clear();
                      box.clear();
                      notes.clear();
                      toast(context, 'أُلغي موقع الأرشيف');
                    }
                  },
                  child: const Text('إلغاء الموقع'),
                ),
            ]),
          ] else
            Text('لا تملك صلاحية تعديل الموقع الأرشيفي. تواصل مع أمين الأرشيف.',
                style: TextStyle(color: context.p.muted)),
        ]),
      ),
      AppCard(
        child: AttachmentList(
          items: r.attachments,
          canEdit: st.canArchiveAttach(),
          emptyText: 'أضف صور المخالفة أو الإشعار أو نسخة ممسوحة من المحضر',
          onAdd: () => addPickedFilesToReport(context, st, r),
          onDelete: (a) => st.removeReportAttachment(r, a),
        ),
      ),
    ]);
  }
}
