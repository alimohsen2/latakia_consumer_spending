import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/util.dart';
import '../data/field_sync.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/attachments_ui.dart';
import '../widgets/common.dart';

const kFieldStatuses = ['مسودة', 'جاهز للمزامنة', 'مزامَن', 'فشل'];

/// قائمة المسودات الميدانية وحالة المزامنة. تعمل بلا إنترنت لأن كل شيء
/// يُحفظ محلياً أولاً.
class FieldHomeScreen extends StatefulWidget {
  const FieldHomeScreen({super.key});
  @override
  State<FieldHomeScreen> createState() => _FieldHomeScreenState();
}

class _FieldHomeScreenState extends State<FieldHomeScreen> {
  int tab = 0;

  Future<void> _syncAll(AppStore st) async {
    if (st.pendingFieldDrafts == 0) {
      toast(context, 'لا توجد مسودات جاهزة للمزامنة');
      return;
    }
    final ok = await st.syncAllField();
    if (!mounted) return;
    toast(
        context,
        ok == 0
            ? 'لم تنجح أي مزامنة. راجع سبب الفشل في البطاقات.'
            : 'تمت مزامنة $ok مسودة بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final all = st.fieldDrafts;
    final list = all.where((d) {
      if (tab == 0) return true;
      if (tab == 1) return d.status == 'مسودة';
      if (tab == 2) return d.ready || d.failed;
      return d.synced;
    }).toList();
    final drafts = all.where((d) => d.status == 'مسودة').length;
    final ready = all.where((d) => d.ready).length;
    final synced = all.where((d) => d.synced).length;
    final failed = all.where((d) => d.failed).length;
    final url = ((st.settings['fieldSyncUrl'] as String?) ?? '').trim();
    return PageBody(children: [
      PageHeader('المفتش الميداني',
          subtitle: 'أنشئ المحاضر في الميدان واحفظها بلا إنترنت ثم زامنها',
          actions: [
            if (st.can('field.create'))
              FilledButton.icon(
                  onPressed: () => context.go('/field/new'),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('محضر ميداني')),
            if (st.can('field.sync'))
              OutlinedButton.icon(
                onPressed: st.fieldSyncBusy ? null : () => _syncAll(st),
                icon: const Icon(CupertinoIcons.arrow_clockwise),
                label:
                    Text(st.fieldSyncBusy ? 'جارٍ المزامنة…' : 'مزامنة الكل'),
              ),
          ]),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E3E8)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(CupertinoIcons.bolt, color: kPrimary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  url.isEmpty
                      ? 'وضع المزامنة: محلي (عرض)'
                      : 'وضع المزامنة: خادم REST',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                url.isEmpty
                    ? 'كل مسودة تُحفظ على هذا الجهاز وتُحوَّل إلى محضر داخل النظام عند المزامنة. لربط خادم حقيقي اضبط «عنوان مزامنة الميدان» في الإعدادات.'
                    : 'تُرسل المسودات ومرفقاتها إلى $url/field/sync عند الضغط على مزامنة.',
                style: TextStyle(color: context.p.muted, fontSize: 12),
              ),
            ]),
          ),
        ]),
      ),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
            width: 240,
            child: StatCard('مسودات', '$drafts', CupertinoIcons.doc_text)),
        SizedBox(
            width: 240,
            child: StatCard(
                'جاهزة للمزامنة', '$ready', CupertinoIcons.arrow_up_doc,
                warn: ready > 0)),
        SizedBox(
            width: 240,
            child: StatCard(
                'مزامَنة', '$synced', CupertinoIcons.checkmark_circle)),
        SizedBox(
            width: 240,
            child: StatCard(
                'فشلت', '$failed', CupertinoIcons.exclamationmark_triangle,
                warn: failed > 0)),
      ]),
      Seg(const ['الكل', 'مسودات', 'بانتظار المزامنة', 'مزامَنة'], tab,
          (i) => setState(() => tab = i)),
      if (list.isEmpty)
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              Icon(CupertinoIcons.location, size: 44, color: context.p.muted),
              const SizedBox(height: 10),
              const Text('لا توجد مسودات ميدانية',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  'ابدأ بمحضر ميداني جديد. يُحفظ تلقائياً على الجهاز ويمكنك إكماله لاحقاً.',
                  style: TextStyle(color: context.p.muted, fontSize: 13)),
              const SizedBox(height: 12),
              if (st.can('field.create'))
                FilledButton(
                    onPressed: () => context.go('/field/new'),
                    child: const Text('محضر ميداني جديد')),
            ]),
          ),
        )
      else
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              _DraftTile(
                  d: list[i],
                  st: st,
                  onSync: () => _syncOne(st, list[i]),
                  onDelete: () => _delete(st, list[i])),
              if (i < list.length - 1) const Divider(),
            ],
          ]),
        ),
    ]);
  }

  Future<void> _syncOne(AppStore st, FieldDraft d) async {
    final out = await st.syncFieldDraft(d);
    if (!mounted) return;
    toast(context, out.message);
  }

  Future<void> _delete(AppStore st, FieldDraft d) async {
    if (!await confirmDialog(context, 'حذف مسودة',
        'ستُحذف المسودة ومرفقاتها من هذا الجهاز. المتابعة؟')) {
      return;
    }
    await st.deleteFieldDraft(d);
    if (!mounted) return;
    toast(context, 'حُذفت المسودة');
  }
}

