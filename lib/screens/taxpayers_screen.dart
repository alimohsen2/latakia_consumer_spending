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
  bool tableView = false;
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
                color: context.p.field,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: context.p.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
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

    final taxpayerTable = AppCard(
      padding: EdgeInsets.zero,
      child: shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('لا توجد نتائج مطابقة',
                    style: TextStyle(color: context.p.muted)),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: DataTable(
                  headingRowHeight: 54,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 72,
                  horizontalMargin: 20,
                  columnSpacing: 28,
                  dividerThickness: .6,
                  headingRowColor: WidgetStatePropertyAll(
                    Color.alphaBlend(
                      kPrimary.withValues(alpha: dark ? .20 : .075),
                      context.p.surface,
                    ),
                  ),
                  headingTextStyle: TextStyle(
                    color: dark ? const Color(0xFFB7E2D9) : kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  dataTextStyle: TextStyle(
                    color: context.p.text,
                    fontSize: 13,
                  ),
                  columns: [
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.building_2_fill,
                            title: 'المنشأة / المالك')),
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.tag_fill, title: 'الفئة')),
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.number,
                            title: 'الرقم الضريبي')),
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.location_fill,
                            title: 'العنوان')),
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.checkmark_seal_fill,
                            title: 'الحالة')),
                    DataColumn(
                        label: _TaxpayerTableHeader(
                            icon: CupertinoIcons.ellipsis_circle_fill,
                            title: 'الإجراءات')),
                  ],
                  rows: [
                    for (final entry in shown.indexed)
                      DataRow(
                        selected: sel.contains(entry.$2.id),
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return kPrimary.withValues(alpha: dark ? .25 : .10);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return kPrimary.withValues(alpha: dark ? .12 : .05);
                          }
                          if (entry.$1.isOdd) {
                            return Color.alphaBlend(
                              Colors.black.withValues(alpha: dark ? .10 : .025),
                              context.p.surface,
                            );
                          }
                          return context.p.surface;
                        }),
                        onSelectChanged: (selected) => setState(
                          () => selected == true
                              ? sel.add(entry.$2.id)
                              : sel.remove(entry.$2.id),
                        ),
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 190,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.$2.name.isEmpty
                                        ? 'منشأة بلا اسم'
                                        : entry.$2.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    entry.$2.owner.isEmpty
                                        ? 'لم يُسجّل اسم المالك'
                                        : entry.$2.owner,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: context.p.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(entry.$2.category)),
                          DataCell(Text(entry.$2.taxNo)),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                entry.$2.address.isEmpty
                                    ? 'غير محدد'
                                    : entry.$2.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(StatusBadge(entry.$2.status)),
                          DataCell(
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'فتح الأضبارة',
                              onPressed: () =>
                                  context.go('/taxpayers/${entry.$2.id}/file'),
                              icon: const Icon(CupertinoIcons.folder, size: 18),
                            ),
                            IconButton(
                              tooltip: 'عرض التفاصيل',
                              onPressed: () =>
                                  context.go('/taxpayers/${entry.$2.id}'),
                              icon: const Icon(CupertinoIcons.arrow_up_right,
                                  size: 18),
                            ),
                          ])),
                        ],
                      ),
                  ],
                ),
              ),
            ),
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
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
            width: 240,
            child: statTile('إجمالي المكلفين', '$total',
                CupertinoIcons.person_2, kPrimary)),
        SizedBox(
            width: 240,
            child: statTile('المكلفون الفعالون', '$active',
                CupertinoIcons.checkmark_seal, kPrimary2)),
        SizedBox(
            width: 240,
            child: statTile('المتوقفون مؤقتاً', '$temporarilyStopped',
                CupertinoIcons.pause_circle, kGold)),
        SizedBox(
            width: 240,
            child: statTile('المتوقفون نهائياً', '$permanentlyStopped',
                CupertinoIcons.stop_circle, kRed)),
        SizedBox(
            width: 240,
            child: statTile('انخفاض المبيعات', '$lowSales',
                CupertinoIcons.arrow_down_right, kRed)),
      ]),
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

class _TaxpayerTableHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _TaxpayerTableHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15,
              color: context.p.isDark ? const Color(0xFFB7E2D9) : kPrimary),
          const SizedBox(width: 7),
          Text(title),
        ],
      );
}

