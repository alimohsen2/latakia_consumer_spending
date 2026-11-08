import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'common.dart';

class _Nav {
  final String path, label, group;
  final IconData icon;
  final String? perm;

  /// لون أيقونة القسم: ألوان هادئة مقروءة على خلفية الثيم الداكنة.
  final Color color;
  const _Nav(
      this.path, this.label, this.icon, this.perm, this.group, this.color);
}

const _items = [
  _Nav('/', 'لوحة التحكم', CupertinoIcons.square_grid_2x2, null, 'الرئيسية',
      Color(0xFFFFD27A)),
  _Nav('/alerts', 'التنبيهات والمواعيد', CupertinoIcons.bell, 'alerts.view',
      'الرئيسية', Color(0xFFFF9E80)),
  _Nav('/taxpayers', 'المكلفون', CupertinoIcons.briefcase, 'taxpayers.view',
      'المكلفون', Color(0xFF7FB8FF)),
  _Nav('/reports', 'المحاضر', CupertinoIcons.doc_text, 'reports.view',
      'المحاضر', Color(0xFFF7C873)),
  _Nav('/approvals', 'اعتماد المحاضر', CupertinoIcons.checkmark_seal,
      'reports.approve|reports.endorse', 'المحاضر', Color(0xFFA8E6A1)),
  _Nav('/field', 'المفتش الميداني', CupertinoIcons.location, 'field.view',
      'الميدان', Color(0xFFFFB3C1)),
  _Nav('/archive', 'أرشيف المحاضر', CupertinoIcons.archivebox, 'archive.view',
      'الأرشيف', Color(0xFFC7B6FF)),
  _Nav('/statements', 'البيانات الشهرية', CupertinoIcons.calendar,
      'statements.edit', 'البيانات والسجلات', Color(0xFF8ADCE3)),
  _Nav('/violations', 'سجل المخالفات', CupertinoIcons.exclamationmark_triangle,
      'registers.view', 'البيانات والسجلات', Color(0xFFFFB07C)),
  _Nav('/followup', 'سجل المتابعة', CupertinoIcons.square_list,
      'registers.view', 'البيانات والسجلات', Color(0xFFFFE08A)),
  _Nav('/analytics', 'مبيعات المكلفين', CupertinoIcons.graph_square,
      'analytics.view', 'المبيعات والتحليل', Color(0xFF9FE3C0)),
  _Nav('/declines', 'انخفاض المبيعات', CupertinoIcons.arrow_down_right,
      'analytics.view', 'المبيعات والتحليل', Color(0xFFFFA99B)),
  _Nav('/reports-center', 'التقارير', CupertinoIcons.chart_bar,
      'reports.center', 'التقارير', Color(0xFF9EC5FF)),
  _Nav('/users', 'المستخدمون', CupertinoIcons.person_2, 'users.manage',
      'المستخدمون والصلاحيات', Color(0xFFD6C2FF)),
  _Nav(
      '/active-users',
      'المستخدمون الفعّالون حاليًا',
      CupertinoIcons.person_crop_circle_badge_checkmark,
      'users.manage',
      'المستخدمون والصلاحيات',
      Color(0xFF9FE3C0)),
  _Nav('/profile', 'ملفي الشخصي', CupertinoIcons.person_crop_circle, null,
      'المستخدمون والصلاحيات', Color(0xFF9EC5FF)),
  _Nav('/permissions', 'الصلاحيات', CupertinoIcons.lock_shield,
      'permissions.manage', 'المستخدمون والصلاحيات', Color(0xFFFFD27A)),
  _Nav('/serials', 'دفاتر أرقام المحاضر', CupertinoIcons.list_number,
      'serials.manage', 'السجلات والرقابة', Color(0xFFC9D4E3)),
  _Nav('/audit', 'سجل العمليات', CupertinoIcons.time, 'audit.view',
      'السجلات والرقابة', Color(0xFFB9C6D8)),
  _Nav('/integrity', 'سلامة السجلات', CupertinoIcons.shield, 'integrity.view',
      'السجلات والرقابة', Color(0xFFA8E6A1)),
  _Nav('/routing', 'توزيع التنبيهات', CupertinoIcons.arrow_branch,
      'alerts.route', 'تهيئة النظام', Color(0xFF8ADCE3)),
  _Nav('/settings', 'الإعدادات والنسخ', CupertinoIcons.gear, 'settings.manage',
      'تهيئة النظام', Color(0xFFC9D4E3)),
];

