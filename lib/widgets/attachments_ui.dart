import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/file_writer.dart';
import '../core/theme.dart';
import '../data/attachments.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

class PickedAttachment {
  final String name, mime;
  final Uint8List bytes;
  const PickedAttachment(this.name, this.mime, this.bytes);
}

String mimeFor(String name) {
  final e = name.split('.').last.toLowerCase();
  switch (e) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}

String bytesLabel(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} ميغا';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} ك.ب';
  return '$n بايت';
}

/// يفتح منتقي الملفات ويعيد الملفات مع بايتاتها. في الويب يعمل بدون أي إعداد.
Future<List<PickedAttachment>> pickAttachments(
    {bool imagesOnly = false}) async {
  final res = await FilePicker.platform.pickFiles(
    type: imagesOnly ? FileType.image : FileType.any,
    allowMultiple: true,
    withData: true,
  );
  if (res == null) return [];
  return [
    for (final f in res.files)
      if (f.bytes != null) PickedAttachment(f.name, mimeFor(f.name), f.bytes!),
  ];
}

/// تنزيل/حفظ ملف المرفق. على الويب يبدأ التنزيل مباشرة.
Future<bool> saveAttachmentFile(String name, Uint8List bytes) async {
  final path = await FilePicker.platform.saveFile(
    fileName: name,
    bytes: bytes,
    lockParentWindow: !kIsWeb,
  );
  if (path == null) return false;
  if (!kIsWeb && requiresFileWriteAfterSave) {
    await writeBytesToFile(path, bytes);
  }
  return true;
}

/// نافذة معاينة موحّدة للمرفق مع زر التنزيل. تُستخدم في القوائم ومعرض الصور.
Future<void> previewAttachment(BuildContext context, Attachment a) async {
  final st = context.read<AppStore>();
  final bytes = await st.attachmentBytes(a.id);
  if (!context.mounted) return;
  if (bytes == null) {
    toast(context,
        'تعذر العثور على الملف. إن كنت على نسخة أخرى فقد تحتاج إلى إعادة رفعه.');
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.p.surface,
      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(40)),
      title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 640,
        height: 460,
        child: a.isImage
            ? Image.memory(bytes, fit: BoxFit.contain)
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(a.isPdf ? CupertinoIcons.doc_text : CupertinoIcons.doc,
                    size: 72, color: ctx.p.muted),
                const SizedBox(height: 12),
                Text('${a.mime} · ${bytesLabel(bytes.length)}',
                    style: TextStyle(color: ctx.p.muted)),
                const SizedBox(height: 6),
                Text('لا يمكن معاينة هذا النوع داخل التطبيق. استخدم «تنزيل».',
                    style: TextStyle(color: ctx.p.muted, fontSize: 12)),
              ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final saved = await saveAttachmentFile(a.name, bytes);
              if (saved && ctx.mounted) {
                toast(ctx, 'تم حفظ «${a.name}»');
              }
            } catch (error) {
              if (ctx.mounted) toast(ctx, 'تعذر حفظ الملف: $error');
            }
          },
          icon: const Icon(CupertinoIcons.arrow_down_doc),
          label: const Text('تنزيل'),
        ),
      ],
    ),
  );
}

/// سطر مرفق واحد: أيقونة، الاسم، الحجم، ومن قام بإضافته، مع عرض/تنزيل/حذف.
class AttachmentTile extends StatelessWidget {
  final Attachment a;
  final bool canDelete;
  final Future<void> Function()? onDelete;

  const AttachmentTile(this.a,
      {super.key, this.canDelete = false, this.onDelete});

  Future<void> _view(BuildContext context) => previewAttachment(context, a);

