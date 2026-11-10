import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/attachments_ui.dart';
import '../widgets/common.dart';

/// أضبارة المكلف: صور الأوراق الموجودة داخل ملفه الورقي (سجل تجاري، هوية،
/// إجازة، عقد إيجار...) مع معاينة وتنزيل وإضافة وحذف.
class TaxpayerFileScreen extends StatelessWidget {
  final String id;
  const TaxpayerFileScreen({super.key, required this.id});

  Future<void> _add(BuildContext context, AppStore st, Taxpayer t) async {
    await addPickedFilesToTaxpayer(context, st, t);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final t = st.tp(id);
    if (t == null) return const Center(child: Text('المكلف غير موجود'));
    final canEdit = st.canTaxpayerFiles();
    final total = t.attachments.fold<int>(0, (a, e) => a + e.size);
    final last = t.attachments
        .map((e) => e.uploadedAt)
        .where((e) => e.isNotEmpty)
        .fold<String>('', (a, b) => b.compareTo(a) > 0 ? b : a);
    final lastDate =
        last.isEmpty ? '' : fmtDate(DateTime.tryParse(last) ?? DateTime.now());
    final reports = st.reports.where((r) => r.taxpayerId == t.id).length;

    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المكلفون',
        current: t.name,
        fallbackLocation: '/taxpayers/${t.id}',
      ),
      PageHeader(
        'أضبارة: ${t.name}',
        subtitle: 'الأوراق المصوّرة والمستندات المحفوظة في أضبارة المكلف',
        actions: [
          if (canEdit)
            FilledButton.icon(
              onPressed: () => _add(context, st, t),
              icon: const Icon(CupertinoIcons.paperclip),
              label: const Text('إضافة صور'),
            ),
        ],
      ),
      StatGrid(
        children: [
          StatCard('صور في الأضبارة', '${t.attachments.length}',
              CupertinoIcons.photo),
          StatCard(
              'حجم الأضبارة', bytesLabel(total), CupertinoIcons.archivebox),
          StatCard('آخر إضافة', lastDate.isEmpty ? '—' : lastDate,
              CupertinoIcons.clock),
          StatCard('محاضر المكلف', '$reports', CupertinoIcons.doc_text),
        ],
      ),
      AppCard(
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: kPrimary.withValues(alpha: .12),
              child: const Icon(CupertinoIcons.briefcase, color: kPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: Text(t.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      StatusBadge(t.status),
                    ]),
                    const SizedBox(height: 2),
                    Text('${t.category} · الرقم الضريبي ${t.taxNo}',
                        style: TextStyle(color: context.p.muted, fontSize: 13)),
                  ]),
            ),
          ]),
          const Divider(height: 28),
          kv('المالك المسجل', t.owner),
          kv('المهنة / النشاط', t.profession),
          kv('العنوان', t.address),
        ]),
      ),
      AppCard(
        child: AttachmentGallery(
          items: t.attachments,
          canEdit: canEdit,
          onAdd: canEdit ? () => _add(context, st, t) : null,
          onDelete: (a) => st.removeTaxpayerAttachment(t, a),
          emptyText: 'لم تُضف صور للأضبارة بعد',
        ),
      ),
      if (!canEdit)
        Text(
          'لا تملك صلاحية إضافة صور للأضبارة. تواصل مع من يملك صلاحية تعديل المكلفين أو مع شعبة الأرشيف.',
          style: TextStyle(color: context.p.muted, fontSize: 12),
        ),
    ]);
  }
}