const _groupIcons = <String, IconData>{
  'الرئيسية': Icons.home_rounded,
  'المكلفون': Icons.groups_rounded,
  'المحاضر': Icons.assignment_rounded,
  'الميدان': Icons.explore_rounded,
  'الأرشيف': Icons.inventory_2_rounded,
  'البيانات والسجلات': Icons.fact_check_rounded,
  'المبيعات والتحليل': Icons.insights_rounded,
  'التقارير': Icons.summarize_rounded,
  'المستخدمون والصلاحيات': Icons.admin_panel_settings_rounded,
  'السجلات والرقابة': Icons.fact_check_rounded,
  'تهيئة النظام': Icons.settings_rounded,
};

const _groupColors = <String, Color>{
  'الرئيسية': Color(0xFFFFD27A),
  'المكلفون': Color(0xFF7FB8FF),
  'المحاضر': Color(0xFFF7C873),
  'الميدان': Color(0xFFFF9EAE),
  'الأرشيف': Color(0xFFC7B6FF),
  'البيانات والسجلات': Color(0xFF8ADCE3),
  'المبيعات والتحليل': Color(0xFF9FE3C0),
  'التقارير': Color(0xFF9EC5FF),
  'المستخدمون والصلاحيات': Color(0xFFD6C2FF),
  'السجلات والرقابة': Color(0xFFB9C6D8),
  'تهيئة النظام': Color(0xFF8ADCE3),
};

