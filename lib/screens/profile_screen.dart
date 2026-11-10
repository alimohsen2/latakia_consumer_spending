import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

/// ملف المستخدم: بيانات الحساب والصلاحيات والمحاضر التي أنشأها.
/// تُعرض للمستخدم الحالي عبر `/profile`، ويمكن لمدير المستخدمين فتح ملف أي
/// مستخدم عبر `/users/:id/profile`.
class ProfileScreen extends StatelessWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final user = userId == null ? st.me : _findUser(st, userId!);
    final isSelf = user != null && user.id == st.me?.id;

    if (user == null) {
      return PageBody(children: [
        if (userId != null)
          const BackBreadcrumb(
            parent: 'إدارة المستخدمين',
            current: 'ملف غير موجود',
            fallbackLocation: '/users',
          ),
        const PageHeader('الملف الشخصي'),
        const AppCard(
          child: Text('تعذر العثور على حساب المستخدم المطلوب.'),
        ),
      ]);
    }

    final reports = st.reports
        .where((report) => _belongsToUser(report.createdBy, user))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final inProgress = reports
        .where((report) => const [
              'مسودة',
              'بانتظار رئيس الشعبة',
              'بانتظار رئيس الدائرة',
            ].contains(report.status))
        .length;
    final completed = reports
        .where((report) => report.status == 'معتمد' || report.status == 'مقفل')
        .length;
    final cancelled =
        reports.where((report) => report.status == 'ملغى').length;
    final fines = reports
        .where((report) => report.status != 'ملغى')
        .fold<num>(0, (sum, report) => sum + report.total);
    final manager = _findUser(st, user.managerId);
    final permissions = _permissionsFor(st, user);
    final canManageUsers = st.can('users.manage');
    final createdStamp = _stamp(user.createdAt);

    return PageBody(children: [
      if (userId != null)
        BackBreadcrumb(
          parent: 'إدارة المستخدمين',
          current: user.name,
          fallbackLocation: '/users',
        ),
      _HeroCard(
        store: st,
        user: user,
        isSelf: isSelf,
        reportsCount: reports.length,
        inProgress: inProgress,
        completed: completed,
        fines: fines,
      ),
      _ProfileStatsRow(
        reportsCount: reports.length,
        inProgress: inProgress,
        completed: completed,
        cancelled: cancelled,
        fines: fines,
      ),
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;
        final account = _CollapsibleSection(
          title: 'بيانات الحساب',
          subtitle: 'المعلومات الأساسية للحساب والتوقيع الوظيفي',
          icon: CupertinoIcons.person_crop_rectangle,
          accent: kPrimary2,
          children: [
            const SizedBox(height: 8),
            InfoTileGrid(tiles: [
              _InfoCard(
                icon: CupertinoIcons.person_fill,
                label: 'الاسم الكامل',
                value: user.name,
              ),
              _InfoCard(
                icon: CupertinoIcons.at,
                label: 'اسم المستخدم',
                value: user.username.isEmpty ? '—' : user.username,
              ),
              _InfoCard(
                icon: CupertinoIcons.phone_fill,
                label: 'رقم الموبايل',
                value: user.phone,
              ),
              _InfoCard(
                icon: CupertinoIcons.briefcase_fill,
                label: 'الدور',
                value: kRoles[user.role] ?? user.role,
                accent: kGold,
              ),
              _InfoCard(
                icon: CupertinoIcons.building_2_fill,
                label: 'الشعبة',
                value: kDivisionNames[user.division] ??
                    kDivisions[user.division] ??
                    user.division,
              ),
              _InfoCard(
                icon: CupertinoIcons.checkmark_seal_fill,
                label: 'الحالة',
                value: _statusLabel(user.status),
                accent: user.status == 'active' ? kPrimary2 : kRed,
              ),
            ]),
          ],
        );
        final lifecycle = canManageUsers
            ? _CollapsibleSection(
                title: 'الإنشاء والإغلاق',
                subtitle: 'سجل إنشاء الحساب والجهات المسؤولة عنه',
                icon: CupertinoIcons.calendar_badge_plus,
                accent: kGold,
                children: [
                  const SizedBox(height: 8),
                  InfoTileGrid(tiles: [
                    _InfoCard(
                      icon: CupertinoIcons.person_2_fill,
                      label: 'المسؤول المباشر',
                      value: manager?.name ?? '—',
                    ),
                    _InfoCard(
                      icon: CupertinoIcons.calendar_circle,
                      label: 'تاريخ إنشاء الحساب',
                      value: createdStamp,
                    ),
                    _InfoCard(
                      icon: CupertinoIcons.person_badge_plus,
                      label: 'أنشئ من قبل',
                      value: user.createdBy,
                    ),
                    if (user.closedAt.isNotEmpty)
                      _InfoCard(
                        icon: CupertinoIcons.lock_fill,
                        label: 'تاريخ الإغلاق',
                        value: _stamp(user.closedAt),
                        accent: kRed,
                      ),
                    if (user.closedBy.isNotEmpty)
                      _InfoCard(
                        icon: CupertinoIcons.xmark_circle_fill,
                        label: 'أغلقه',
                        value: user.closedBy,
                        accent: kRed,
                      ),
                    if (user.closureReason.isNotEmpty)
                      _InfoCard(
                        icon: CupertinoIcons.exclamationmark_circle,
                        label: 'سبب الإغلاق',
                        value: user.closureReason,
                        accent: kRed,
                      ),
                  ]),
                ],
              )
            : null;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            account,
            if (lifecycle != null) ...[
              const SizedBox(height: 18),
              lifecycle,
            ],
          ],
        );
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [Color(0xFFA98545), Color(0xFF7C5A1E)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.lock_shield_fill,
                          size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الصلاحيات',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            user.role == 'sysadmin'
                                ? 'مدير النظام يملك كل الصلاحيات'
                                : 'الصلاحيات المسندة لهذا الحساب',
                            style: TextStyle(
                              color: context.p.muted,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: context.p.isDark
                            ? Colors.white.withValues(alpha: .08)
                            : const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${permissions.length}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  if (user.role == 'sysadmin')
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: context.p.isDark ? .16 : .10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kGold.withValues(alpha: .35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.sparkles,
                              size: 17, color: kGold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'صلاحيات كاملة على النظام بوصفه مدير النظام',
                              style: TextStyle(
                                color: context.p.isDark
                                    ? const Color(0xFFE9CEA8)
                                    : const Color(0xFF6B4A0C),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (permissions.isEmpty)
                    Text(
                      'لا توجد صلاحيات مسندة لهذا الحساب.',
                      style: TextStyle(color: context.p.muted, fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final permission in permissions)
                          Container(
                            padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 6),
                            decoration: BoxDecoration(
                              color: context.p.isDark
                                  ? Colors.white.withValues(alpha: .06)
                                  : const Color(0xFFF4F6F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.p.isDark
                                    ? const Color(0xFF29302F)
                                    : const Color(0xFFE0E7E5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.checkmark_circle_fill,
                                    size: 14, color: kPrimary2),
                                const SizedBox(width: 6),
                                Text(
                                  kPerms[permission] ?? permission,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details,
              const SizedBox(height: 18),
              side,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: details),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: side),
          ],
        );
      }),
      if (reports.isNotEmpty)
        _ReportsSection(
          reports: reports,
          store: st,
          user: user,
          isSelf: isSelf,
        ),
    ]);
  }

  static AppUser? _findUser(AppStore store, String id) {
    for (final user in store.users) {
      if (user.id == id) return user;
    }
    return null;
  }

  static bool _belongsToUser(String createdBy, AppUser user) {
    final value = createdBy.trim();
    return value.isNotEmpty &&
        (value == user.name.trim() || value == user.username.trim());
  }

  static List<String> _permissionsFor(AppStore store, AppUser user) {
    if (user.role == 'sysadmin') return kPerms.keys.toList();
    return store.perms[user.role] ?? const [];
  }

  static String _statusLabel(String value) => switch (value) {
        'closed' => 'مغلق نهائيًا',
        'disabled' => 'معطل مؤقتًا',
        _ => 'فعال',
      };

  static String _stamp(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? '—' : fmtDT12(date);
  }
}

