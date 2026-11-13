import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/sales_api.dart';
import '../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'sales_screens.dart';

class TaxpayersScreen extends StatefulWidget {
  final String initialQuery;
  const TaxpayersScreen({super.key, this.initialQuery = ''});
  @override
  State<TaxpayersScreen> createState() => _TaxpayersScreenState();
}

class _TaxpayersScreenState extends State<TaxpayersScreen> {
  late final TextEditingController q;
  String mode = 'all', cat = '', status = '';
  final sel = <String>{};
  int page = 0;
  bool tableView = true;
  static const per = 10;

  @override
  void initState() {
    super.initState();
    q = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant TaxpayersScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery) {
      q.text = widget.initialQuery;
      page = 0;
    }
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _import(AppStore st) async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استيراد مكلفين من Excel'),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'انسخ الصفوف من Excel والصقها هنا. الأعمدة بالترتيب: اسم المنشأة، المالك، الفئة، الرقم الضريبي، العنوان. يُتجاهل الرقم الضريبي المكرر.',
                style: TextStyle(color: context.p.muted, fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
                controller: ctl,
                maxLines: 10,
                decoration: const InputDecoration(hintText: 'الصق هنا')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('استيراد'))
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final r = st.importTaxpayers(text);
    toast(context, 'أُضيف ${r[0]} مكلف وتُجوهل ${r[1]} صفاً');
  }

  Future<void> _bulkStatus(AppStore st) async {
    var s = 'متوقف مؤقتاً';
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('تغيير حالة ${sel.length} مكلف'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Drop('الحالة الجديدة', s, {for (final x in kStatuses) x: x},
                    (v) => set(() => s = v))
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: reason,
                  decoration:
                      const InputDecoration(labelText: 'سبب التغيير (إلزامي)')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => reason.text.trim().isEmpty
                    ? null
                    : Navigator.pop(ctx, true),
                child: const Text('تطبيق على المحدد')),
          ],
        ),
      ),
    );
    if (ok == true) {
      st.changeStatus(sel.toList(), s, reason.text.trim());
      setState(sel.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final dark = context.p.isDark;
    final list =
        st.searchTaxpayers(q: q.text, mode: mode, cat: cat, status: status);
    final pages = (list.length / per).ceil().clamp(1, 9999);
    if (page >= pages) page = pages - 1;
    final shown = list.skip(page * per).take(per).toList();
    final total = st.taxpayers.length;
    final active = st.taxpayers.where((t) => t.status == 'فعال').length;
    final temporarilyStopped =
        st.taxpayers.where((t) => t.status == 'متوقف مؤقتاً').length;
    final permanentlyStopped =
        st.taxpayers.where((t) => t.status == 'متوقف نهائياً').length;
    final lowSales = st.declines().length;
    final from = list.isEmpty ? 0 : page * per + 1;
    final to = (page * per + shown.length).clamp(0, list.length);

    Widget iconTile(IconData icon, Color color, {double size = 42}) =>
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? .18 : .11),
              borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(icon, color: color, size: size * .48),
        );

    Widget statTile(String label, String value, IconData icon, Color color) =>
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            iconTile(icon, color, size: 40),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.p.muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.1)),
                  ]),
            ),
          ]),
        );

    IconData categoryIcon(String category) => switch (category) {
          'صاغة' => Icons.diamond_outlined,
          'مطاعم' => Icons.restaurant_outlined,
          'شركات شامبو' => Icons.factory_outlined,
          'أخرى' => Icons.category_outlined,
          _ => Icons.category_outlined,
        };

    Widget filterOption(String label, IconData? icon) => Row(
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 18, color: dark ? const Color(0xFF8FDCCF) : kPrimary),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        );

    Widget filterDrop(String label, String value, Map<String, String> items,
        void Function(String) onChanged,
        {IconData? Function(String)? itemIcon}) {
      final selectedValue = items.containsKey(value) ? value : items.keys.first;
      return SizedBox(
        width: 188,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
              child: Text(
                label,
                style: TextStyle(
                  color: context.p.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              height: 48,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
              decoration: BoxDecoration(
                color: context.p.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.p.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(16),
                  selectedItemBuilder: (context) => items.entries
                      .map((entry) =>
                          filterOption(entry.value, itemIcon?.call(entry.key)))
                      .toList(),
                  items: items.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: filterOption(
                                entry.value, itemIcon?.call(entry.key)),
                          ))
                      .toList(),
                  onChanged: (next) {
                    if (next != null) onChanged(next);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasActiveFilters = q.text.trim().isNotEmpty ||
        mode != 'all' ||
        cat.isNotEmpty ||
        status.isNotEmpty;
    final activeFilters = <Widget>[
      if (mode != 'all')
        InputChip(
          label:
              Text('البحث في: ${mode == 'name' ? 'الاسم' : 'الرقم الضريبي'}'),
          onDeleted: () => setState(() {
            mode = 'all';
            page = 0;
          }),
        ),
      if (cat.isNotEmpty)
        InputChip(
          label: Text('الفئة: $cat'),
          onDeleted: () => setState(() {
            cat = '';
            page = 0;
          }),
        ),
      if (status.isNotEmpty)
        InputChip(
          label: Text('الحالة: $status'),
          onDeleted: () => setState(() {
            status = '';
            page = 0;
          }),
        ),
    ];

    final searchField = Container(
      padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
      decoration: BoxDecoration(
        color: context.p.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.p.border),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: dark ? .24 : .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(CupertinoIcons.search,
              size: 17, color: dark ? const Color(0xFF8FDCCF) : kPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: q,
            onChanged: (_) => setState(() => page = 0),
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المنشأة أو المالك أو الرقم الضريبي',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        if (q.text.trim().isNotEmpty)
          IconButton(
            tooltip: 'مسح البحث',
            onPressed: () => setState(() {
              q.clear();
              page = 0;
            }),
            icon: const Icon(CupertinoIcons.clear_circled_solid, size: 17),
          ),
      ]),
    );

    final filterCard = AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (c, cons) {
          final titleRow = Row(children: [
            iconTile(CupertinoIcons.line_horizontal_3_decrease, kPrimary,
                size: 34),
            const SizedBox(width: 10),
            const Text('البحث والتصفية',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('يتجاهل التشكيل والهمزات (أ/ا، ة/ه، ى/ي)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.p.muted, fontSize: 11.5)),
            ),
          ]);
          final saveButton = TextButton.icon(
            onPressed: () async {
              final n = await askText(context, 'حفظ الفلتر الحالي',
                  label: 'اسم الفلتر');
              if (n != null) {
                st.saveFilter({
                  'name': n,
                  'q': q.text,
                  'mode': mode,
                  'cat': cat,
                  'status': status
                });
              }
            },
            icon: const Icon(CupertinoIcons.bookmark, size: 16),
            label: const Text('حفظ الفلتر'),
          );
          if (cons.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleRow,
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: saveButton),
              ],
            );
          }
          return Row(children: [
            Expanded(child: titleRow),
            saveButton,
          ]);
        }),
        const SizedBox(height: 16),
        Text('ابحث في السجل',
            style: TextStyle(
                color: context.p.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        searchField,
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              '${list.length} نتيجة',
              key: ValueKey(list.length),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark ? const Color(0xFF8FDCCF) : kPrimary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              filterDrop(
                  'البحث عن طريق',
                  mode,
                  const {
                    'all': 'الكل',
                    'name': 'الاسم',
                    'tax': 'الرقم الضريبي'
                  },
                  (v) => setState(() => mode = v),
                  itemIcon: (field) => switch (field) {
                        'name' => Icons.person_search_outlined,
                        'tax' => Icons.pin_outlined,
                        _ => Icons.search,
                      }),
              filterDrop(
                  'الفئة',
                  cat,
                  {'': 'الكل', for (final c in kCategories) c: c},
                  (v) => setState(() => cat = v),
                  itemIcon: (category) => category.isEmpty
                      ? Icons.apps_outlined
                      : categoryIcon(category)),
              filterDrop(
                  'الحالة',
                  status,
                  {'': 'الكل', for (final s in kStatuses) s: s},
                  (v) => setState(() => status = v),
                  itemIcon: (value) => switch (value) {
                        'فعال' => Icons.check_circle_outline,
                        'متوقف مؤقتاً' => Icons.pause_circle_outline,
                        'متوقف نهائياً' => Icons.block_outlined,
                        _ => Icons.apps_outlined,
                      }),
              Padding(
                padding: const EdgeInsets.only(top: 21),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      side: BorderSide(color: context.p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: hasActiveFilters
                        ? () => setState(() {
                              q.clear();
                              mode = 'all';
                              cat = '';
                              status = '';
                              page = 0;
                            })
                        : null,
                    icon: const Icon(CupertinoIcons.refresh, size: 16),
                    label: const Text('إعادة ضبط'),
                  ),
                ),
              ),
            ]),
        if (activeFilters.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 2, children: activeFilters),
        ],
        if (st.savedFilters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < st.savedFilters.length; i++)
              InputChip(
                avatar: Icon(CupertinoIcons.bookmark_fill,
                    size: 14, color: dark ? const Color(0xFF8FDCCF) : kPrimary),
                label: Text(st.savedFilters[i]['name'] as String),
                onPressed: () => setState(() {
                  final f = st.savedFilters[i];
                  q.text = f['q'] as String;
                  mode = f['mode'] as String;
                  cat = f['cat'] as String;
                  status = f['status'] as String;
                  page = 0;
                }),
                onDeleted: () => st.removeFilter(i),
              ),
          ]),
        ],
      ]),
    );

    final taxpayerCards = LayoutBuilder(
      builder: (c, cons) {
        if (shown.isEmpty) {
          return AppCard(
            child: Column(children: [
              iconTile(CupertinoIcons.search, kPrimary, size: 46),
              const SizedBox(height: 10),
              const Text('لا توجد نتائج مطابقة',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  'جرّب جزءاً من الاسم أو الرقم الضريبي، أو أعد ضبط عوامل التصفية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.p.muted, fontSize: 12)),
            ]),
          );
        }
        final columns = cons.maxWidth >= 900 ? 2 : 1;
        final cardWidth =
            columns == 1 ? cons.maxWidth : (cons.maxWidth - 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final t in shown)
              SizedBox(
                width: cardWidth,
                child: _TaxpayerListCard(
                  taxpayer: t,
                  selected: sel.contains(t.id),
                  sales: st.sales[t.id],
                  declining: st.declineOf(t) != null,
                  onSelected: (selected) => setState(
                    () => selected ? sel.add(t.id) : sel.remove(t.id),
                  ),
                  onOpen: () => context.go('/taxpayers/${t.id}'),
                  onOpenFile: () => context.go('/taxpayers/${t.id}/file'),
                ),
              ),
          ],
        );
      },
    );

    final taxpayerTable = GridTable(
      minWidth: 940,
      onRowTap: (index) =>
          context.go('/taxpayers/${shown[index].id}'),
      heads: const [
        '',
        'المنشأة',
        'الفئة',
        'الرقم الضريبي',
        'العنوان',
        'الحالة',
        'إجراءات',
      ],
      flex: const [1, 4, 2, 2, 3, 2, 2],
      rows: [
        for (final t in shown)
          [
            Center(
              child: Checkbox(
                value: sel.contains(t.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    sel.add(t.id);
                  } else {
                    sel.remove(t.id);
                  }
                }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t.name.isEmpty ? 'منشأة بلا اسم' : t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.owner.isEmpty ? 'لم يُسجّل اسم المالك' : t.owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.p.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            cellText(t.category),
            cellText(t.taxNo),
            SizedBox(
              width: 160,
              child: Text(
                t.address.isEmpty ? 'غير محدد' : t.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            StatusBadge(t.status),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TaxpayerAction(
                  tooltip: 'فتح الأضبارة',
                  icon: CupertinoIcons.folder,
                  color: kGold,
                  onPressed: () => context.go('/taxpayers/${t.id}/file'),
                ),
                const SizedBox(width: 8),
                _TaxpayerAction(
                  tooltip: 'عرض التفاصيل',
                  icon: CupertinoIcons.arrow_up_right,
                  color: kPrimary2,
                  onPressed: () => context.go('/taxpayers/${t.id}'),
                ),
              ],
            ),
          ],
      ],
      empty: 'لا توجد نتائج مطابقة — جرّب تغيير البحث أو الفلاتر.',
    );

    final animatedTable = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, .025),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(
            '$tableView-$page-${shown.map((taxpayer) => taxpayer.id).join(',')}'),
        child: tableView ? taxpayerTable : taxpayerCards,
      ),
    );

    return PageBody(children: [
      // رأس الصفحة: هوية القسم، ملخّص سريع، وأزرار العمل.
      Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: dark
                ? const [Color(0xFF15201E), Color(0xFF0F1615)]
                : const [Color(0xFFFFFFFF), Color(0xFFF1F7F5)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: context.p.border, width: .6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .05),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: LayoutBuilder(
          builder: (c, cons) {
            final title = Row(children: [
              iconTile(CupertinoIcons.person_2_fill, kPrimary, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المكلفون',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.4)),
                      const SizedBox(height: 3),
                      Text('سجل المنشآت والأضابير الضريبية',
                          style:
                              TextStyle(color: context.p.muted, fontSize: 13)),
                    ]),
              ),
            ]);
            final buttons = Wrap(spacing: 8, runSpacing: 8, children: [
              if (st.can('taxpayers.edit'))
                OutlinedButton.icon(
                    onPressed: () => _import(st),
                    icon: const Icon(CupertinoIcons.arrow_up_doc, size: 17),
                    label: const Text('استيراد Excel')),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: st.exportTaxpayersTsv(list)));
                  if (context.mounted) {
                    toast(
                        context, 'نُسخت ${list.length} صفاً. الصقها في Excel');
                  }
                },
                icon: const Icon(CupertinoIcons.arrow_down_doc, size: 17),
                label: const Text('تصدير'),
              ),
              if (st.can('taxpayers.edit'))
                FilledButton.icon(
                    onPressed: () => context.go('/taxpayers/new'),
                    icon: const Icon(CupertinoIcons.add, size: 17),
                    label: const Text('إضافة مكلف')),
            ]);
            return cons.maxWidth < 760
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        title,
                        const SizedBox(height: 14),
                        buttons,
                      ])
                : Row(children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    buttons,
                  ]);
          },
        ),
      ),
      StatGrid(
        children: [
          statTile('إجمالي المكلفين', '$total',
              CupertinoIcons.person_2, kPrimary),
          statTile('المكلفون الفعالون', '$active',
              CupertinoIcons.checkmark_seal, kPrimary2),
          statTile('المتوقفون مؤقتاً', '$temporarilyStopped',
              CupertinoIcons.pause_circle, kGold),
          statTile('المتوقفون نهائياً', '$permanentlyStopped',
              CupertinoIcons.stop_circle, kRed),
          statTile('انخفاض المبيعات', '$lowSales',
              CupertinoIcons.arrow_down_right, kRed),
        ],
      ),
      filterCard,
      if (sel.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: dark
                  ? kPrimary.withValues(alpha: .22)
                  : const Color(0xFFEAF3F1),
              border: Border.all(
                  color: kPrimary.withValues(alpha: dark ? .4 : .18),
                  width: .6),
              borderRadius: BorderRadius.circular(14)),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(CupertinoIcons.checkmark_circle_fill,
                    size: 17, color: dark ? const Color(0xFF8FDCCF) : kPrimary),
                const SizedBox(width: 8),
                Text('تم تحديد ${sel.length} مكلف',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              if (st.can('taxpayers.status'))
                OutlinedButton(
                    onPressed: () => _bulkStatus(st),
                    child: const Text('تغيير الحالة')),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: st.exportTaxpayersTsv(
                          list.where((t) => sel.contains(t.id)).toList())));
                  if (context.mounted) toast(context, 'نُسخ المحدد');
                },
                child: const Text('تصدير المحدد'),
              ),
              TextButton(
                  onPressed: () => setState(sel.clear),
                  child: const Text('إلغاء التحديد')),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: LayoutBuilder(builder: (context, constraints) {
          final heading = Row(children: [
            Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                    color: kPrimary2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 9),
            const Text('قائمة المكلفين',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -.2)),
            const SizedBox(width: 10),
            Text('${list.length} نتيجة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.p.muted, fontSize: 12)),
          ]);
          final viewToggle = Seg(
            const ['بطاقات', 'جدول'],
            tableView ? 1 : 0,
            (index) => setState(() => tableView = index == 1),
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: viewToggle,
                ),
              ],
            );
          }
          return Row(children: [
            heading,
            const SizedBox(width: 14),
            Expanded(child: Container(height: .6, color: context.p.border)),
            const SizedBox(width: 14),
            viewToggle,
          ]);
        }),
      ),
      animatedTable,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.p.border, width: .6),
        ),
        child: LayoutBuilder(builder: (c, cons) {
          final controls = Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: 'السابق',
                onPressed: page > 0 ? () => setState(() => page--) : null,
                icon: const Icon(CupertinoIcons.chevron_right, size: 18)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: .06)
                      : const Color(0xFFF1F5F4),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('صفحة ${page + 1} من $pages',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            IconButton(
                tooltip: 'التالي',
                onPressed:
                    page < pages - 1 ? () => setState(() => page++) : null,
                icon: const Icon(CupertinoIcons.chevron_left, size: 18)),
          ]);
          final info = Text('عرض $from–$to من ${list.length}',
              style: TextStyle(color: context.p.muted, fontSize: 12));
          if (cons.maxWidth < 430) {
            return Column(children: [
              info,
              const SizedBox(height: 2),
              controls,
            ]);
          }
          return Row(children: [info, const Spacer(), controls]);
        }),
      ),
    ]);
  }
}