class AppShell extends StatefulWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarVisible = true;

  @override
  void initState() {
    super.initState();
    _loadSidebarPreference();
  }

  Future<void> _loadSidebarPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _sidebarVisible = prefs.getBool('lcs_sidebar_visible_v1') ?? true;
      });
    } catch (error) {
      if (mounted) toast(context, 'تعذر استعادة حالة القائمة الجانبية: $error');
    }
  }

  Future<void> _toggleSidebar() async {
    final visible = !_sidebarVisible;
    setState(() => _sidebarVisible = visible);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setBool('lcs_sidebar_visible_v1', visible);
      if (!saved) throw StateError('لم يتم حفظ التفضيل');
    } catch (error) {
      if (mounted) toast(context, 'تعذر حفظ حالة القائمة الجانبية: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wide = MediaQuery.of(context).size.width >= 1000;
    final storageWarning = _storageWarning(context, store);
    final side = Sidebar(
      location: widget.location,
      onClose: () {
        if (wide) {
          _toggleSidebar();
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
    if (wide) {
      return Scaffold(
        body: Row(children: [
          AnimatedContainer(
            width: _sidebarVisible ? 276 : 0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: 276,
                maxWidth: 276,
                child: SizedBox(
                  width: 276,
                  child: AnimatedSlide(
                    offset:
                        _sidebarVisible ? Offset.zero : const Offset(.08, 0),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOutCubic,
                    child: AnimatedOpacity(
                      opacity: _sidebarVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 252,
                          child: Sidebar(
                            location: widget.location,
                            floating: true,
                            onClose: _toggleSidebar,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(children: [
              if (store.persistenceError != null) storageWarning,
              TopBar(
                sidebarVisible: _sidebarVisible,
                onToggleSidebar: _toggleSidebar,
              ),
              Expanded(child: widget.child),
            ]),
          ),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'فتح القائمة الجانبية',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(CupertinoIcons.sidebar_left),
          ),
        ),
        title: const Text('الإنفاق الاستهلاكي',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      drawer: Drawer(
        width: (MediaQuery.sizeOf(context).width * .88)
            .clamp(0.0, 320.0)
            .toDouble(),
        backgroundColor: context.p.chrome,
        child: side,
      ),
      body: Column(children: [
        if (store.persistenceError != null) storageWarning,
        Expanded(child: widget.child),
      ]),
    );
  }

  Widget _storageWarning(BuildContext context, AppStore store) =>
      MaterialBanner(
        content: Text(store.persistenceError ?? ''),
        leading: const Icon(Icons.error_outline, color: Colors.red),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await store.retryPersistence();
              } catch (error) {
                if (context.mounted) toast(context, '$error');
              }
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
}

/// شريط جانبي بهوية الدائرة: خلفية Teal داكنة، نصوص بيضاء، وأيقونات ملوّنة.
class Sidebar extends StatefulWidget {
  final String location;
  final VoidCallback onClose;
  final bool floating;
  const Sidebar({
    super.key,
    required this.location,
    required this.onClose,
    this.floating = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final _collapsedGroups = <String>{};

  @override
  void initState() {
    super.initState();
    _showOnlyGroup(_groupForLocation(widget.location));
    _loadCollapsedGroups();
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _showOnlyGroup(_groupForLocation(widget.location));
      _saveCollapsedGroups();
    }
  }

  void _showOnlyGroup(String? group) {
    _collapsedGroups
      ..addAll(_items.map((item) => item.group))
      ..remove(group);
  }

  String? _groupForLocation(String location) {
    for (final item in _items) {
      if (item.path == '/'
          ? location == '/'
          : location == item.path || location.startsWith('${item.path}/')) {
        return item.group;
      }
    }
    return null;
  }

  Future<void> _loadCollapsedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed =
          prefs.getStringList('lcs_sidebar_collapsed_groups_v1') ?? [];
      if (!mounted) return;
      setState(() {
        _collapsedGroups
          ..clear()
          ..addAll(collapsed);
        _showOnlyGroup(_groupForLocation(widget.location));
      });
      await _saveCollapsedGroups();
    } catch (error) {
      if (mounted) toast(context, 'تعذر استعادة حالة أقسام القائمة: $error');
    }
  }

  Future<void> _saveCollapsedGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
          'lcs_sidebar_collapsed_groups_v1', _collapsedGroups.toList());
      if (!saved) throw StateError('لم يتم حفظ التفضيل');
    } catch (error) {
      if (mounted) toast(context, 'تعذر حفظ حالة أقسام القائمة: $error');
    }
  }

  void _toggleGroup(String group) {
    setState(() {
      if (_collapsedGroups.contains(group)) {
        _showOnlyGroup(group);
      } else {
        _collapsedGroups.add(group);
      }
    });
    _saveCollapsedGroups();
  }

  void _toggleAllGroups(Iterable<String> groups) {
    final groupNames = groups.toSet();
    if (groupNames.isEmpty) return;
    final collapseAll = !_collapsedGroups.containsAll(groupNames);
    setState(() {
      if (collapseAll) {
        _collapsedGroups.addAll(_items.map((item) => item.group));
      } else {
        final activeGroup = _groupForLocation(widget.location);
        _showOnlyGroup(
          activeGroup != null && groupNames.contains(activeGroup)
              ? activeGroup
              : groupNames.first,
        );
      }
    });
    _saveCollapsedGroups();
  }

  bool _selected(String p) => p == '/'
      ? widget.location == '/'
      : (widget.location == p || widget.location.startsWith('$p/'));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final alertCount = st.me == null ? 0 : st.alertsFor(st.me!).length;
    final groups = <String, List<_Nav>>{};
    for (final item in _items) {
      if (item.perm != null && !st.can(item.perm!)) continue;
      if (item.path == '/field' && !st.canField()) continue;
      groups.putIfAbsent(item.group, () => []).add(item);
    }
    final allGroupsCollapsed =
        groups.isNotEmpty && _collapsedGroups.containsAll(groups.keys);

    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 10, 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2E8C7E), Color(0xFF17574E)]),
                shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                shadows: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ]),
            child: const Icon(CupertinoIcons.shield_fill,
                color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الإنفاق الاستهلاكي',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white)),
              Text('مديرية مالية اللاذقية',
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
            ]),
          ),
          Semantics(
            button: true,
            label: allGroupsCollapsed
                ? 'إظهار مجموعة واحدة'
                : 'طي المجموعة المفتوحة',
            child: IconButton(
              onPressed: () => _toggleAllGroups(groups.keys),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                allGroupsCollapsed
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_up,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
        child: Container(height: .8, color: Colors.white.withValues(alpha: .2)),
      ),
    ];
    for (final entry in groups.entries) {
      final group = entry.key;
      final collapsed = _collapsedGroups.contains(group);
      children.add(
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 4),
          child: Semantics(
            button: true,
            expanded: !collapsed,
            label: '${collapsed ? 'إظهار' : 'طي'} مجموعة $group',
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              focusColor: Colors.white.withValues(alpha: .12),
              onTap: () => _toggleGroup(group),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 8, 9),
                child: Row(children: [
                  Icon(_groupIcons[group] ?? CupertinoIcons.folder,
                      size: 16, color: _groupColors[group] ?? Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(group,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .94),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .1)),
                  ),
                  AnimatedRotation(
                    turns: collapsed ? 0 : .5,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(CupertinoIcons.chevron_down,
                        size: 13, color: Colors.white70),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );

      final navChildren = <Widget>[];
      for (final n in entry.value) {
        final on = _selected(n.path);
        navChildren.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            child: Semantics(
              button: true,
              selected: on,
              label: on ? '${n.label}، الصفحة الحالية' : n.label,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                focusColor: Colors.white.withValues(alpha: .12),
                onTap: () {
                  final sc = Scaffold.maybeOf(context);
                  if (sc != null && sc.isDrawerOpen) Navigator.pop(context);
                  context.go(n.path);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: on
                        ? n.color.withValues(alpha: .16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: on
                        ? Border.all(
                            color: n.color.withValues(alpha: .58),
                            width: .8,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: on
                                  ? n.color.withValues(alpha: .2)
                                  : Colors.white.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(n.icon, size: 16, color: n.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(n.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: on
                                      ? Colors.white
                                      : const Color(0xE6FFFFFF),
                                  fontWeight:
                                      on ? FontWeight.w700 : FontWeight.w400)),
                        ),
                        if (n.path == '/alerts' && alertCount > 0)
                          Semantics(
                            label: '$alertCount تنبيه',
                            child: Container(
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD27A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                alertCount > 99 ? '99+' : '$alertCount',
                                style: const TextStyle(
                                  color: Color(0xFF293027),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        if (on)
                          Icon(CupertinoIcons.circle_fill,
                              size: 6, color: n.color),
                      ]),
                      if (on)
                        PositionedDirectional(
                          start: 0,
                          top: 5,
                          bottom: 5,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: n.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )));
      }
      children.add(
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(width: double.infinity, height: 0)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: navChildren,
                  ),
          ),
        ),
      );
    }
    return Container(
      key: widget.floating ? const ValueKey('floating-sidebar') : null,
      clipBehavior: widget.floating ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: context.p.chrome,
        borderRadius:
            widget.floating ? BorderRadius.circular(20) : BorderRadius.zero,
        border: widget.floating
            ? Border.all(color: Colors.white.withValues(alpha: .1), width: .7)
            : Border(
                left: BorderSide(
                    color: Colors.white.withValues(alpha: .08), width: .5)),
        boxShadow: widget.floating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ListView(children: [...children, const SizedBox(height: 20)]),
    );
  }
}