/// رأس الملف: بطاقة ترقية بصورة كبيرة ومعلومات سريعة وأزرار.
class _HeroCard extends StatelessWidget {
  final AppStore store;
  final AppUser user;
  final bool isSelf;
  final int reportsCount, inProgress, completed;
  final num fines;

  const _HeroCard({
    required this.store,
    required this.user,
    required this.isSelf,
    required this.reportsCount,
    required this.inProgress,
    required this.completed,
    required this.fines,
  });

  @override
  Widget build(BuildContext context) {
    final role = kRoles[user.role] ?? user.role;
    final division = kDivisionNames[user.division] ??
        kDivisions[user.division] ??
        user.division;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .35),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Color(0xFF1D6054),
                Color(0xFF17574E),
                Color(0xFF0E3A34),
              ],
            ),
          ),
          child: Stack(children: [
            PositionedDirectional(
              top: -84,
              start: -64,
              child: _glow(kGold.withValues(alpha: .28), 240),
            ),
            PositionedDirectional(
              bottom: -110,
              end: -72,
              child: _glow(kPrimary2.withValues(alpha: .35), 280),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(28, 24, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      Text(
                        isSelf ? 'ملفي الشخصي' : 'ملف المستخدم',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .88),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .4,
                        ),
                      ),
                      if (isSelf)
                        FilledButton.icon(
                          onPressed: () => context.go('/change-password'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: .16),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                14, 10, 14, 10),
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12))),
                          ),
                          icon: const Icon(CupertinoIcons.lock_rotation,
                              size: 17),
                          label: const Text(
                            'تغيير كلمة المرور',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final avatar = _ProfileAvatar(store: store,
                        user: user, editable: isSelf);
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.3,
                              ),
                            ),
                            StatusBadge(ProfileScreen._statusLabel(user.status)),
                            if (user.passwordChangeRequired)
                              const StatusBadge('تغيير كلمة المرور مطلوب'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.briefcase_fill,
                                size: 16,
                                color: kGold.withValues(alpha: .95)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                [role, if (division.isNotEmpty) division]
                                    .join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .92),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.at,
                                size: 15,
                                color:
                                    Colors.white.withValues(alpha: .66)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${user.username}'
                                '${user.phone.trim().isEmpty ? '' : ' · ${user.phone.trim()}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: .74),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: avatar),
                          const SizedBox(height: 16),
                          info,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar,
                        const SizedBox(width: 22),
                        Expanded(child: info),
                      ],
                    );
                  }),
                  Divider(
                    color: Colors.white.withValues(alpha: .16),
                    height: 26,
                    thickness: .8,
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _GlassPill(
                        icon: CupertinoIcons.doc_text,
                        label: 'محاضري',
                        value: '$reportsCount',
                      ),
                      _GlassPill(
                        icon: CupertinoIcons.clock,
                        label: 'قيد الإنجاز',
                        value: '$inProgress',
                        accent: inProgress > 0 ? kGold : null,
                      ),
                      _GlassPill(
                        icon: CupertinoIcons.checkmark_seal,
                        label: 'معتمدة أو مقفلة',
                        value: '$completed',
                      ),
                      _GlassPill(
                        icon: CupertinoIcons.money_dollar,
                        label: 'إجمالي الغرامات',
                        value: money(fines),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
        child: SizedBox(width: size, height: size),
      );
}