class _DraftTile extends StatelessWidget {
  final FieldDraft d;
  final AppStore st;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  const _DraftTile(
      {required this.d,
      required this.st,
      required this.onSync,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title =
        d.taxpayerName.trim().isEmpty ? 'مسودة بلا اسم' : d.taxpayerName;
    final sub = [
      d.taxNo.isEmpty ? '' : 'رقم ضريبي ${d.taxNo}',
      d.serial.isEmpty ? '' : 'محضر ${d.serial}',
      '${d.items.length} مخالفة',
      '${d.attachments.length} مرفق',
      if (d.location.isNotEmpty) d.location,
      if (d.updatedAt.isNotEmpty)
        'آخر تعديل ${d.updatedAt.substring(0, d.updatedAt.length >= 16 ? 16 : d.updatedAt.length).replaceAll('T', ' ')}',
    ].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15))),
              const SizedBox(width: 8),
              StatusBadge(d.status),
            ]),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(color: context.p.muted, fontSize: 12)),
            if (d.failed && d.lastError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('سبب الفشل: ${d.lastError}',
                    style: const TextStyle(color: kRed, fontSize: 12)),
              ),
            if (d.synced && d.lastError.isEmpty)
              Text('أُنشئ المحضر ${d.serial} في النظام',
                  style: const TextStyle(color: kPrimary, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 12),
        Wrap(spacing: 4, children: [
          TextButton(
              onPressed: () => context.go('/field/${d.id}'),
              child: Text(d.synced ? 'عرض' : 'فتح')),
          if (!d.synced && st.can('field.sync'))
            FilledButton(
                onPressed: st.fieldSyncBusy ? null : onSync,
                child: Text(d.failed ? 'إعادة' : 'مزامنة')),
          if (d.synced &&
              d.serverReportId.isNotEmpty &&
              st.report(d.serverReportId) != null)
            OutlinedButton(
                onPressed: () => context.go('/reports/${d.serverReportId}'),
                child: const Text('المحضر')),
          if (!d.synced)
            IconButton(
                tooltip: 'حذف',
                onPressed: onDelete,
                icon: const Icon(CupertinoIcons.trash, color: kRed, size: 20)),
        ]),
      ]),
    );
  }
}

/// محرر المسودة الميدانية: بيانات المنشأة، المخالفات، الموقع، والمرفقات.
class FieldDraftEditorScreen extends StatefulWidget {
  final String? id;
  const FieldDraftEditorScreen({super.key, this.id});
  @override
  State<FieldDraftEditorScreen> createState() => _FieldDraftEditorScreenState();
}