/// زر دائري بأيقونة — بنمط أزرار جدول المستخدمين.
class _TaxpayerAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const _TaxpayerAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: color.withValues(alpha: .10),
            shape: CircleBorder(
                side: BorderSide(color: color.withValues(alpha: .35))),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      );
}

class _TaxpayerListCard extends StatefulWidget {

  final Taxpayer taxpayer;
  final bool selected;
  final SalesSeries? sales;
  final bool declining;
  final ValueChanged<bool> onSelected;
  final VoidCallback onOpen;
  final VoidCallback onOpenFile;

  const _TaxpayerListCard({
    required this.taxpayer,
    required this.selected,
    required this.sales,
    required this.declining,
    required this.onSelected,
    required this.onOpen,
    required this.onOpenFile,
  });

  @override
  State<_TaxpayerListCard> createState() => _TaxpayerListCardState();
}

class _TaxpayerListCardState extends State<_TaxpayerListCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dark = context.p.isDark;
    final accent = dark ? const Color(0xFF8FDCCF) : kPrimary;
    const ease = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 240);
    final taxpayer = widget.taxpayer;
    final selected = widget.selected;
    final sales = widget.sales;
    final declining = widget.declining;
    final onSelected = widget.onSelected;
    final onOpen = widget.onOpen;
    final onOpenFile = widget.onOpenFile;

    Widget detail(String label, String value, IconData icon) => Container(
          constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.p.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: context.p.muted, fontSize: 10, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(value.isEmpty ? 'غير محدد' : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
        );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: duration,
        curve: ease,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0)
          ..multiply(Matrix4.diagonal3Values(
              _hover ? 1.012 : 1.0, _hover ? 1.012 : 1.0, 1.0)),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover
              ? kGold.withValues(alpha: dark ? .12 : .06)
              : selected
                  ? kPrimary.withValues(alpha: dark ? .16 : .055)
                  : context.p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _hover
                  ? kGold.withValues(alpha: .85)
                  : selected
                      ? accent
                      : context.p.border,
              width: (_hover || selected) ? 1.5 : .7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .075),
              blurRadius: _hover ? 22 : 12,
              offset: _hover ? const Offset(0, 10) : const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Checkbox(
                    value: selected,
                    onChanged: (value) => onSelected(value == true),
                    visualDensity: VisualDensity.compact,
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: dark
                            ? const [Color(0xFF254D46), Color(0xFF18332F)]
                            : const [Color(0xFFE7F3F0), Color(0xFFD8EAE5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      taxpayer.name.trim().isEmpty
                          ? 'م'
                          : taxpayer.name.trim()[0],
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          taxpayer.name.isEmpty
                              ? 'منشأة بلا اسم'
                              : taxpayer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          taxpayer.owner.isEmpty
                              ? 'لم يُسجّل اسم المالك'
                              : taxpayer.owner,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: context.p.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(taxpayer.status),
                ]),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Divider(height: 1, color: context.p.border),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    detail('الفئة', taxpayer.category, CupertinoIcons.tag),
                    detail(
                        'الرقم الضريبي', taxpayer.taxNo, CupertinoIcons.number),
                    if (taxpayer.address.isNotEmpty)
                      detail(
                          'العنوان', taxpayer.address, CupertinoIcons.location),
                  ],
                ),
                if (sales != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 42,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Icon(
                        declining
                            ? CupertinoIcons.arrow_down_right
                            : CupertinoIcons.chart_bar,
                        size: 16,
                        color: declining ? kRed : accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        declining ? 'اتجاه المبيعات منخفض' : 'المبيعات',
                        style: TextStyle(
                            color: declining ? kRed : context.p.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LineChart(
                          [sales.monthly],
                          height: 30,
                          mini: true,
                          colors: [declining ? kRed : kPrimary2],
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TaxpayerAction(
                      tooltip: 'فتح الأضبارة',
                      icon: CupertinoIcons.folder,
                      color: kGold,
                      onPressed: onOpenFile,
                    ),
                    _TaxpayerAction(
                      tooltip: 'عرض التفاصيل',
                      icon: CupertinoIcons.arrow_up_right,
                      color: kPrimary2,
                      onPressed: onOpen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class TaxpayerFormScreen extends StatefulWidget {
  final String? id;
  const TaxpayerFormScreen({super.key, this.id});
  @override
  State<TaxpayerFormScreen> createState() => _TaxpayerFormScreenState();
}

class _TaxpayerFormScreenState extends State<TaxpayerFormScreen> {
  final name = TextEditingController(),
      owner = TextEditingController(),
      taxNo = TextEditingController(),
      address = TextEditingController(),
      profession = TextEditingController();
  String cat = 'صاغة', status = 'فعال';
  String? err;
  Taxpayer? existing;
  final initialValues = <String, String>{};

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      existing = context.read<AppStore>().tp(widget.id!);
      final t = existing;
      if (t != null) {
        name.text = t.name;
        owner.text = t.owner;
        taxNo.text = t.taxNo;
        address.text = t.address;
        profession.text = t.profession;
        cat = t.category;
        status = t.status;
        initialValues.addAll({
          'اسم المنشأة': t.name,
          'المالك': t.owner,
          'الفئة': t.category,
          'العنوان': t.address,
          'المهنة': t.profession,
        });
      }
    }
  }

  Future<void> _fetch(AppStore st) async {
    final r = await st.salesApi.lookupTaxpayer(taxNo.text);
    if (!mounted) return;
    if (r == null) {
      toast(context, 'لم تُعثر بيانات لهذا الرقم');
      return;
    }
    setState(() {
      name.text = r['name'] ?? '';
      owner.text = r['owner'] ?? '';
      address.text = r['address'] ?? '';
      cat = r['category'] ?? cat;
    });
  }

  void _save(AppStore st) {
    if (name.text.trim().isEmpty || taxNo.text.trim().isEmpty) {
      setState(() => err = 'اسم المنشأة والرقم الضريبي إلزاميان');
      return;
    }
    if (existing != null) {
      final t = existing!;
      final updatedValues = {
        'اسم المنشأة': name.text.trim(),
        'المالك': owner.text.trim(),
        'الفئة': cat,
        'العنوان': address.text.trim(),
        'المهنة': profession.text.trim(),
      };
      final changes = updatedValues.entries
          .where((entry) => initialValues[entry.key] != entry.value)
          .map((entry) =>
              '${entry.key}: ${initialValues[entry.key] ?? '—'} ← ${entry.value.isEmpty ? '—' : entry.value}')
          .join(' · ');
      t.name = name.text.trim();
      t.owner = owner.text.trim();
      t.category = cat;
      t.address = address.text.trim();
      t.profession = profession.text.trim();
      st.updateTaxpayer(t, detail: changes);
      context.go('/taxpayers/${t.id}');
      return;
    }
    final t = Taxpayer(
        id: newId(),
        name: name.text.trim(),
        owner: owner.text.trim(),
        category: cat,
        taxNo: taxNo.text.trim(),
        address: address.text.trim(),
        profession: profession.text.trim(),
        status: status);
    final e = st.addTaxpayer(t);
    if (e != null) {
      setState(() => err = e);
      return;
    }
    context.go('/taxpayers/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppStore>();
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المكلفون',
        current: existing?.name ?? 'إضافة مكلف',
        fallbackLocation:
            existing == null ? '/taxpayers' : '/taxpayers/${existing!.id}',
      ),
      PageHeader(existing == null ? 'إضافة مكلف' : 'تعديل مكلف',
          subtitle: 'يمكن جلب البيانات تلقائياً من الواجهة بالرقم الضريبي',
          actions: [
            OutlinedButton(
                onPressed: () => context.go('/taxpayers'),
                child: const Text('إلغاء')),
            FilledButton(onPressed: () => _save(st), child: const Text('حفظ')),
          ]),
      AppCard(
        child: Column(children: [
          rowOf([
            Field('الرقم الضريبي',
                ctl: taxNo, readOnly: existing != null, flex: 3),
            if (existing == null)
              OutlinedButton.icon(
                  onPressed: () => _fetch(st),
                  icon: const Icon(CupertinoIcons.cloud_download),
                  label: const Text('جلب البيانات من الواجهة')),
          ]),
          const SizedBox(height: 12),
          rowOf([
            Field('اسم المنشأة', ctl: name),
            Field('المالك المسجل', ctl: owner)
          ]),
          const SizedBox(height: 12),
          rowOf([
            Drop('الفئة', cat, {for (final c in kCategories) c: c},
                (v) => setState(() => cat = v)),
            if (existing == null)
              Drop('الحالة', status, {for (final s in kStatuses) s: s},
                  (v) => setState(() => status = v)),
            Field('المهنة', ctl: profession),
          ]),
          const SizedBox(height: 12),
          rowOf([Field('العنوان', ctl: address)]),
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(err!, style: const TextStyle(color: kRed))),
        ]),
      ),
    ]);
  }
}