/// شريحة زجاجية داعمة داخل رأس الملف.
class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const _GlassPill({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Colors.white;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: .96)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// عنوان قسم صغير بأيقونة متدرجة.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String accent;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent == 'gold' ? kGold : kPrimary2;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                color.withValues(alpha: .28),
                color.withValues(alpha: .10),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة معلومة أنيقة (صف لافتة أيقونة).
/// بطاقة قسم قابلة للطي/الفتح مع تأشير واضح وزر سحب.
class _CollapsibleSection extends StatefulWidget {
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> children;
  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: '${_open ? 'طي' : 'فتح'} ${widget.title}',
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 8),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [
                          widget.accent.withValues(alpha: .26),
                          widget.accent.withValues(alpha: .08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, size: 20, color: widget.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: context.p.muted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOutCubic,
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 19,
                      color: context.p.muted,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// بطاقة إحصائية أنيقة في سطر واحد.
class _ProfileStatsRow extends StatelessWidget {
  final int reportsCount, inProgress, completed, cancelled;
  final num fines;
  const _ProfileStatsRow({
    required this.reportsCount,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
    required this.fines,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.p.isDark;
    final stats = <_Stat>[
      _Stat('محاضري', '$reportsCount', CupertinoIcons.doc_text, kPrimary2),
      _Stat('قيد الإنجاز', '$inProgress', CupertinoIcons.clock_fill, kGold,
          warn: inProgress > 0),
      _Stat('معتمدة أو مقفلة', '$completed', CupertinoIcons.checkmark_seal_fill,
          kPrimary2),
      _Stat('ملغاة', '$cancelled', CupertinoIcons.xmark_circle_fill, kRed,
          warn: cancelled > 0),
      _Stat('إجمالي الغرامات', money(fines), CupertinoIcons.money_dollar,
          kGold),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final stat in stats)
          SizedBox(
            width: 216,
            height: 128,
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: [
                              stat.color.withValues(alpha: .24),
                              stat.color.withValues(alpha: .08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(stat.icon, size: 21, color: stat.color),
                      ),
                      const Spacer(),
                      if (stat.warn && stat.value != '0')
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: kGold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: kGold.withValues(alpha: .5),
                                  blurRadius: 6),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    stat.value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stat.label,
                    style: TextStyle(
                      color: dark ? context.p.muted : const Color(0xFF6E6E73),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool warn;
  const _Stat(this.label, this.value, this.icon, this.color,
      {this.warn = false});
}

/// قسم المحاضر التي أنشأها المستخدم.
class _ReportsSection extends StatelessWidget {
  final List<Report> reports;
  final AppStore store;
  final AppUser user;
  final bool isSelf;
  const _ReportsSection({
    required this.reports,
    required this.store,
    required this.user,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: CupertinoIcons.doc_text,
          title: isSelf ? 'محاضر قمت بإنشائها' : 'محاضر من إنشاء ${user.name}',
          accent: 'teal',
        ),
        const SizedBox(height: 4),
        Text(
          reports.isEmpty
              ? 'لم يُنشئ هذا المستخدم أي محاضر بعد.'
              : '${reports.length} محضر، مرتبة من الأحدث إلى الأقدم.',
          style: TextStyle(color: context.p.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GridTable(
          heads: const [
            'الرقم',
            'المنشأة',
            'التاريخ',
            'قيمة الضبط',
            'الحالة',
            '',
          ],
          flex: const [1, 3, 2, 2, 2, 1],
          rows: [
            for (final report in reports)
              [
                cellText(
                  report.serial.isEmpty ? '—' : report.serial,
                  bold: true,
                ),
                cellText(store.tp(report.taxpayerId)?.name ?? ''),
                cellText(fmtDate(report.date)),
                cellText(money(report.total)),
                StatusBadge(report.status),
                TextButton(
                  onPressed: () => context.go('/reports/${report.id}'),
                  child: const Text('عرض'),
                ),
              ],
          ],
          empty: 'لا توجد محاضر أنشأها هذا المستخدم',
        ),
      ],
    );
  }
}

/// بطاقة معلومة فردية بأيقونة ولون.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return InfoTile(
      icon: icon,
      label: label,
      value: empty ? '—' : value,
      accent: accent ?? kPrimary2,
    );
  }
}

/// صورة المستخدم الشخصية مع زر تغيير الصورة.
class _ProfileAvatar extends StatefulWidget {
  final AppStore store;
  final AppUser user;
  final bool editable;

  const _ProfileAvatar({
    required this.store,
    required this.user,
    required this.editable,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool uploading = false;

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        toast(context, 'تعذر قراءة الصورة المختارة');
        return;
      }

      final extension = file.extension?.toLowerCase() ?? '';
      final mime = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'application/octet-stream',
      };

      setState(() => uploading = true);
      final error = await widget.store.setUserPhoto(
        widget.user.id,
        name: file.name,
        mime: mime,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => uploading = false);
      if (error != null) {
        toast(context, error);
        return;
      }
      toast(context, 'تم تحديث الصورة الشخصية');
    } catch (error) {
      if (!mounted) return;
      setState(() => uploading = false);
      toast(context, 'تعذر تحديث الصورة الشخصية: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.user.name.trim().isEmpty
        ? '؟'
        : widget.user.name.trim().substring(0, 1);
    final status = widget.user.status;
    final statusColor = switch (status) {
      'active' => const Color(0xFF34C759),
      'disabled' => kGold,
      _ => kRed,
    };
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Colors.white.withValues(alpha: .95),
                  Colors.white.withValues(alpha: .35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kGold.withValues(alpha: .85),
                    width: 2.4,
                  ),
                ),
                child: FutureBuilder<Uint8List?>(
                  key: ValueKey(widget.user.photoId),
                  future: widget.user.photoId.isEmpty
                      ? null
                      : widget.store.attachmentBytes(widget.user.photoId),
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    return ClipOval(
                      child: bytes == null
                          ? DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentDirectional.topStart,
                                  end: AlignmentDirectional.bottomEnd,
                                  colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            )
                          : Image.memory(bytes, fit: BoxFit.cover),
                    );
                  },
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 2,
            bottom: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
          if (widget.editable)
            PositionedDirectional(
              end: -4,
              bottom: -6,
              child: IconButton.filled(
                tooltip: 'تعديل الصورة الشخصية',
                onPressed: uploading ? null : _pickPhoto,
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(CupertinoIcons.camera_fill, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(42, 42),
                  elevation: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