class _FieldDraftEditorScreenState extends State<FieldDraftEditorScreen> {
  late FieldDraft d;
  final name = TextEditingController();
  final taxNo = TextEditingController();
  final address = TextEditingController();
  final profession = TextEditingController();
  final serial = TextEditingController();
  final orderNo = TextEditingController();
  final orderDate = TextEditingController();
  final servedName = TextEditingController();
  final servedCapacity = TextEditingController();
  final servedNat = TextEditingController();
  final inspectors = TextEditingController();
  final fieldHead = TextEditingController();
  final location = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  final notes = TextEditingController();
  String? err;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppStore>();
    final ex = widget.id == null ? null : st.fieldDraft(widget.id!);
    if (ex != null) {
      d = ex;
    } else {
      final now = DateTime.now().toIso8601String();
      d = FieldDraft(
        id: newId(),
        inspectorName: st.me?.name ?? '',
        division: st.me?.division ?? 'field',
        inspectors: st.me?.name ?? '',
        createdAt: now,
        updatedAt: now,
      );
    }
    name.text = d.taxpayerName;
    taxNo.text = d.taxNo;
    address.text = d.address;
    profession.text = d.profession;
    serial.text = d.serial;
    orderNo.text = d.orderNo;
    orderDate.text = d.orderDate;
    servedName.text = d.servedName;
    servedCapacity.text = d.servedCapacity;
    servedNat.text = d.servedNationalNo;
    inspectors.text = d.inspectors;
    fieldHead.text = d.fieldHead;
    location.text = d.location;
    lat.text = d.lat;
    lng.text = d.lng;
    notes.text = d.notes;
  }

  void _collect() {
    d.taxpayerName = name.text.trim();
    d.taxNo = taxNo.text.trim();
    d.address = address.text.trim();
    d.profession = profession.text.trim();
    d.serial = serial.text.trim();
    d.orderNo = orderNo.text.trim();
    d.orderDate = orderDate.text.trim();
    d.servedName = servedName.text.trim();
    d.servedCapacity = servedCapacity.text.trim();
    d.servedNationalNo = servedNat.text.trim();
    d.inspectors = inspectors.text.trim();
    d.fieldHead = fieldHead.text.trim();
    d.location = location.text.trim();
    d.lat = lat.text.trim();
    d.lng = lng.text.trim();
    d.notes = notes.text.trim();
  }

  Future<void> _save(AppStore st, {required bool finish}) async {
    _collect();
    if (finish && d.taxpayerName.isEmpty) {
      setState(() => err = 'اكتب اسم المنشأة أو اختر مكلفاً من القائمة');
      return;
    }
    if (finish && d.items.isEmpty) {
      setState(() => err = 'أضف مخالفة واحدة على الأقل قبل المزامنة');
      return;
    }
    setState(() => err = null);
    if (finish) {
      d.status = 'جاهز للمزامنة';
      d.lastError = '';
    }
    st.saveFieldDraft(d);
    if (!finish) {
      toast(context, 'حُفظت المسودة على هذا الجهاز');
      return;
    }
    final out = await st.syncFieldDraft(d);
    if (!mounted) return;
    if (out.ok) {
      toast(context, out.message);
      context.go('/field');
    } else {
      setState(() => err = out.message);
    }
  }

  Future<void> _pickTaxpayer(AppStore st) async {
    final q = TextEditingController();
    final t = await showDialog<Taxpayer>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final l = st.searchTaxpayers(q: q.text);
          return AlertDialog(
            title: const Text('اختيار مكلف من القائمة المحلية'),
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
                  child: l.isEmpty
                      ? Center(
                          child: Text(
                              'لا نتائج. أدخل المنشأة يدوياً إن لم تكن مسجلة.',
                              style: TextStyle(color: context.p.muted)))
                      : ListView(children: [
                          for (final x in l)
                            ListTile(
                                title: Text(x.name),
                                subtitle: Text('${x.category} · ${x.taxNo}'),
                                trailing: StatusBadge(x.status),
                                onTap: () => Navigator.pop(ctx, x)),
                        ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (t == null || !mounted) return;
    setState(() {
      d.taxpayerId = t.id;
      d.taxpayerName = t.name;
      d.taxNo = t.taxNo;
      d.address = t.address;
      d.profession = t.profession;
      name.text = t.name;
      taxNo.text = t.taxNo;
      address.text = t.address;
      profession.text = t.profession;
    });
  }

  Future<void> _addItem(AppStore st) async {
    final types = st.violationTypes;
    var sel = types.isEmpty ? '' : types.first['name'] as String;
    final art = TextEditingController(
        text: types.isEmpty ? '' : '${types.first['article']}');
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
              if (types.isEmpty)
                const Text('لا توجد أنواع مخالفات معرّفة. أضفها من الإعدادات.',
                    style: TextStyle(color: kRed))
              else
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
                          })),
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
                child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true && sel.isNotEmpty) {
      setState(() {
        d.items.add(Violation(
            type: sel,
            article: art.text.trim(),
            fine: num.tryParse(fine.text) ?? 0));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    if (d.synced) return _readOnly(context, st);
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المفتش الميداني',
        current: 'محضر ميداني',
        fallbackLocation: '/field',
      ),
      PageHeader('محضر ميداني',
          subtitle: 'يُحفظ محلياً أولاً. لا تحتاج اتصالاً حتى تُنهي وتزامن.',
          actions: [
            OutlinedButton(
                onPressed: () => _save(st, finish: false),
                child: const Text('حفظ مسودة')),
            if (st.can('field.sync'))
              FilledButton.icon(
                  onPressed:
                      st.fieldSyncBusy ? null : () => _save(st, finish: true),
                  icon: const Icon(CupertinoIcons.arrow_up_doc),
                  label: const Text('إنهاء ومزامنة')),
          ]),
      if (err != null)
        AppCard(child: Text(err!, style: const TextStyle(color: kRed))),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('المنشأة',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            OutlinedButton.icon(
                onPressed: () => _pickTaxpayer(st),
                icon: const Icon(CupertinoIcons.search),
                label: const Text('اختيار من القائمة')),
          ]),
          const SizedBox(height: 4),
          Text(
              'إن لم تكن المنشأة مسجلة، أدخل بياناتها يدوياً. تُنشأ تلقائياً عند المزامنة.',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 320,
                child: TextField(
                    controller: name,
                    onChanged: (_) => d.taxpayerId = '',
                    decoration:
                        const InputDecoration(labelText: 'اسم المنشأة *'))),
            SizedBox(
                width: 200,
                child: TextField(
                    controller: taxNo,
                    onChanged: (_) => d.taxpayerId = '',
                    decoration:
                        const InputDecoration(labelText: 'الرقم الضريبي'))),
            SizedBox(
                width: 300,
                child: TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'العنوان'))),
            SizedBox(
                width: 220,
                child: TextField(
                    controller: profession,
                    decoration:
                        const InputDecoration(labelText: 'المهنة/النشاط'))),
          ]),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('بيانات الضبط',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 200,
                child: TextField(
                    controller: serial,
                    decoration: const InputDecoration(
                        labelText: 'رقم المحضر (إن وُجد)'))),
            SizedBox(
                width: 200,
                child: TextField(
                    controller: orderNo,
                    decoration:
                        const InputDecoration(labelText: 'رقم الأمر الإداري'))),
            SizedBox(
                width: 180,
                child: TextField(
                    controller: orderDate,
                    decoration:
                        const InputDecoration(labelText: 'تاريخ الأمر'))),
            SizedBox(
                width: 240,
                child: TextField(
                    controller: inspectors,
                    decoration:
                        const InputDecoration(labelText: 'أسماء المفتشين'))),
            SizedBox(
                width: 240,
                child: TextField(
                    controller: fieldHead,
                    decoration: const InputDecoration(
                        labelText: 'رئيس الشعبة الميدانية'))),
            SizedBox(
                width: 220,
                child: TextField(
                    controller: servedName,
                    decoration: const InputDecoration(labelText: 'المتبلغ'))),
            SizedBox(
                width: 180,
                child: TextField(
                    controller: servedCapacity,
                    decoration: const InputDecoration(labelText: 'صفته'))),
            SizedBox(
                width: 200,
                child: TextField(
                    controller: servedNat,
                    decoration:
                        const InputDecoration(labelText: 'الرقم الوطني'))),
          ]),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('المخالفات المضبوطة',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${d.items.length}', style: TextStyle(color: context.p.muted)),
            const Spacer(),
            OutlinedButton.icon(
                onPressed: () => _addItem(st),
                icon: const Icon(CupertinoIcons.add),
                label: const Text('إضافة مخالفة')),
          ]),
          if (d.items.isEmpty)
            Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('لم تُضف مخالفات بعد',
                    style: TextStyle(color: context.p.muted)))
          else
            for (var i = 0; i < d.items.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(d.items[i].type),
                subtitle: Text(
                    'المادة: ${d.items[i].article.isEmpty ? '—' : d.items[i].article}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(d.items[i].fine)),
                  IconButton(
                    icon: const Icon(CupertinoIcons.trash, size: 20),
                    onPressed: () => setState(() => d.items.removeAt(i)),
                  ),
                ]),
              ),
          if (d.items.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                  'مجموع الغرامات: ${money(d.items.fold<num>(0, (a, v) => a + v.fine))} ل.س',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الموقع والملاحظات',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              'أدخل الإحداثيات يدوياً. تحديد الموقع تلقائياً متاح في تطبيق الموبايل بعد إضافة geolocator (انظر docs/FIELD_APP.md).',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 360,
                child: TextField(
                    controller: location,
                    decoration: const InputDecoration(
                        labelText: 'وصف الموقع (الحي، الشارع، علامة مميزة)'))),
            SizedBox(
                width: 160,
                child: TextField(
                    controller: lat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'خط العرض'))),
            SizedBox(
                width: 160,
                child: TextField(
                    controller: lng,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'خط الطول'))),
            SizedBox(
                width: 520,
                child: TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظات المفتش'))),
          ]),
        ]),
      ),
      AppCard(
        child: AttachmentList(
          items: d.attachments,
          canEdit: true,
          emptyText: 'أضف صور المخالفة أو الإشعار أو مستندات مساندة',
          onAdd: () async {
            final n =
                await addPickedFilesToDraft(context, st, d.id, d.attachments);
            if (n > 0 && mounted) {
              _collect();
              st.saveFieldDraft(d);
              setState(() {});
            }
          },
          onDelete: (a) async {
            setState(() => d.attachments.removeWhere((x) => x.id == a.id));
            await st.attachmentStore.delete(a.id);
            _collect();
            st.saveFieldDraft(d);
          },
        ),
      ),
      Row(children: [
        const Spacer(),
        OutlinedButton(
            onPressed: () => _save(st, finish: false),
            child: const Text('حفظ مسودة')),
        const SizedBox(width: 8),
        if (st.can('field.sync'))
          FilledButton.icon(
              onPressed:
                  st.fieldSyncBusy ? null : () => _save(st, finish: true),
              icon: const Icon(CupertinoIcons.arrow_up_doc),
              label: const Text('إنهاء ومزامنة')),
      ]),
    ]);
  }

  Widget _readOnly(BuildContext context, AppStore st) {
    final r = st.report(d.serverReportId);
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المفتش الميداني',
        current: 'مسودة ميدانية مزامَنة',
        fallbackLocation: '/field',
      ),
      PageHeader('مسودة ميدانية مزامَنة', subtitle: d.taxpayerName, actions: [
        if (r != null)
          FilledButton(
              onPressed: () => context.go('/reports/${r.id}'),
              child: const Text('فتح المحضر')),
      ]),
      AppCard(
        child: Column(children: [
          kv('المنشأة', d.taxpayerName),
          kv('الرقم الضريبي', d.taxNo),
          kv('رقم المحضر', d.serial),
          kv('الحالة', d.status),
          kv(
              'تاريخ المزامنة',
              d.syncedAt.isEmpty
                  ? ''
                  : fmtDT(DateTime.tryParse(d.syncedAt) ?? DateTime.now())),
          kv('المفتش', d.inspectorName),
          kv('الموقع', d.location),
          kv('الإحداثيات',
              [d.lat, d.lng].where((e) => e.isNotEmpty).join(', ')),
          kv('عدد المخالفات', '${d.items.length}'),
          kv('قيمة الضبط',
              '${money(d.items.fold<num>(0, (a, v) => a + v.fine))} ل.س'),
          if (d.notes.isNotEmpty) kv('ملاحظات', d.notes),
        ]),
      ),
      AppCard(
        child: AttachmentList(
            items: d.attachments, canEdit: false, emptyText: 'لا مرفقات'),
      ),
    ]);
  }
}