class _TaxpayerListCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dark = context.p.isDark;
    final accent = dark ? const Color(0xFF8FDCCF) : kPrimary;

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? kPrimary.withValues(alpha: dark ? .16 : .055)
            : context.p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected ? accent : context.p.border,
            width: selected ? 1.4 : .7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .12 : .035),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                          [sales!.monthly],
                          height: 30,
                          mini: true,
                          colors: [declining ? kRed : kPrimary2],
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: onOpenFile,
                        icon: const Icon(CupertinoIcons.folder, size: 16),
                        label: const Text('الأضبارة'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onOpen,
                        icon:
                            const Icon(CupertinoIcons.arrow_up_right, size: 16),
                        label: const Text('عرض التفاصيل'),
                      ),
                    ]),
              ],
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
    final dark = context.p.isDark;
    final reports = st.reports.where((r) => r.taxpayerId == t.id).toList();
    final activeReports = reports.where((r) => r.status != 'ملغى').length;
    final totalFines = reports.fold<num>(0, (a, r) => a + r.total);
    final initial = t.name.trim().isEmpty ? 'م' : t.name.trim().substring(0, 1);

    Widget metaChip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: .06)
                  : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: context.p.muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.p.muted)),
            ),
          ]),
        );

    Widget goldTile(IconData icon, {double size = 50}) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: .06)
                : const Color(0xFFF6F1E7),
            borderRadius: BorderRadius.circular(size * .28),
            border: Border.all(color: kGold.withValues(alpha: .22), width: .6),
          ),
          child: Icon(icon, color: kGold, size: size * .46),
        );

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
          icon: const Icon(CupertinoIcons.add, size: 16),
          label: const Text('محضر جديد'),
        ),
      if (st.can('taxpayers.edit'))
        OutlinedButton.icon(
          onPressed: () => context.go('/taxpayers/${t.id}/edit'),
          icon: const Icon(CupertinoIcons.pencil, size: 15),
          label: const Text('تعديل البيانات'),
        ),
      if (st.can('taxpayers.status'))
        OutlinedButton.icon(
          onPressed: () => _changeStatus(st, t),
          icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 15),
          label: const Text('تغيير الحالة'),
        ),
    ];

    Widget body;
    switch (tab) {
      case 1:
        body = GridTable(
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
        );
        break;
      case 2:
        body = SalesPanel(taxpayer: t);
        break;
      case 3:
        final now = DateTime.now();
        body = AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الالتزام بتقديم البيانات الشهرية',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('آخر ١٢ شهراً',
                style: TextStyle(color: context.p.muted, fontSize: 12)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < 12; i++)
                Builder(builder: (_) {
                  final ym = ymOf(DateTime(now.year, now.month - i, 1));
                  final ok = st.submitted(t.id, ym);
                  final c = badgeColors(ok ? 'مقدّم' : 'غير مقدّم');
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: c.$1, borderRadius: BorderRadius.circular(20)),
                    child: Text('$ym · ${ok ? "مقدّم" : "غير مقدّم"}',
                        style: TextStyle(
                            color: c.$2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  );
                }),
            ]),
          ]),
        );
        break;
      case 4:
        body = GridTable(
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
        );
        break;
      default:
        final details = AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text('بيانات المنشأة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.p.text)),
              ),
              const SizedBox(width: 8),
              Text('سجل المكلف',
                  style: TextStyle(color: context.p.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            const Divider(),
            kv('المالك المسجل', t.owner),
            kv('المهنة / النشاط', t.profession),
            kv('العنوان', t.address),
            kv('الفئة', t.category),
            kv('الرقم الضريبي', t.taxNo),
          ]),
        );
        final side = Column(children: [
          AppCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 3,
                    height: 15,
                    decoration: BoxDecoration(
                        color: kGold, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('ملخص سريع',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.p.text)),
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
      // البطاقة الرئيسية: هوية المكلف وأزرار العمل.
      Container(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: dark
                ? const [Color(0xFF16201E), Color(0xFF0F1615)]
                : const [Color(0xFFFFFFFF), Color(0xFFF2F7F5)],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: context.p.border, width: .6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .28 : .05),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E8C7E), Color(0xFF17574E)]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: kPrimary.withValues(alpha: .28),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.3)),
                          StatusBadge(t.status),
                        ]),
                    const SizedBox(height: 7),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      metaChip(
                          CupertinoIcons.number, 'الرقم الضريبي ${t.taxNo}'),
                      metaChip(CupertinoIcons.tag, t.category),
                      if (t.address.isNotEmpty)
                        metaChip(CupertinoIcons.location, t.address),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          Divider(color: context.p.border),
          const SizedBox(height: 14),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...actions,
                const SizedBox(width: 4),
                metaChip(CupertinoIcons.doc_text, '${reports.length} محضر'),
              ]),
        ]),
      ),
      // أضبارة المكلف: زر مستقل أسفل البطاقة الرئيسية كما هو مطلوب.
      LayoutBuilder(builder: (c, cons) {
        final label =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('أضبارة المكلف',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (t.attachments.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                    color: kGold.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${t.attachments.length} صورة',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kGold)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Text(
              'السجل التجاري، الهوية، الإجازة، عقد الإيجار، وبقية الأوراق المصوّرة',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
        ]);
        final button = FilledButton.icon(
          onPressed: () => context.go('/taxpayers/${t.id}/file'),
          icon: const Icon(CupertinoIcons.folder, size: 16),
          label: const Text('فتح الأضبارة'),
        );
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.p.border, width: .6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .22 : .04),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
            ],
          ),
          child: cons.maxWidth < 620
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    goldTile(CupertinoIcons.folder),
                    const SizedBox(width: 14),
                    Expanded(child: label)
                  ]),
                  const SizedBox(height: 14),
                  Align(
                      alignment: AlignmentDirectional.centerEnd, child: button),
                ])
              : Row(children: [
                  goldTile(CupertinoIcons.folder),
                  const SizedBox(width: 14),
                  Expanded(child: label),
                  const SizedBox(width: 12),
                  button,
                ]),
        );
      }),
      Seg(tabs, tab, (i) => setState(() => tab = i)),
      body,
    ]);
  }
}