class TaxpayerProfileScreen extends StatefulWidget {
  final String id;
  const TaxpayerProfileScreen({super.key, required this.id});
  @override
  State<TaxpayerProfileScreen> createState() => _TaxpayerProfileScreenState();
}


/// رأس قسم فخم داخل تبويبات صفحة المكلف.
Widget _luxeHead(BuildContext context,
    {required IconData icon,
    required String title,
    required String subtitle,
    required Color accent}) =>
    Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [accent, accent.withValues(alpha: .55)],
          ),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.2)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: context.p.muted, fontSize: 11.5)),
          ],
        ),
      ),
    ]);

class _TaxpayerProfileScreenState extends State<TaxpayerProfileScreen> {
  int tab = 0;
  static const tabs = [
    'نظرة عامة',
    'المحاضر',
    'المبيعات',
    'البيانات الشهرية',
    'سجل الحالة'
  ];

  Future<void> _changeStatus(AppStore st, Taxpayer t) async {
    var s = t.status;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('تغيير حالة المكلف'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Drop('الحالة', s, {for (final x in kStatuses) x: x},
                    (v) => set(() => s = v))
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: reason,
                  decoration:
                      const InputDecoration(labelText: 'السبب (إلزامي)')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => reason.text.trim().isEmpty
                    ? null
                    : Navigator.pop(ctx, true),
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok == true) st.changeStatus([t.id], s, reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final t = st.tp(widget.id);
    if (t == null) return const Center(child: Text('المكلف غير موجود'));
    final reports = st.reports.where((r) => r.taxpayerId == t.id).toList();
    final activeReports = reports.where((r) => r.status != 'ملغى').length;
    final totalFines = reports.fold<num>(0, (a, r) => a + r.total);
    final initial = t.name.trim().isEmpty ? 'م' : t.name.trim().substring(0, 1);

    Widget miniStat(String label, String value) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: context.p.muted, fontSize: 12)),
            const SizedBox(height: 5),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
          ]),
        );

    final actions = <Widget>[
      if (st.can('reports.create'))
        FilledButton.icon(
          onPressed: () => context.go('/reports/new?tp=${t.id}'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8C766),
            foregroundColor: const Color(0xFF3A2B12),
            padding: const EdgeInsetsDirectional.fromSTEB(20, 13, 20, 13),
            shape: const StadiumBorder(),
            elevation: 2,
            shadowColor: kGold.withValues(alpha: .5),
          ),
          icon: const Icon(CupertinoIcons.add, size: 18),
          label: const Text('محضر جديد',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      if (st.can('taxpayers.edit'))
        OutlinedButton.icon(
          onPressed: () => context.go('/taxpayers/${t.id}/edit'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: .92),
            side: BorderSide(color: Colors.white.withValues(alpha: .28)),
            backgroundColor: Colors.white.withValues(alpha: .08),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 12),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(CupertinoIcons.pencil, size: 16),
          label: const Text('تعديل البيانات',
              style: TextStyle(fontSize: 13)),
        ),
      if (st.can('taxpayers.status'))
        OutlinedButton.icon(
          onPressed: () => _changeStatus(st, t),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFE2A6),
            side: BorderSide(color: const Color(0xFFE8C766).withValues(alpha: .5)),
            backgroundColor: const Color(0xFFE8C766).withValues(alpha: .12),
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 12),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
          label: const Text('تغيير الحالة',
              style: TextStyle(fontSize: 13)),
        ),
    ];

    Widget body;
    switch (tab) {
      case 1:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: _luxeHead(context,
                  icon: CupertinoIcons.doc_text,
                  title: 'محاضر ${t.name}',
                  subtitle:
                      '${reports.length} محضر — انقر أي محضر لفتحه',
                  accent: kPrimary2),
            ),
            const SizedBox(height: 12),
            GridTable(
              heads: const [
                'الرقم',
                'التاريخ',
                'المخالفات',
                'قيمة الضبط',
                'الحالة'
              ],
              flex: const [1, 1, 3, 1, 1],
              rows: [
                for (final r in reports)
                  [
                    InkWell(
                        onTap: () => context.go('/reports/${r.id}'),
                        child: cellText(r.serial, bold: true)),
                    cellText(fmtDate(r.date)),
                    cellText(r.items.map((e) => e.type).join('، ')),
                    cellText(money(r.total)),
                    StatusBadge(r.status)
                  ]
              ],
              empty: 'لا توجد محاضر لهذا المكلف',
            ),
          ],
        );
        break;
      case 2:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: _luxeHead(context,
                  icon: CupertinoIcons.chart_bar,
                  title: 'مبيعات ${t.name}',
                  subtitle: 'هذه السنة مقابل الماضية، ويومياً و5 سنوات',
                  accent: kGold),
            ),
            const SizedBox(height: 12),
            SalesPanel(taxpayer: t),
          ],
        );
        break;
      case 3:
        final now = DateTime.now();
        body = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _luxeHead(context,
                  icon: CupertinoIcons.calendar_circle,
                  title: 'التزام البيانات الشهرية',
                  subtitle: 'آخر 12 شهراً — الأخضر وصلك في وقته والرمادي لم يصل',
                  accent: kPrimary2),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < 12; i++)
                  Builder(builder: (_) {
                    final ym = ymOf(DateTime(now.year, now.month - i, 1));
                    final ok = st.submitted(t.id, ym);
                    return Container(
                      width: 88,
                      height: 82,
                      padding:
                          const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                      decoration: BoxDecoration(
                        color: ok
                            ? const Color(0xFFEAF7EF)
                            : context.p.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ok
                              ? const Color(0xFF34C759).withValues(alpha: .45)
                              : context.p.border,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(ym,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .2)),
                          const SizedBox(height: 5),
                          Icon(
                            ok
                                ? CupertinoIcons.checkmark_seal_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            size: 17,
                            color: ok
                                ? const Color(0xFF34C759)
                                : kRed,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ok ? 'مقدّم' : 'غير مقدّم',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: ok
                                    ? const Color(0xFF1E7A3A)
                                    : kRed),
                          ),
                        ],
                      ),
                    );
                  }),
              ]),
            ],
          ),
        );
        break;
      case 4:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: _luxeHead(context,
                  icon: CupertinoIcons.clock,
                  title: 'سجل تغييرات الحالة',
                  subtitle:
                      'متى وكيف تغيّرت حالة هذا المكلف — الأحدث أولاً',
                  accent: kGold),
            ),
            const SizedBox(height: 12),
            GridTable(
              heads: const ['التاريخ', 'من', 'إلى', 'السبب', 'بواسطة'],
              flex: const [2, 2, 2, 3, 2],
              rows: [
                for (final h in t.history.reversed)
                  [
                    cellText('${h['date']}'),
                    StatusBadge('${h['from']}'),
                    StatusBadge('${h['to']}'),
                    cellText('${h['reason']}'),
                    cellText('${h['by']}')
                  ]
              ],
              empty: 'لم تتغير حالة هذا المكلف',
            ),
          ],
        );
        break;
      default:
        final details = AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8C766), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withValues(alpha: .45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.briefcase,
                    size: 21, color: Color(0xFF3A2B12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بيانات المنشأة',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: context.p.text)),
                    const SizedBox(height: 2),
                    Text('المعلومات الأساسية المسجّلة',
                        style: TextStyle(
                            color: context.p.muted, fontSize: 11.5)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            InfoTileGrid(
              tiles: [
                InfoTile(
                    icon: CupertinoIcons.person,
                    label: 'المالك المسجل',
                    value: t.owner),
                InfoTile(
                    icon: CupertinoIcons.briefcase,
                    label: 'المهنة / النشاط',
                    value: t.profession),
                InfoTile(
                    icon: CupertinoIcons.tag,
                    label: 'الفئة',
                    value: t.category),
                InfoTile(
                    icon: CupertinoIcons.number,
                    label: 'الرقم الضريبي',
                    value: t.taxNo),
              ],
            ),
            const SizedBox(height: 8),
            InfoTile(
                icon: CupertinoIcons.location,
                label: 'العنوان',
                value: t.address,
                maxLines: 3),
          ]),
        );
        final side = Column(children: [
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: .16),
                    border: Border.all(color: kGold.withValues(alpha: .3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.doc_chart,
                      size: 20, color: kGold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('ملخص المحاضر والأداء',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: context.p.text)),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                miniStat('المحاضر', '${reports.length}'),
                Container(width: .6, height: 34, color: context.p.border),
                const SizedBox(width: 14),
                miniStat('مخالفات سارية', '$activeReports'),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                miniStat('إجمالي الضبوط', money(totalFines)),
                const SizedBox(width: 14),
                miniStat('الوضع', t.status),
              ]),
            ]),
          ),
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(CupertinoIcons.time, size: 15, color: context.p.muted),
                const SizedBox(width: 8),
                Text('آخر تحديث للحالة',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.p.text)),
              ]),
              const SizedBox(height: 12),
              if (t.history.isEmpty)
                Text('لم يسجّل أي تغيير على الحالة بعد.',
                    style: TextStyle(color: context.p.muted, fontSize: 13))
              else
                Builder(builder: (_) {
                  final h = t.history.last;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          StatusBadge('${h['to']}'),
                          const SizedBox(width: 8),
                          Text('${h['date']}',
                              style: TextStyle(
                                  color: context.p.muted, fontSize: 12)),
                        ]),
                        if ('${h['reason']}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('${h['reason']}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                      ]);
                }),
            ]),
          ),
        ]);
        body = LayoutBuilder(
          builder: (c, cons) => cons.maxWidth < 900
              ? Column(children: [details, const SizedBox(height: 12), side])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: details),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: side),
                ]),
        );
    }

    return PageBody(children: [
      // شريط تنقّل علوي: زر رجوع + مسار الصفحة.
      BackBreadcrumb(
        parent: 'المكلفون',
        current: t.name,
        fallbackLocation: '/taxpayers',
      ),
      // البطاقة الرئيسية الفاخرة: هوية المكلف وأزرار العمل.
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0C2420).withValues(alpha: .55),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF123B36), Color(0xFF0C2420)],
              ),
            ),
            child: Stack(
              children: [
                // توهّجات زخرفية داخل الحدود
                PositionedDirectional(
                  top: -40,
                  end: -30,
                  child: _glowDecoration(kGold.withValues(alpha: .22), 150),
                ),
                PositionedDirectional(
                  bottom: -50,
                  start: -40,
                  child: _glowDecoration(const Color(0xFF2E8C7E).withValues(alpha: .30), 170),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(builder: (c, cons) {
                      final wide = cons.maxWidth >= 640;
                      final avatar = Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFE8C766), Color(0xFFB8860B)],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .4),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: kGold.withValues(alpha: .45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(initial,
                                  style: const TextStyle(
                                      color: Color(0xFF3A2B12),
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: t.status == 'فعال'
                                    ? const Color(0xFF34C759)
                                    : t.status == 'متوقف مؤقتاً'
                                        ? kGold
                                        : kRed,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF0C2420), width: 3.5),
                              ),
                            ),
                          ),
                        ],
                      );
                      final identity = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              Text(
                                t.name.isEmpty ? 'منشأة بلا اسم' : t.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.4),
                              ),
                              StatusBadge(t.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _heroChip(CupertinoIcons.number,
                                'الرقم الضريبي ${t.taxNo}'),
                            _heroChip(CupertinoIcons.tag, t.category),
                            if (t.owner.isNotEmpty)
                              _heroChip(CupertinoIcons.person_fill, t.owner),
                            if (t.address.isNotEmpty)
                              _heroChip(CupertinoIcons.location_fill, t.address),
                          ]),
                        ],
                      );
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: avatar),
                            const SizedBox(height: 16),
                            identity,
                          ],
                        );
                      }
                      return Row(children: [
                        avatar,
                        const SizedBox(width: 22),
                        Expanded(child: identity),
                      ]);
                    }),
                    const SizedBox(height: 20),
                    Divider(
                        color: Colors.white.withValues(alpha: .14), height: 1),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroStat(
                            icon: CupertinoIcons.doc_text,
                            label: 'المحاضر',
                            value: '${reports.length}'),
                        _HeroStat(
                            icon: CupertinoIcons.clock,
                            label: 'قيد الإجراء',
                            value:
                                '${reports.where((r) => r.status == 'مسودة' || r.status == 'بانتظار رئيس الشعبة' || r.status == 'بانتظار رئيس الدائرة').length}'),
                        _HeroStat(
                            icon: CupertinoIcons.money_dollar,
                            label: 'إجمالي الضبوط',
                            value: money(totalFines)),
                        _HeroStat(
                            icon: CupertinoIcons.checkmark_seal,
                            label: 'المخالفات السارية',
                            value: '$activeReports'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, children: actions),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // أضبارة المكلف: بطاقة ذهبية فاخرة مستقلّة.
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: kGold.withValues(alpha: .30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFFFDF7E7), Color(0xFFF6ECD6)],
              ),
            ),
            child: LayoutBuilder(builder: (c, cons) {
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('أضبارة المكلف',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A3410))),
                      if (t.attachments.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${t.attachments.length} صورة',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7A5B12))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'السجل التجاري، الهوية، الإجازة، عقد الإيجار وبقية الأوراق المصوّرة',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Color(0xFF6F5A1E), fontSize: 12, height: 1.4),
                  ),
                ],
              );
              final button = FilledButton.icon(
                onPressed: () => context.go('/taxpayers/${t.id}/file'),
                style: FilledButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: const Color(0xFF3A2B12),
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 14),
                  shape: const StadiumBorder(),
                  elevation: 2,
                  shadowColor: kGold.withValues(alpha: .5),
                ),
                icon: const Icon(CupertinoIcons.folder, size: 19),
                label: const Text('فتح الأضبارة',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
              );
              final tile = Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8C766), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withValues(alpha: .55),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.folder,
                    size: 30, color: Color(0xFF3A2B12)),
              );
              if (cons.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      tile,
                      const SizedBox(width: 14),
                      Expanded(child: label),
                    ]),
                    const SizedBox(height: 14),
                    Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: button),
                  ],
                );
              }
              return Row(children: [
                tile,
                const SizedBox(width: 14),
                Expanded(child: label),
                const SizedBox(width: 12),
                button,
              ]);
            }),
          ),
        ),
      ),
      _LuxTabs(
        items: tabs,
        icons: const [
          CupertinoIcons.square_grid_2x2_fill,
          CupertinoIcons.doc_text,
          CupertinoIcons.chart_bar,
          CupertinoIcons.calendar_circle,
          CupertinoIcons.clock,
        ],
        index: tab,
        onChanged: (i) => setState(() => tab = i),
      ),
      body,
    ]);
  }
}