  Future<void> _download(BuildContext context) async {
    final st = context.read<AppStore>();
    final bytes = await st.attachmentBytes(a.id);
    if (!context.mounted) return;
    if (bytes == null) return toast(context, 'الملف غير موجود');
    try {
      final saved = await saveAttachmentFile(a.name, bytes);
      if (saved && context.mounted) toast(context, 'تم حفظ «${a.name}»');
    } catch (e) {
      if (context.mounted) toast(context, 'تعذر حفظ الملف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = [
      bytesLabel(a.size),
      if (a.uploadedAt.isNotEmpty)
        a.uploadedAt
            .substring(0, a.uploadedAt.length >= 10 ? 10 : a.uploadedAt.length),
      if (a.uploadedBy.isNotEmpty) a.uploadedBy,
      if (a.note.isNotEmpty) a.note,
    ].where((e) => e.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: a.kind == 'photo'
              ? (context.p.isDark
                  ? kPrimary.withValues(alpha: .18)
                  : const Color(0xFFF5F5F7))
              : context.p.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          a.kind == 'photo'
              ? CupertinoIcons.photo
              : (a.isPdf ? CupertinoIcons.doc_text : CupertinoIcons.doc),
          color: a.kind == 'photo'
              ? (context.p.isDark ? const Color(0xFFF2F2F4) : kPrimary)
              : context.p.muted,
          size: 21,
        ),
      ),
      title: Text(a.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle:
          Text(sub, style: TextStyle(fontSize: 12, color: context.p.muted)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: 'عرض',
            onPressed: () => _view(context),
            icon: const Icon(CupertinoIcons.eye, size: 20)),
        IconButton(
            tooltip: 'تنزيل',
            onPressed: () => _download(context),
            icon: const Icon(CupertinoIcons.arrow_down_doc, size: 20)),
        if (canDelete && onDelete != null)
          IconButton(
            tooltip: 'حذف',
            onPressed: () async {
              if (await confirmDialog(context, 'حذف مرفق',
                      'سيُحذف «${a.name}» نهائياً. المتابعة؟') &&
                  context.mounted) {
                await onDelete!();
              }
            },
            icon: const Icon(CupertinoIcons.trash, size: 20, color: kRed),
          ),
      ]),
    );
  }
}

/// قائمة مرفقات مع زر إضافة اختياري. تُستخدم في الأرشيف والميدان.
class AttachmentList extends StatelessWidget {
  final List<Attachment> items;
  final bool canEdit;
  final Future<void> Function()? onAdd;
  final Future<void> Function(Attachment)? onDelete;
  final String emptyText;

  const AttachmentList({
    super.key,
    required this.items,
    this.canEdit = false,
    this.onAdd,
    this.onDelete,
    this.emptyText = 'لا توجد مرفقات بعد',
  });

  @override
  Widget build(BuildContext context) {
    final used = items.fold<int>(0, (a, e) => a + e.size);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('المرفقات', style: TextStyle(fontWeight: FontWeight.w700)),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Text('${items.length} · ${bytesLabel(used)}',
                style: TextStyle(color: context.p.muted, fontSize: 12)),
          ),
        const Spacer(),
        if (canEdit && onAdd != null)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(CupertinoIcons.paperclip),
            label: const Text('إضافة مرفق'),
          ),
      ]),
      const SizedBox(height: 4),
      Text(
          'صور المخالفة، الإشعارات، القرارات، ومحاضر الضبط الممسوحة. الحد 1.5 ميغابايت للملف الواحد.',
          style: TextStyle(color: context.p.muted, fontSize: 12)),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
              child: Text(emptyText, style: TextStyle(color: context.p.muted))),
        )
      else
        for (var i = 0; i < items.length; i++) ...[
          AttachmentTile(
            items[i],
            canDelete: canEdit,
            onDelete: onDelete == null ? null : () => onDelete!(items[i]),
          ),
          if (i < items.length - 1) const Divider(),
        ],
    ]);
  }
}

/// يضيف الملفات المختارة إلى محضر (مع رسائل الخطأ). يعيد عدد المضاف.
Future<int> addPickedFilesToReport(BuildContext context, AppStore st, Report r,
    {bool imagesOnly = false}) async {
  final picked = await pickAttachments(imagesOnly: imagesOnly);
  var n = 0;
  String? err;
  for (final p in picked) {
    err = st.attachmentError(p.bytes);
    if (err != null) continue;
    final a = await st.addReportAttachment(
      r,
      name: p.name,
      mime: p.mime,
      bytes: p.bytes,
      kind: p.mime.startsWith('image/') ? 'photo' : 'document',
    );
    if (a != null) n++;
  }
  if (context.mounted) {
    if (err != null) {
      toast(context, err);
    } else if (n > 0) {
      toast(context, 'أُضيف $n مرفق');
    }
  }
  return n;
}

/// يضيف ملفات إلى مسودة ميدانية (دون حفظ المسودة؛ على المستدعي الحفظ).
Future<int> addPickedFilesToDraft(
    BuildContext context, AppStore st, String ownerId, List<Attachment> target,
    {bool imagesOnly = false}) async {
  final picked = await pickAttachments(imagesOnly: imagesOnly);
  var n = 0;
  String? err;
  for (final p in picked) {
    err = st.attachmentError(p.bytes);
    if (err != null) continue;
    final a = await st.createAttachment(
      ownerId: ownerId,
      name: p.name,
      mime: p.mime,
      bytes: p.bytes,
      kind: p.mime.startsWith('image/') ? 'photo' : 'document',
    );
    if (a != null) {
      target.add(a);
      n++;
    }
  }
  if (context.mounted) {
    if (err != null) {
      toast(context, err);
    } else if (n > 0) {
      toast(context, 'أُضيف $n مرفق');
    }
  }
  return n;
}

