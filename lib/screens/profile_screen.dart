import 'dart:typed_data';

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
    final cancelled = reports.where((report) => report.status == 'ملغى').length;
    final fines = reports
        .where((report) => report.status != 'ملغى')
        .fold<num>(0, (sum, report) => sum + report.total);
    final manager = _findUser(st, user.managerId);
    final permissions = _permissionsFor(st, user);

    return PageBody(children: [
      if (userId != null)
        BackBreadcrumb(
          parent: 'إدارة المستخدمين',
          current: user.name,
          fallbackLocation: '/users',
        ),
      PageHeader(
        isSelf ? 'ملفي الشخصي' : 'ملف المستخدم',
        subtitle: 'بيانات الحساب والصلاحيات والمحاضر التي أنشأها ${user.name}',
        actions: [
          if (isSelf)
            OutlinedButton.icon(
              onPressed: () => context.go('/change-password'),
              icon: const Icon(CupertinoIcons.lock_rotation),
              label: const Text('تغيير كلمة المرور'),
            ),
        ],
      ),
      AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileAvatar(store: st, user: user),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      StatusBadge(_statusLabel(user.status)),
                      if (user.passwordChangeRequired)
                        const StatusBadge('تغيير كلمة المرور مطلوب'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      kRoles[user.role] ?? user.role,
                      if (user.division.isNotEmpty)
                        kDivisionNames[user.division] ??
                            kDivisions[user.division] ??
                            user.division,
                    ].join(' · '),
                    style: TextStyle(
                      color: context.p.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
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
      ),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 270,
          child: StatCard(
            'المحاضر المنشأة',
            '${reports.length}',
            CupertinoIcons.doc_text,
          ),
        ),
        SizedBox(
          width: 270,
          child: StatCard(
            'قيد الإنجاز',
            '$inProgress',
            CupertinoIcons.clock,
            warn: inProgress > 0,
          ),
        ),
        SizedBox(
          width: 270,
          child: StatCard(
            'معتمدة أو مقفلة',
            '$completed',
            CupertinoIcons.checkmark_seal,
          ),
        ),
        SizedBox(
          width: 270,
          child: StatCard(
            'ملغاة',
            '$cancelled',
            CupertinoIcons.xmark_circle,
            warn: cancelled > 0,
          ),
        ),
        SizedBox(
          width: 270,
          child: StatCard(
            'إجمالي الغرامات',
            money(fines),
            CupertinoIcons.money_dollar,
          ),
        ),
      ]),
      AppCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final primary = <Widget>[
              kv('الاسم الكامل', user.name),
              kv('اسم المستخدم', user.username),
              kv('رقم الموبايل', user.phone),
              kv('الدور', kRoles[user.role] ?? user.role),
              kv(
                'الشعبة',
                kDivisionNames[user.division] ??
                    kDivisions[user.division] ??
                    user.division,
              ),
              kv('الحالة', _statusLabel(user.status)),
            ];
            final secondary = <Widget>[
              kv('المسؤول المباشر', manager?.name ?? ''),
              kv('تاريخ إنشاء الحساب', _stamp(user.createdAt)),
              kv('أنشئ من قبل', user.createdBy),
              if (user.closedAt.isNotEmpty)
                kv('تاريخ الإغلاق', _stamp(user.closedAt)),
              if (user.closedBy.isNotEmpty) kv('أغلقه', user.closedBy),
              if (user.closureReason.isNotEmpty)
                kv('سبب الإغلاق', user.closureReason),
            ];
            if (constraints.maxWidth < 720) {
              return Column(children: [...primary, ...secondary]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: primary)),
                const SizedBox(width: 28),
                Expanded(child: Column(children: secondary)),
              ],
            );
          },
        ),
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(CupertinoIcons.lock_shield,
                  size: 18, color: context.p.muted),
              const SizedBox(width: 8),
              Text(
                'الصلاحيات (${permissions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (permissions.isEmpty)
              Text(
                'لا توجد صلاحيات مسندة لهذا الحساب.',
                style: TextStyle(color: context.p.muted),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final permission in permissions)
                    Chip(
                      label: Text(kPerms[permission] ?? permission),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
          ],
        ),
      ),
      PageHeader(
        'المحاضر التي أنشأها',
        subtitle: reports.isEmpty
            ? 'لم يُنشئ هذا المستخدم أي محاضر بعد.'
            : '${reports.length} محضر، مرتبة من الأحدث إلى الأقدم.',
      ),
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
              cellText(st.tp(report.taxpayerId)?.name ?? ''),
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
    return date == null ? '' : fmtDT(date);
  }
}

class _ProfileAvatar extends StatelessWidget {
  final AppStore store;
  final AppUser user;

  const _ProfileAvatar({required this.store, required this.user});

  @override
  Widget build(BuildContext context) {
    final initial =
        user.name.trim().isEmpty ? '؟' : user.name.trim().substring(0, 1);
    return FutureBuilder<Uint8List?>(
      key: ValueKey(user.photoId),
      future: user.photoId.isEmpty ? null : store.attachmentBytes(user.photoId),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.p.border, width: 1.5),
          ),
          child: ClipOval(
            child: bytes == null
                ? ColoredBox(
                    color: kPrimary.withValues(alpha: .12),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