/// توهّج دائري للزخرفة في بطاقات المكلف الرئيسية.
Widget _glowDecoration(Color color, double size) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
      child: SizedBox(width: size, height: size),
    );

/// شريحة زجاجية داكنة في رأس صفحة المكلف.
Widget _heroChip(IconData icon, String text) => Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: .85)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: .88))),
        ),
      ]),
    );

/// إحصائية صغيرة داخل رأس صفحة المكلف (زجاجية).
class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(13, 9, 13, 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: const Color(0xFFE8C766)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: .62),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ]),
      );
}

/// شريط تبويبات المكلف — بطاقة عاجية وإيزمارالد فخم مع أيقونة ذهبية عند التحديد.
class _LuxTabs extends StatelessWidget {
  final List<String> items;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;
  const _LuxTabs({
    required this.items,
    required this.icons,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wideEnough = MediaQuery.of(context).size.width >= 820;
    final bar = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DFCE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: wideEnough ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: 4),
            if (wideEnough)
              Expanded(
                child: _LuxTab(
                  icon: icons[i],
                  label: items[i],
                  selected: i == index,
                  onTap: () => onChanged(i),
                ),
              )
            else
              _LuxTab(
                icon: icons[i],
                label: items[i],
                selected: i == index,
                onTap: () => onChanged(i),
              ),
          ],
        ],
      ),
    );

    return wideEnough
        ? bar
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: bar,
          );
  }
}

class _LuxTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LuxTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const _deep = Color(0xFF123B36);
  static const _ink = Color(0xFF3B3326);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        splashColor: const Color(0xFFB8860B).withValues(alpha: .18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _deep : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: selected
                ? Border.all(color: const Color(0xFFB8860B), width: 1.2)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _deep.withValues(alpha: .40),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? const Color(0xFFE8C766)
                    : const Color(0xFF8A7B4B),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