class TopBar extends StatefulWidget {
  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  const TopBar(
      {super.key, required this.sidebarVisible, required this.onToggleSidebar});
  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final ctl = TextEditingController();
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final me = st.me;
    final n = me == null ? 0 : st.alertsFor(me).length;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
          color: context.p.surface,
          border:
              Border(bottom: BorderSide(color: context.p.border, width: .5))),
      child: Row(children: [
        IconButton(
          tooltip: widget.sidebarVisible
              ? 'إخفاء القائمة الجانبية'
              : 'إظهار القائمة الجانبية',
          onPressed: widget.onToggleSidebar,
          icon: Icon(
            widget.sidebarVisible
                ? CupertinoIcons.sidebar_left
                : CupertinoIcons.sidebar_right,
            size: 20,
            color: context.p.muted,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 380,
          height: 36,
          child: TextField(
            controller: ctl,
            onSubmitted: (v) =>
                context.go('/taxpayers?q=${Uri.encodeComponent(v)}'),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
                hintText: 'بحث عن مكلف بالاسم أو الرقم الضريبي',
                prefixIcon: Icon(CupertinoIcons.search,
                    size: 16, color: context.p.muted),
                fillColor: context.p.field,
                contentPadding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
        const Spacer(),
        const ThemeToggle(),
        Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: IconButton(
              onPressed: () => context.go('/alerts'),
              icon:
                  Icon(CupertinoIcons.bell, size: 22, color: context.p.muted)),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: context.p.surface,
          onSelected: (v) {
            if (v == 'profile') context.go('/profile');
            if (v == 'verify') context.go('/verify');
            if (v == 'theme') st.toggleDarkMode();
            if (v == 'logout') {
              st.logout();
              context.go('/login');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
            const PopupMenuItem(value: 'verify', child: Text('التحقق من محضر')),
            PopupMenuItem(
                value: 'theme',
                child: Row(children: [
                  Icon(
                      st.darkMode
                          ? CupertinoIcons.sun_max
                          : CupertinoIcons.moon,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(st.darkMode ? 'الوضع الفاتح' : 'الوضع الداكن'),
                ])),
            const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
          ],
          child: Row(children: [
            CircleAvatar(
                radius: 17,
                backgroundColor: kPrimary,
                child: Text((me?.name ?? 'م').substring(0, 1),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
            const SizedBox(width: 9),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(me?.name ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(kRoles[me?.role] ?? '',
                      style: TextStyle(fontSize: 11, color: context.p.muted)),
                ]),
          ]),
        ),
      ]),
    );
  }
}