/// يضيف صوراً إلى أضبارة مكلف (مع رسائل الخطأ). يعيد عدد المضاف.
Future<int> addPickedFilesToTaxpayer(
    BuildContext context, AppStore st, Taxpayer t,
    {bool imagesOnly = true}) async {
  final picked = await pickAttachments(imagesOnly: imagesOnly);
  var n = 0;
  String? err;
  for (final p in picked) {
    err = st.attachmentError(p.bytes);
    if (err != null) continue;
    final a = await st.addTaxpayerAttachment(
      t,
      name: p.name,
      mime: p.mime,
      bytes: p.bytes,
      kind: p.mime.startsWith('image/') ? 'photo' : 'document',
    );
    if (a != null) n++;
  }
  if (context.mounted) {
    if (err != null) {
      toast(context, err);
    } else if (n > 0) {
      toast(context, 'أُضيف $n مستنداً إلى الأضبارة');
    }
  }
  return n;
}

/// معرض صور الأضبارة: شبكة مصغّرات مع معاينة وحذف.
class AttachmentGallery extends StatelessWidget {
  final List<Attachment> items;
  final bool canEdit;
  final Future<void> Function()? onAdd;
  final Future<void> Function(Attachment)? onDelete;
  final String emptyText;
  final String title;

  const AttachmentGallery({
    super.key,
    required this.items,
    this.canEdit = false,
    this.onAdd,
    this.onDelete,
    this.emptyText = 'لا توجد صور في الأضبارة بعد',
    this.title = 'صور الأضبارة',
  });

  @override
  Widget build(BuildContext context) {
    final used = items.fold<int>(0, (a, e) => a + e.size);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Text('${items.length} صورة · ${bytesLabel(used)}',
                style: TextStyle(color: context.p.muted, fontSize: 12)),
          ),
        const Spacer(),
        if (canEdit && onAdd != null)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(CupertinoIcons.paperclip),
            label: const Text('إضافة صور'),
          ),
      ]),
      const SizedBox(height: 4),
      Text(
          'صوّر الأوراق داخل الأضبارة: السجل التجاري، الهوية، الإجازة، عقد الإيجار، وأي مستند ورقي. الحد 1.5 ميغابايت للصورة.',
          style: TextStyle(color: context.p.muted, fontSize: 12)),
      const SizedBox(height: 14),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: Column(children: [
              Icon(CupertinoIcons.folder, size: 42, color: context.p.muted),
              const SizedBox(height: 8),
              Text(emptyText, style: TextStyle(color: context.p.muted)),
            ]),
          ),
        )
      else
        Wrap(spacing: 12, runSpacing: 14, children: [
          for (final a in items)
            _GalleryThumb(
              a: a,
              canDelete: canEdit,
              onDelete: onDelete == null ? null : () => onDelete!(a),
            ),
        ]),
    ]);
  }
}

class _GalleryThumb extends StatelessWidget {
  final Attachment a;
  final bool canDelete;
  final Future<void> Function()? onDelete;
  const _GalleryThumb(
      {required this.a, required this.canDelete, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppStore>();
    return SizedBox(
      width: 168,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => previewAttachment(context, a),
            child: Container(
              width: 168,
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.p.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.p.border, width: .5),
              ),
              child: FutureBuilder<Uint8List?>(
                future: st.attachmentBytes(a.id),
                builder: (c, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final b = s.data;
                  if (b == null) {
                    return Center(
                        child: Icon(CupertinoIcons.exclamationmark_triangle,
                            color: context.p.muted));
                  }
                  if (!a.isImage) {
                    return Center(
                        child: Icon(
                            a.isPdf
                                ? CupertinoIcons.doc_text
                                : CupertinoIcons.doc,
                            size: 42,
                            color: context.p.muted));
                  }
                  return Image.memory(b,
                      fit: BoxFit.cover,
                      width: 168,
                      height: 120,
                      gaplessPlayback: true);
                },
              ),
            ),
          ),
          if (canDelete && onDelete != null)
            Positioned(
              top: 6,
              left: 6,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    if (await confirmDialog(context, 'حذف الصورة',
                            'ستُحذف «${a.name}» من الأضبارة. المتابعة؟') &&
                        context.mounted) {
                      await onDelete!();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(CupertinoIcons.xmark,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 5),
        Text(a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(bytesLabel(a.size),
            style: TextStyle(fontSize: 11, color: context.p.muted)),
      ]),
    );
  }
}

/// نص توضيحي لمساحة المرفقات المستخدمة.
Future<String> attachmentsUsageLabel(AppStore st) async {
  final b = await st.attachmentStore.usedBytes();
  return '${bytesLabel(b)} من ${bytesLabel(AttachmentStore.maxBytes * 5)} تقريباً';
}
