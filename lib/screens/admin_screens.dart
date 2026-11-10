import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirmation = TextEditingController();
  String? error;
  bool saving = false;
  bool showCurrent = false, showNext = false, showConfirmation = false;

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (next.text != confirmation.text) {
      setState(() => error = 'كلمتا المرور الجديدتان غير متطابقتين');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    String? result;
    try {
      result = await context.read<AppStore>().changeOwnPassword(
            currentPassword: current.text,
            newPassword: next.text,
          );
    } catch (saveError) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = 'تعذر حفظ كلمة المرور: $saveError';
      });
      return;
    }
    if (!mounted) return;
    if (result != null) {
      setState(() {
        saving = false;
        error = result;
      });
      return;
    }
    context.go('/');
    toast(context, 'تم تغيير كلمة المرور');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final requiredChange = store.me?.passwordChangeRequired == true;
    Widget passwordField({
      required TextEditingController controller,
      required String label,
      required IconData icon,
      required bool visible,
      required VoidCallback onToggle,
      Iterable<String>? autofillHints,
      VoidCallback? onSubmitted,
    }) =>
        TextField(
          controller: controller,
          obscureText: !visible,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 19),
            suffixIcon: IconButton(
              tooltip: visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
              onPressed: onToggle,
              icon: Icon(
                visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                size: 19,
              ),
            ),
            filled: true,
            fillColor: context.p.field,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.p.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.p.border),
            ),
          ),
        );

    Widget guidance = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.checkmark_shield_fill,
              color: kPrimary2, size: 25),
          const SizedBox(height: 12),
          const Text(
            'نصائح لكلمة مرور آمنة',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (final tip in [
            'استخدم 6 أحرف على الأقل.',
            'اختر كلمة مرور يصعب تخمينها.',
            'لا تشارك كلمة المرور مع الآخرين.',
          ])
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 16, color: kPrimary2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        color: context.p.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: context.p.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.p.bg, context.p.surfaceAlt],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [kPrimary, Color(0xFF2E8C7E)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: .2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                requiredChange ? 'إجراء مطلوب' : 'أمان الحساب',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!requiredChange)
                              TextButton.icon(
                                onPressed: () => context.go('/profile'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: .12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  CupertinoIcons.arrow_right,
                                  size: 17,
                                ),
                                label: const Text('الملف الشخصي'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requiredChange
                                        ? 'أنشئ كلمة مرور جديدة'
                                        : 'حافظ على أمان حسابك',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    requiredChange
                                        ? 'هذه كلمة مرور مؤقتة. غيّرها للمتابعة إلى النظام.'
                                        : 'أدخل كلمة المرور الحالية ثم اختر كلمة مرور جديدة.',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .82),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .13),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .25),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.lock_shield_fill,
                                color: Colors.white,
                                size: 35,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final form = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'بيانات كلمة المرور',
                              style: TextStyle(
                                color: context.p.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            passwordField(
                              controller: current,
                              label: 'كلمة المرور الحالية',
                              icon: CupertinoIcons.lock,
                              visible: showCurrent,
                              onToggle: () =>
                                  setState(() => showCurrent = !showCurrent),
                              autofillHints: const [AutofillHints.password],
                            ),
                            const SizedBox(height: 13),
                            passwordField(
                              controller: next,
                              label: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                              icon: CupertinoIcons.lock_fill,
                              visible: showNext,
                              onToggle: () =>
                                  setState(() => showNext = !showNext),
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 13),
                            passwordField(
                              controller: confirmation,
                              label: 'تأكيد كلمة المرور الجديدة',
                              icon: CupertinoIcons.checkmark_shield,
                              visible: showConfirmation,
                              onToggle: () => setState(
                                  () => showConfirmation = !showConfirmation),
                              onSubmitted: saving ? null : _save,
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kRed.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: kRed.withValues(alpha: .22)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.exclamationmark_circle,
                                      color: kRed,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                            color: kRed, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: saving ? null : _save,
                                icon: saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(
                                        CupertinoIcons.checkmark_shield_fill),
                                label: Text(
                                    saving ? 'جارٍ الحفظ…' : 'حفظ كلمة المرور'),
                              ),
                            ),
                            Align(
                              child: TextButton.icon(
                                onPressed: saving
                                    ? null
                                    : () {
                                        store.logout();
                                        context.go('/login');
                                      },
                                icon: const Icon(
                                    CupertinoIcons.square_arrow_right),
                                label: const Text('تسجيل الخروج'),
                              ),
                            ),
                          ],
                        );

                        if (constraints.maxWidth < 680) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              form,
                              const SizedBox(height: 20),
                              guidance,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: form),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: guidance),
                          ],
                        );
                      },
                    ),
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

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class ActiveUsersScreen extends StatelessWidget {
  const ActiveUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppStore>().me;
    return PageBody(children: [
      const PageHeader(
        'المستخدمون الفعّالون حاليًا',
        subtitle:
            'يعرض هذا الوضع التجريبي الجلسة على هذا الجهاز فقط. ستظهر جلسات بقية الأجهزة عند ربط الخادم.',
      ),
      AppCard(
        child: Row(children: [
          const Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
              color: Color(0xFF2F6B4A), size: 24),
          const SizedBox(width: 10),
          Text(
            'المستخدمون المسجّلون على هذا الجهاز: ${user == null ? 0 : 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ]),
      ),
      GridTable(
        heads: const [
          'الاسم الكامل',
          'اسم المستخدم',
          'الدور',
          'الشعبة',
          'الحالة'
        ],
        flex: const [3, 2, 3, 2, 2],
        rows: [
          if (user != null)
            [
              cellText(user.name, bold: true),
              cellText(user.username),
              cellText(kRoles[user.role] ?? user.role),
              cellText(kDivisionNames[user.division] ?? '—'),
              const StatusBadge('فعال'),
            ],
        ],
      ),
    ]);
  }
}

class _UsersScreenState extends State<UsersScreen> {
  String role = '', div = '';
  String status = '';
  String view = 'cards';
  final query = TextEditingController();

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _edit(AppStore st, AppUser user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditUserDialog(store: st, user: user),
    );
  }

  Future<void> _showAccountHistory(AppUser user) async {
    AppUser? findUser(String id) {
      for (final candidate in context.read<AppStore>().users) {
        if (candidate.id == id) return candidate;
      }
      return null;
    }

    final manager = findUser(user.managerId);
    final creatorName = user.createdBy.trim().isEmpty
        ? 'غير محدد'
        : user.createdBy.trim() == 'النظام'
            ? 'النظام (بذرة أولية)'
            : user.createdBy;
    final statusColor = switch (user.status) {
      'closed' => kRed,
      'disabled' => kGold,
      _ => const Color(0xFF34C759),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.p.surface,
        shape:
            ContinuousRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
          child: Row(
            children: [
              _UserAvatar(
                store: context.read<AppStore>(),
                user: user,
                radius: 32,
                statusColor: statusColor,
                borderColor: Colors.white.withValues(alpha: .55),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .74),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _GlassChip(
                            icon: CupertinoIcons.briefcase_fill,
                            label: kRoles[user.role] ?? user.role),
                        if (user.division.isNotEmpty)
                          _GlassChip(
                              icon: CupertinoIcons.building_2_fill,
                              label: kDivisionNames[user.division] ??
                                  kDivisions[user.division] ??
                                  user.division),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440, maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistorySection(
                  icon: CupertinoIcons.person_crop_rectangle,
                  title: 'بيانات الحساب',
                  accent: kPrimary2,
                  rows: [
                    _InfoRow(label: 'الاسم الكامل', value: user.name),
                    _InfoRow(label: 'اسم المستخدم', value: user.username),
                    _InfoRow(
                        label: 'رقم الموبايل',
                        value: user.phone.isEmpty ? '—' : user.phone),
                    _InfoRow(
                        label: 'الدور',
                        value: kRoles[user.role] ?? user.role),
                    if (user.division.isNotEmpty)
                      _InfoRow(
                          label: 'الشعبة',
                          value: kDivisionNames[user.division] ??
                              kDivisions[user.division] ??
                              user.division),
                    _InfoRow(
                        label: 'المسؤول المباشر',
                        value: manager?.name ?? '—'),
                  ],
                ),
                const SizedBox(height: 12),
                _HistorySection(
                  icon: CupertinoIcons.calendar_badge_plus,
                  title: 'الإنشاء والإغلاق',
                  accent: kGold,
                  rows: [
                    _InfoRow(
                      label: 'تاريخ الإنشاء',
                      value: _stampDate(user.createdAt),
                      icon: CupertinoIcons.calendar_circle,
                    ),
                    _InfoRow(
                      label: 'وقت الإنشاء',
                      value: _stampTime(user.createdAt),
                      icon: CupertinoIcons.clock,
                    ),
                    _InfoRow(
                      label: 'أنشئ من قبل',
                      value: creatorName,
                      icon: CupertinoIcons.person_badge_plus,
                    ),
                    if (user.status == 'closed') ...[
                      _InfoRow(
                        label: 'تاريخ الإغلاق',
                        value: _stamp12(user.closedAt),
                        icon: CupertinoIcons.lock_fill,
                        accent: kRed,
                      ),
                      if (user.closedBy.isNotEmpty)
                        _InfoRow(
                          label: 'أغلقه',
                          value: user.closedBy,
                          icon: CupertinoIcons.xmark_circle_fill,
                          accent: kRed,
                        ),
                      if (user.closureReason.isNotEmpty)
                        _InfoRow(
                          label: 'سبب الإغلاق',
                          value: user.closureReason,
                          icon: CupertinoIcons.exclamationmark_circle,
                          accent: kRed,
                        ),
                    ],
                  ],
                ),
                if (user.statusPeriods.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _HistorySection(
                    icon: CupertinoIcons.clock,
                    title: 'سجل التعطيل وإعادة التفعيل',
                    accent: kGold,
                    rows: [
                      for (var index = 0;
                          index < user.statusPeriods.length;
                          index++)
                        _StatusPeriodRow(
                          index: index + 1,
                          period: user.statusPeriods[index],
                        ),
                    ],
                  ),
                ],
                if (user.passwordChangeRequired) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: kGold.withValues(
                          alpha: context.p.isDark ? .16 : .10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kGold.withValues(alpha: .35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                            size: 16, color: kGold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'كلمة مرور مؤقتة — التغيير مطلوب عند الدخول التالي.',
                            style: TextStyle(
                              color: context.p.isDark
                                  ? const Color(0xFFE9CEA8)
                                  : const Color(0xFF6B4A0C),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.go('/users/${user.id}/profile');
            },
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            icon: const Icon(CupertinoIcons.person_crop_circle_fill, size: 18),
            label: const Text('عرض الملف الشخصي'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeUser(AppStore st, AppUser user) async {
    final credentials = await showDialog<({String reason, String password})>(
      context: context,
      builder: (_) => const _CloseAccountDialog(),
    );
    if (credentials == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التأكيد الثاني للإغلاق النهائي'),
        content: Text(
          'هل أنت متأكد من إغلاق حساب «${user.name}» نهائيًا؟ '
          'لن يمكن إعادة تفعيله، وستبقى سجلاته محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('أؤكد الإغلاق النهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await st.closeUser(
        user.id,
        credentials.reason,
        adminPassword: credentials.password,
      );
      if (mounted) {
        toast(context, result ?? 'أُغلق الحساب نهائيًا وحُفظت جميع سجلاته');
      }
    } catch (error) {
      if (mounted) toast(context, 'تعذر حفظ إغلاق الحساب: $error');
    }
  }

  Future<void> _add(AppStore st) async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        un = TextEditingController(),
        pw = TextEditingController();
    PickedUserPhoto? selectedPhoto;
    final requiredAccount = st.nextRequiredLeadershipAccount;
    var r = requiredAccount?.role ?? 'user',
        d = requiredAccount?.division ?? 'field',
        mgr = '';
    String? err;
    bool roleAvailable(String role, String division) => !st.users.any(
          (user) =>
              user.active &&
              user.role == role &&
              (!isDivisionHeadRole(role) || user.division == division),
        );
    String? managerRole(String role, String division) => switch (role) {
          'sectionHead' || 'infoSectionHead' => 'financeDirector',
          'deptHead' => 'sectionHead',
          'fieldHead' || 'officeHead' || 'archiveHead' => 'deptHead',
          'monitor' || 'user' => headRoleForDivision(division),
          _ => null,
        };
    List<AppUser> managersFor(String role, String division) {
      final expectedRole = managerRole(role, division);
      if (expectedRole == null) return [];
      return st.users
          .where((user) =>
              user.active &&
              user.role == expectedRole &&
              (!isDivisionHeadRole(expectedRole) || user.division == division))
          .toList();
    }

    List<String> rolesForDivision(String division) {
      if (requiredAccount != null) {
        return division == requiredAccount.division
            ? [requiredAccount.role]
            : [];
      }
      if (division.isEmpty) {
        return [
          if (roleAvailable('financeDirector', '')) 'financeDirector',
          if (roleAvailable('sectionHead', '') &&
              managersFor('sectionHead', '').isNotEmpty)
            'sectionHead',
          if (roleAvailable('infoSectionHead', '') &&
              managersFor('infoSectionHead', '').isNotEmpty)
            'infoSectionHead',
          if (roleAvailable('deptHead', '') &&
              managersFor('deptHead', '').isNotEmpty)
            'deptHead',
          'sysadmin',
        ];
      }
      return [
        if (roleAvailable('financeDirector', '')) 'financeDirector',
        if (roleAvailable('sectionHead', '') &&
            managersFor('sectionHead', '').isNotEmpty)
          'sectionHead',
        if (roleAvailable('infoSectionHead', '') &&
            managersFor('infoSectionHead', '').isNotEmpty)
          'infoSectionHead',
        if (roleAvailable('deptHead', '') &&
            managersFor('deptHead', '').isNotEmpty)
          'deptHead',
        if (roleAvailable(headRoleForDivision(division)!, division) &&
            managersFor(headRoleForDivision(division)!, division).isNotEmpty)
          headRoleForDivision(division)!,
        if (division == 'field' && managersFor('monitor', division).isNotEmpty)
          'monitor',
        'user',
        'sysadmin',
      ];
    }

    void chooseDefaultManager() {
      final candidates = managersFor(r, d);
      mgr = candidates.length == 1 ? candidates.first.id : '';
    }

    String managerLabel(AppUser manager) {
      return '${manager.name} (${kRoles[manager.role]})';
    }

    Widget directManagerField() {
      final candidates = managersFor(r, d);
      final value = candidates.length == 1
          ? managerLabel(candidates.first)
          : 'لا يوجد رئيس شعبة مفعّل لهذه الشعبة';
      return Expanded(
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'المسؤول المباشر',
            enabled: false,
          ),
          child: Text(value),
        ),
      );
    }

    chooseDefaultManager();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('إنشاء حساب'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _UserPhotoPicker(
                  store: st,
                  onChanged: (photo) => set(() => selectedPhoto = photo),
                ),
                const SizedBox(height: 10),
                rowOf([
                  Field('الاسم الكامل', ctl: name),
                  Field('رقم الموبايل', ctl: phone, type: TextInputType.phone),
                ]),
                const SizedBox(height: 10),
                rowOf([
                  Field('اسم المستخدم', ctl: un),
                ]),
                const SizedBox(height: 10),
                rowOf([Field('كلمة مرور مؤقتة (6 أحرف على الأقل)', ctl: pw)]),
                const SizedBox(height: 10),
                if (requiredAccount != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'أكمل إنشاء الحسابات الإدارية بالترتيب قبل إضافة الموظفين والمراقبين.',
                      style: TextStyle(color: context.p.muted),
                    ),
                  ),
                rowOf([
                  Drop(
                    'الدور',
                    r,
                    {
                    for (final role in rolesForDivision(d)) role: kRoles[role]!,
                    },
                    (v) => set(() {
                      r = v;
                      if (isDivisionHeadRole(v)) {
                        d = divisionForHeadRole(v)!;
                      } else if (!['monitor', 'user'].contains(v)) {
                        d = '';
                    } else if (d.isEmpty || (v == 'monitor' && d != 'field')) {
                        d = 'field';
                      }
                      chooseDefaultManager();
                    }),
                  ),
                if (requiredAccount == null && ['monitor', 'user'].contains(r))
                    Drop(
                      'الشعبة',
                      d,
                      kDivisionNames,
                      (v) => set(() {
                        d = v;
                        if (!rolesForDivision(d).contains(r)) {
                          r = d.isEmpty
                              ? rolesForDivision(d).first
                              : (rolesForDivision(d).contains('user')
                                  ? 'user'
                                  : rolesForDivision(d).first);
                        }
                        chooseDefaultManager();
                      }),
                      enabled: ['monitor', 'user'].contains(r),
                    ),
                ]),
                if (managerRole(r, d) != null) ...[
                  const SizedBox(height: 10),
                  rowOf([
                    if (['monitor', 'user'].contains(r))
                      directManagerField()
                    else
                      Drop(
                        'المسؤول المباشر',
                        mgr,
                        {
                        if (managersFor(r, d).isEmpty) '': 'لا يوجد مسؤول متاح',
                          for (final u in managersFor(r, d))
                            u.id: '${u.name} (${kRoles[u.role]})',
                        },
                        (v) => set(() => mgr = v),
                      ),
                  ]),
                ],
                if (err != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err!, style: const TextStyle(color: kRed))),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty ||
                    un.text.trim().isEmpty ||
                    pw.text.length < 6) {
                  set(() => err = 'أكمل الحقول. كلمة المرور 6 أحرف على الأقل');
                  return;
                }
                if (managerRole(r, d) != null && mgr.isEmpty) {
                  set(() =>
                      err = 'لا يوجد مسؤول مباشر مناسب لهذا الدور والشعبة');
                  return;
                }
                final account = AppUser(
                  id: newId(),
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  username: un.text.trim(),
                  passHash: '',
                  role: r,
                  division: d,
                  managerId: mgr,
                );
                final e = st.addUser(account, pw.text);
                if (e != null) {
                  set(() => err = e);
                } else {
                  if (selectedPhoto != null) {
                    try {
                      final photoError = await st.setUserPhoto(
                        account.id,
                        name: selectedPhoto!.name,
                        mime: selectedPhoto!.mime,
                        bytes: selectedPhoto!.bytes,
                      );
                      if (photoError != null && ctx.mounted) {
                        toast(ctx, 'تم إنشاء الحساب لكن تعذر حفظ الصورة: $photoError');
                      }
                    } catch (error) {
                      if (ctx.mounted) {
                        toast(ctx, 'تم إنشاء الحساب لكن تعذر حفظ الصورة: $error');
                      }
                    }
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  String _managerNameOf(AppUser user) {
    for (final candidate in context.read<AppStore>().users) {
      if (candidate.id == user.managerId) {
        return candidate.name;
      }
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final normalizedQuery = normAr(query.text.trim());
    final list = st.users
        .where((u) =>
            (role.isEmpty || u.role == role) &&
            (div.isEmpty || u.division == div) &&
            (status.isEmpty || u.status == status) &&
            (normalizedQuery.isEmpty ||
                normAr(
                  '${u.name} ${u.username} ${kRoles[u.role]} '
                  '${kDivisionNames[u.division] ?? ''} ${_managerNameOf(u)}',
                ).contains(normalizedQuery)))
        .toList();
    final activeCount = st.users.where((u) => u.status == 'active').length;
    final disabledCount = st.users.where((u) => u.status == 'disabled').length;
    final closedCount = st.users.where((u) => u.status == 'closed').length;

    return PageBody(children: [
      PageHeader('إدارة المستخدمين',
          subtitle:
              'الفريق بالكامل في مكان واحد — عرض وإنشاء وتعديل وإغلاق الحسابات',
          actions: [
            FilledButton.icon(
              onPressed: () => _add(st),
              icon: const Icon(CupertinoIcons.person_add, size: 18),
              label: const Text('إنشاء حساب'),
            ),
          ]),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _UserStat(
              label: 'إجمالي الحسابات',
              value: '${st.users.length}',
              icon: CupertinoIcons.person_2_fill,
              color: kPrimary2),
          _UserStat(
              label: 'فعالة',
              value: '$activeCount',
              icon: CupertinoIcons.checkmark_seal_fill,
              color: const Color(0xFF34C759)),
          _UserStat(
              label: 'معطلة مؤقتًا',
              value: '$disabledCount',
              icon: CupertinoIcons.pause_circle_fill,
              color: kGold),
          _UserStat(
              label: 'مغلقة نهائيًا',
              value: '$closedCount',
              icon: CupertinoIcons.lock_fill,
              color: kRed),
        ],
      ),
      AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [kPrimary2, Color(0xFF17574E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.search,
                    size: 19, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'البحث والفلاتر',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Seg(const ['بطاقات', 'جدول'], view == 'cards' ? 0 : 1,
                  (i) => setState(() => view = i == 0 ? 'cards' : 'table')),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: query,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المستخدم أو اسمه الكامل…',
                prefixIcon: const Icon(CupertinoIcons.search,
                    size: 20),
                suffixIcon: query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill,
                            size: 19),
                        onPressed: () {
                          query.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: context.p.surfaceAlt,
                contentPadding:
                    const EdgeInsetsDirectional.fromSTEB(16, 17, 16, 17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: kPrimary2.withValues(alpha: .6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _IconDropdown(
                  icon: CupertinoIcons.briefcase_fill,
                  label: 'الدور',
                  value: role,
                  options: {'': 'الكل', ...kRoles},
                  onChanged: (v) => setState(() => role = v),
                ),
                _IconDropdown(
                  icon: CupertinoIcons.building_2_fill,
                  label: 'الشعبة',
                  value: div,
                  options: {'': 'الكل', ...kDivisionNames},
                  onChanged: (v) => setState(() => div = v),
                ),
                _IconDropdown(
                  icon: CupertinoIcons.lock_fill,
                  label: 'الحالة',
                  value: status,
                  options: const {
                    '': 'كل الحالات',
                    'active': 'فعال',
                    'disabled': 'معطل مؤقتًا',
                    'closed': 'مغلق نهائيًا',
                  },
                  onChanged: (v) => setState(() => status = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'المعروض: ${list.length} من أصل ${st.users.length} حساب · فعالة: $activeCount · معطلة: $disabledCount · مغلقة: $closedCount',
                style: TextStyle(color: context.p.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      if (view == 'table' && list.isNotEmpty)
        GridTable(
          heads: const [
            'المستخدم',
            'اسم المستخدم',
            'الدور',
            'الشعبة',
            'المسؤول',
            'تاريخ الإنشاء',
            'وقت الإنشاء',
            'الحالة',
            '',
          ],
          flex: const [2, 2, 2, 2, 2, 2, 2, 2, 2],
          rows: [
            for (final u in list)
              [
                cellText(u.name, bold: true),
                cellText(u.username),
                cellText(kRoles[u.role] ?? u.role),
                cellText(kDivisionNames[u.division] ??
                    kDivisions[u.division] ??
                    u.division),
                cellText(_managerNameOf(u)),
                cellText(_stampDate(u.createdAt)),
                cellText(_stampTime(u.createdAt)),
                StatusBadge(_userStatusLabel(u.status)),
                Wrap(spacing: 2, children: [
                  IconButton(
                    tooltip: 'صفحة المستخدم',
                    onPressed: () => context.go('/users/${u.id}/profile'),
                    icon: const Icon(CupertinoIcons.person_crop_circle_fill,
                        size: 20, color: kPrimary2),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'تفاصيل وسجل الحساب',
                    onPressed: () => _showAccountHistory(u),
                    icon: const Icon(CupertinoIcons.info,
                        size: 20, color: kGold),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (u.status != 'closed')
                    IconButton(
                      tooltip: 'تعديل المستخدم',
                      onPressed: () => _edit(st, u),
                      icon: const Icon(CupertinoIcons.pencil,
                          size: 17, color: kPrimary2),
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ],
          ],
        )
      else if (list.isEmpty)
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                Icon(CupertinoIcons.question_circle,
                    size: 46, color: context.p.muted),
                const SizedBox(height: 10),
                const Text(
                  'لا توجد حسابات مطابقة لهذه الفلاتر',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'جرّب مسح البحث أو تغيير الفلاتر.',
                  style: TextStyle(color: context.p.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        )
      else
        for (final u in list)
          _UserCard(
            store: st,
            user: u,
            managerName: _managerNameOf(u),
            onHistory: () => _showAccountHistory(u),
            onEdit: u.status == 'closed' ? null : () => _edit(st, u),
            onToggleActive: u.id != st.me?.id && u.status != 'closed'
                ? () {
                    final error = st.setUserActive(u, !u.active);
                    if (error != null) toast(context, error);
                  }
                : null,
            onClose: u.id != st.me?.id && u.status != 'closed'
                ? () => _closeUser(st, u)
                : null,
          ),
    ]);

  }
}

class _CloseAccountDialog extends StatefulWidget {
  const _CloseAccountDialog();

  @override
  State<_CloseAccountDialog> createState() => _CloseAccountDialogState();
}

class _CloseAccountDialogState extends State<_CloseAccountDialog> {
  final reason = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    reason.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('التأكيد الأول: بيانات الإغلاق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل سبب الإغلاق وكلمة مرور مدير النظام للمتابعة. ستبقى جميع مدخلات الحساب وسجلاته محفوظة.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'سبب الإغلاق'),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'كلمة مرور مدير النظام'),
              onChanged: (_) => setState(() => error = null),
              onSubmitted: (_) => setState(() => error = null),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: kRed)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty || password.text.isEmpty) {
                setState(() => error = reason.text.trim().isEmpty
                    ? 'أدخل سبب إغلاق الحساب'
                    : 'أدخل كلمة مرور مدير النظام');
                return;
              }
              Navigator.pop(
                context,
                (reason: reason.text.trim(), password: password.text),
              );
            },
            child: const Text('متابعة إلى التأكيد الثاني'),
          ),
        ],
      );
}

String _userPhotoMimeFor(String name) =>
    switch (name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'application/octet-stream',
    };

class PickedUserPhoto {
  final String name;
  final String mime;
  final Uint8List bytes;

  const PickedUserPhoto({
    required this.name,
    required this.mime,
    required this.bytes,
  });
}

class _UserPhotoPicker extends StatefulWidget {
  final AppStore store;
  final String photoId;
  final ValueChanged<PickedUserPhoto?> onChanged;

  const _UserPhotoPicker({
    required this.store,
    required this.onChanged,
    this.photoId = '',
  });

  @override
  State<_UserPhotoPicker> createState() => _UserPhotoPickerState();
}

class _UserPhotoPickerState extends State<_UserPhotoPicker> {
  PickedUserPhoto? selectedPhoto;

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
      final error = widget.store.attachmentError(bytes);
      if (error != null) {
        toast(context, error);
        return;
      }
      final photo = PickedUserPhoto(
        name: file.name,
        mime: _userPhotoMimeFor(file.name),
        bytes: bytes,
      );
      setState(() => selectedPhoto = photo);
      widget.onChanged(photo);
    } catch (error) {
      if (mounted) toast(context, 'تعذر اختيار صورة المستخدم: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          FutureBuilder<Uint8List?>(
            key: ValueKey(widget.photoId),
            future: widget.photoId.isEmpty
                ? null
                : widget.store.attachmentBytes(widget.photoId),
            builder: (context, snapshot) {
              final bytes = selectedPhoto?.bytes ?? snapshot.data;
              return CircleAvatar(
                radius: 24,
                backgroundImage: bytes == null ? null : MemoryImage(bytes),
                child: bytes == null ? const Icon(CupertinoIcons.person) : null,
              );
            },
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(CupertinoIcons.camera),
            label: Text(selectedPhoto == null
                ? (widget.photoId.isEmpty
                    ? 'اختيار صورة شخصية'
                    : 'تغيير الصورة')
                : 'تغيير الصورة المختارة'),
          ),
        ],
      );
}

class _EditUserDialog extends StatefulWidget {
  final AppStore store;
  final AppUser user;

  const _EditUserDialog({required this.store, required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final name = TextEditingController(text: widget.user.name);
  late final phone = TextEditingController(text: widget.user.phone);
  late final username = TextEditingController(text: widget.user.username);
  final password = TextEditingController();
  PickedUserPhoto? selectedPhoto;
  late String role = widget.user.role;
  late String division = (isDivisionHeadRole(widget.user.role) ||
          ['monitor', 'user'].contains(widget.user.role))
      ? widget.user.division
      : '';
  late String managerId = widget.user.managerId;
  String? error;

  Future<void> save() async {
    final user = widget.user;
    if (name.text.trim().isEmpty) {
      setState(() => error = 'أدخل الاسم الكامل');
      return;
    }
    if (username.text.trim().isEmpty) {
      setState(() => error = 'أدخل اسم المستخدم');
      return;
    }
    if (username.text.trim() != user.username && password.text.trim().isEmpty) {
      setState(() => error = 'أدخل كلمة مرور جديدة عند تغيير اسم المستخدم');
      return;
    }
    if (password.text.isNotEmpty && password.text.length < 6) {
      setState(() => error = 'كلمة المرور يجب ألا تقل عن 6 أحرف');
      return;
    }
    final updated = AppUser(
      id: user.id,
      name: name.text.trim(),
      phone: phone.text.trim(),
      username: username.text.trim(),
      passHash: user.passHash,
      role: role,
      division: division,
      managerId: managerId,
      active: user.active,
    );
    final result = widget.store.updateUser(
      updated,
      newPassword: password.text.isEmpty ? null : password.text,
    );
    if (result != null) {
      setState(() => error = result);
    } else {
      if (selectedPhoto != null) {
        try {
          final photoError = await widget.store.setUserPhoto(
            user.id,
            name: selectedPhoto!.name,
            mime: selectedPhoto!.mime,
            bytes: selectedPhoto!.bytes,
          );
          if (photoError != null && mounted) {
            toast(context, 'تم تعديل الحساب لكن تعذر حفظ الصورة: $photoError');
          }
        } catch (saveError) {
          if (mounted) {
            toast(context, 'تم تعديل الحساب لكن تعذر حفظ الصورة: $saveError');
          }
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('تعديل بيانات المستخدم'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _UserPhotoPicker(
                store: widget.store,
                photoId: widget.user.photoId,
                onChanged: (photo) => setState(() => selectedPhoto = photo),
              ),
              const SizedBox(height: 10),
              rowOf([
                Field('الاسم الكامل', ctl: name),
                Field('رقم الموبايل', ctl: phone, type: TextInputType.phone),
              ]),
              const SizedBox(height: 10),
              rowOf([
                Field('اسم المستخدم',
                    ctl: username,
                    readOnly: widget.store.me?.role != 'sysadmin'),
              ]),
              const SizedBox(height: 10),
              rowOf([
                Field('كلمة مرور مؤقتة جديدة (اختياري)', ctl: password),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'عند إدخال كلمة مرور، سيُطلب من المستخدم تغييرها عند دخوله التالي.',
                  style: TextStyle(color: context.p.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              if (['monitor', 'user'].contains(role))
                rowOf([
                  Drop(
                    'الشعبة',
                    division,
                    {
                      if (role == 'user') '': 'بلا شعبة',
                      if (role == 'monitor')
                        'field': kDivisionNames['field']!
                      else
                        ...kDivisionNames,
                    },
                    (value) => setState(() => division = value),
                  ),
                ]),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: kRed)),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: save,
            child: const Text('حفظ التعديلات'),
          ),
        ],
      );
}

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final roles = kRoles.keys.toList();
    return PageBody(children: [
      const PageHeader('مصفوفة الصلاحيات',
          subtitle:
              'يحدد مدير النظام لكل دور ما يستطيع فعله. كل تغيير يُسجَّل في سجل العمليات'),
      AppCard(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 800),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3)},
              defaultColumnWidth: const FlexColumnWidth(1.3),
              border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xFFEEEEF0))),
              children: [
                TableRow(children: [
                  const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('الإجراء',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  for (final r in roles)
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(kRoles[r]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)))
                ]),
                for (final p in kPerms.entries)
                  TableRow(children: [
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(p.value,
                            style: const TextStyle(fontSize: 13))),
                    for (final r in roles)
                      Center(
                          child: Checkbox(
                              value: (st.perms[r] ?? []).contains(p.key),
                              onChanged: (_) => st.togglePerm(r, p.key))),
                  ]),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

class RoutingScreen extends StatelessWidget {
  const RoutingScreen({super.key});

  Future<void> _users(BuildContext context, AppStore st, String type) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => Consumer<AppStore>(
          builder: (ctx, s, _) => AlertDialog(
            title: Text('مستخدمون محددون: ${kAlertTypes[type]}'),
            content: SizedBox(
                width: 420,
                height: 360,
                child: ListView(children: [
                  for (final u in s.users)
                    CheckboxListTile(
                        value: (s.routing[type] ?? []).contains('user:${u.id}'),
                        onChanged: (_) => s.toggleRoute(type, 'user:${u.id}'),
                        title: Text(u.name),
                        subtitle: Text(kRoles[u.role] ?? ''))
                ])),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('تم'))
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    const cols = {
      'role:sectionHead': 'رئيس قسم الواردات',
      'role:deptHead': 'رئيس دائرة الإنفاق الإستهلاكي',
      'role:fieldHead': 'رئيس الشعبة الميدانية',
      'role:officeHead': 'رئيس الشعبة المكتبية',
      'role:archiveHead': 'رئيس شعبة الأرشيف',
      'div:field': 'الميدانية',
      'div:office': 'المكتبية',
      'div:archive': 'الأرشيف'
    };
    return PageBody(children: [
      const PageHeader('توزيع التنبيهات',
          subtitle: 'يحدد مدير النظام وحده من يصله كل تنبيه. كل تغيير يُسجَّل'),
      AppCard(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3)},
              defaultColumnWidth: const FlexColumnWidth(1.3),
              border: const TableBorder(
                  horizontalInside: BorderSide(color: Color(0xFFEEEEF0))),
              children: [
                TableRow(children: [
                  const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('التنبيه',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  for (final c in cols.values)
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(c,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12))),
                  const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('مستخدمون',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12)))
                ]),
                for (final a in kAlertTypes.entries)
                  TableRow(children: [
                    Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(a.value,
                            style: const TextStyle(fontSize: 13))),
                    for (final c in cols.keys)
                      Center(
                          child: Checkbox(
                              value: (st.routing[a.key] ?? []).contains(c),
                              onChanged: (_) => st.toggleRoute(a.key, c))),
                    Center(
                        child: TextButton(
                            onPressed: () => _users(context, st, a.key),
                            child: Text(
                                '${(st.routing[a.key] ?? []).where((x) => x.startsWith('user:')).length}'))),
                  ]),
              ],
            ),
          ),
        ),
      ),
      Text('مدير النظام يستلم كل التنبيهات دائماً.',
          style: TextStyle(color: context.p.muted, fontSize: 12)),
    ]);
  }
}

class SerialsScreen extends StatelessWidget {
  const SerialsScreen({super.key});

  Future<void> _addBook(BuildContext context, AppStore st) async {
    final from = TextEditingController(),
        to = TextEditingController(),
        who = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('تسليم دفتر محاضر'),
          content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                rowOf([
                  Field('من رقم', ctl: from, type: TextInputType.number),
                  Field('إلى رقم', ctl: to, type: TextInputType.number)
                ]),
                const SizedBox(height: 10),
                rowOf([Field('المسلَّم إليه', ctl: who)]),
                if (err != null) Text(err!, style: const TextStyle(color: kRed))
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(from.text), b = int.tryParse(to.text);
                if (a == null || b == null || who.text.trim().isEmpty) {
                  set(() => err = 'أكمل الحقول');
                  return;
                }
                final e = st.addBook(a, b, who.text.trim());
                if (e != null) {
                  set(() => err = e);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('تسليم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reconcile(
      BuildContext context, AppStore st, SerialBook b) async {
    final gaps = st.gaps(b);
    if (gaps.isEmpty) return toast(context, 'لا أرقام غير مُحاسَب عليها');
    var n = gaps.first;
    var reason = 'تالف';
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('تسوية رقم محضر'),
          content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                rowOf([
                  Drop('الرقم', '$n', {for (final g in gaps) '$g': '$g'},
                      (v) => set(() => n = int.parse(v))),
                  Drop(
                      'السبب',
                      reason,
                      const {
                        'تالف': 'تالف',
                        'ضائع': 'ضائع',
                        'ملغى قبل الاستخدام': 'ملغى قبل الاستخدام'
                      },
                      (v) => set(() => reason = v))
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: note,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظة (إلزامية)'))
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () =>
                    note.text.trim().isEmpty ? null : Navigator.pop(ctx, true),
                child: const Text('تسجيل التسوية'))
          ],
        ),
      ),
    );
    if (ok == true) st.reconcile(b, n, '$reason: ${note.text.trim()}');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    return PageBody(children: [
      PageHeader('دفاتر أرقام المحاضر',
          subtitle: 'كل رقم مطبوع مُسلَّم لمفتش ومُحاسَب عليه',
          actions: [
            FilledButton.icon(
                onPressed: () => _addBook(context, st),
                icon: const Icon(CupertinoIcons.add),
                label: const Text('تسليم دفتر'))
          ]),
      Row(children: [
        Expanded(
            child: StatCard('أرقام غير مُحاسَب عليها', '${st.totalGaps()}',
                CupertinoIcons.exclamationmark_circle,
                warn: st.totalGaps() > 0)),
        const SizedBox(width: 12),
        Expanded(
            child: StatCard(
                'دفاتر مسلَّمة', '${st.books.length}', CupertinoIcons.book))
      ]),
      GridTable(
        heads: const [
          'من',
          'إلى',
          'المسلَّم إليه',
          'مستخدم',
          'غير مُحاسَب',
          'تسويات',
          ''
        ],
        flex: const [1, 1, 3, 1, 2, 1, 2],
        rows: [
          for (final b in st.books)
            [
              cellText('${b.from}'),
              cellText('${b.to}'),
              cellText(b.assignee),
              cellText('${st.usedIn(b).length}'),
              st.gaps(b).isEmpty
                  ? const StatusBadge('سليم')
                  : StatusBadge('يحتاج مراجعة: ${st.gaps(b).join("، ")}'),
              cellText('${b.reconciled.length}'),
              TextButton(
                  onPressed: () => _reconcile(context, st, b),
                  child: const Text('تسوية')),
            ],
        ],
      ),
    ]);
  }
}

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final q = TextEditingController();
  String userFilter = '';

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final nq = normAr(q.text);
    final users = {
      for (final user in st.users)
        if (user.name.trim().isNotEmpty) user.name.trim(),
      for (final entry in st.audit)
        if (entry.user.trim().isNotEmpty) entry.user.trim(),
    }.toList()
      ..sort();
    final userOptions = {
      '': 'كل المستخدمين',
      for (final user in users) user: user,
    };
    final list = st.audit.reversed
        .where((e) =>
            (userFilter.isEmpty || e.user == userFilter) &&
            (nq.isEmpty ||
                normAr('${e.user} ${e.action} ${e.entity} ${e.detail}')
                    .contains(nq)))
        .toList();
    return PageBody(children: [
      const PageHeader('سجل العمليات',
          subtitle:
              'منفذ العملية هو المستخدم الذي أجراها، والعنصر المتأثر هو السجل الذي عُدّل. '
              'التفاصيل تعرض معلومات إضافية. السجل للقراءة فقط ومترابط ببصمات تكشف التعديل أو الحذف.'),
      AppCard(
        child: Column(children: [
          rowOf([
            Drop(
              'عرض عمليات المستخدم',
              userFilter,
              userOptions,
              (value) => setState(() => userFilter = value),
            ),
            Expanded(
              child: TextField(
                controller: q,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'بحث في السجل',
                  prefixIcon: Icon(CupertinoIcons.search),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'عدد العمليات المعروضة: ${list.length}',
              style: TextStyle(color: context.p.muted, fontSize: 12),
            ),
          ),
        ]),
      ),
      GridTable(
        heads: const [
          'منفذ العملية',
          'نوع العملية',
          'العنصر المتأثر',
          'تفاصيل إضافية',
          'الوقت',
          'البصمة'
        ],
        flex: const [2, 2, 2, 4, 2, 2],
        minWidth: 1120,
        rows: [
          for (final e in list)
            [
              _auditCell(e.user),
              _auditCell(e.action, bold: true),
              _auditCell(e.entity),
              _auditCell(e.detail.isEmpty ? '—' : e.detail),
              cellText(fmtDT(DateTime.parse(e.ts))),
              cellText(e.hash.substring(0, 10))
            ]
        ],
      ),
    ]);
  }

  Widget _auditCell(String value, {bool bold = false}) => Tooltip(
        message: value,
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
}

class IntegrityScreen extends StatefulWidget {
  const IntegrityScreen({super.key});
  @override
  State<IntegrityScreen> createState() => _IntegrityScreenState();
}

class _IntegrityScreenState extends State<IntegrityScreen> {
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final checks = st.runIntegrity();
    final bad = checks.where((c) => !c.ok).length;
    final failed =
        st.audit.where((e) => e.action == 'محاولة دخول فاشلة').length;
    final cancels = st.audit.where((e) => e.action == 'إلغاء محضر').length;
    return PageBody(children: [
      PageHeader('سلامة السجلات',
          subtitle: 'يكشف أي تعديل أو نقص أو تكرار',
          actions: [
            FilledButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(CupertinoIcons.shield),
                label: const Text('تشغيل فحص الآن'))
          ]),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bad == 0 ? const Color(0xFFF5F5F7) : const Color(0xFFF8E3E3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: bad == 0
                    ? const Color(0xFFE3E3E8)
                    : const Color(0xFFE7B9B9))),
        child: Row(children: [
          Icon(
              bad == 0
                  ? CupertinoIcons.shield_fill
                  : CupertinoIcons.exclamationmark_triangle_fill,
              color: bad == 0 ? kPrimary : kRed),
          const SizedBox(width: 10),
          Text(
              bad == 0
                  ? 'لم تُكتشف تعديلات غير مسجّلة (${fmtDT(DateTime.now())})'
                  : 'تحتاج $bad فحوص مراجعة',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: bad == 0 ? kPrimary : kRed))
        ]),
      ),
      AppCard(
          child: Column(children: [
        for (final c in checks)
          ListTile(
              leading: Icon(
                  c.ok
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.exclamationmark_circle_fill,
                  color: c.ok ? kPrimary : kRed),
              title: Text(c.title),
              subtitle: Text(c.detail),
              trailing: StatusBadge(c.ok ? 'سليم' : 'يحتاج مراجعة'))
      ])),
      AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مؤشرات تستحق المراجعة',
            style: TextStyle(fontWeight: FontWeight.w700)),
        kv('محاولات دخول فاشلة', '$failed'),
        kv('محاضر ملغاة', '$cancels')
      ])),
    ]);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ctl = <String, TextEditingController>{};
  TextEditingController c(AppStore st, String k) => ctl.putIfAbsent(
      k, () => TextEditingController(text: '${st.settings[k]}'));

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    const nums = {
      'lateFeePct': 'غرامة التأخير الشهرية % (افتراضي)',
      'objectionDays': 'مهلة الاعتراض (أيام)',
      'statementsDeadlineDay': 'آخر يوم لتقديم البيان الشهري',
      'declineCritical': 'عتبة الانخفاض الحرج %',
      'declineHigh': 'عتبة الانخفاض المرتفع %',
      'declineMedium': 'عتبة الانخفاض المتوسط %'
    };
    final types = st.violationTypes;
    return PageBody(children: [
      PageHeader('الإعدادات والنسخ الاحتياطي', actions: [
        FilledButton(
          onPressed: () {
            for (final k in nums.keys) {
              final v = num.tryParse(ctl[k]?.text ?? '');
              if (v != null) st.setSetting(k, v);
            }
            toast(context, 'حُفظت الإعدادات');
          },
          child: const Text('حفظ'),
        ),
      ]),
      AppCard(
        child: RadioGroup<String>(
          groupValue: st.settings['serialMode'] as String,
          onChanged: (value) {
            if (value != null) st.setSetting('serialMode', value);
          },
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ترقيم المحاضر',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const RadioListTile<String>(
              value: 'manual',
              title: Text(
                  'رقم مطبوع مسبقاً يدخله الموظف (مع التحقق من التكرار ومن دفاتر الأرقام)'),
            ),
            const RadioListTile<String>(
              value: 'auto',
              title: Text('رقم تلقائي من النظام'),
            ),
          ]),
        ),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('المظهر', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              'يعمل التبديل فوراً ويُحفظ مع الإعدادات. متاح أيضاً من زر القمر/الشمس في الشريط العلوي.',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: st.darkMode,
            onChanged: st.setDarkMode,
            title: const Text('الوضع الداكن'),
            subtitle: Text(st.darkMode ? 'مفعّل' : 'غير مفعّل',
                style: TextStyle(color: context.p.muted, fontSize: 12)),
            secondary: Icon(
                st.darkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max,
                color: st.darkMode ? const Color(0xFF9BB0FF) : kGold),
          ),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('القواعد والعتبات',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final e in nums.entries)
              SizedBox(
                  width: 280,
                  child: TextField(
                      controller: c(st, e.key),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: e.value)))
          ]),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('أنواع المخالفات',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () async {
                final n = await askText(context, 'نوع مخالفة جديد',
                    label: 'اسم المخالفة');
                if (n != null) {
                  st.setViolationTypes([
                    ...types,
                    {'name': n, 'article': '', 'fine': 0}
                  ]);
                }
              },
              icon: const Icon(CupertinoIcons.add),
              label: const Text('إضافة نوع'),
            ),
          ]),
          for (var i = 0; i < types.length; i++)
            ListTile(
                dense: true,
                title: Text(types[i]['name'] as String),
                trailing: IconButton(
                    icon: const Icon(CupertinoIcons.trash),
                    onPressed: () =>
                        st.setViolationTypes([...types]..removeAt(i)))),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('النسخ الاحتياطي',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              'هذه نسخة من بيانات المتصفح التجريبية. في الإنتاج تُؤخذ النسخ من قاعدة SQL Server على الخادم.',
              style: TextStyle(color: context.p.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: st.exportAll()));
                  if (context.mounted) {
                    toast(context, 'نُسخت النسخة الاحتياطية إلى الحافظة');
                  }
                },
                child: const Text('نسخ نسخة احتياطية')),
            OutlinedButton(
              onPressed: () async {
                final t = TextEditingController();
                final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                            title: const Text('استعادة نسخة'),
                            content: SizedBox(
                                width: 520,
                                child: TextField(
                                    controller: t,
                                    maxLines: 10,
                                    decoration: const InputDecoration(
                                        hintText: 'الصق محتوى النسخة هنا'))),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('إلغاء')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('استعادة'))
                            ]));
                if (ok == true && context.mounted) {
                  toast(
                      context,
                      st.importAll(t.text)
                          ? 'تمت الاستعادة. سجّل الدخول من جديد'
                          : 'النسخة غير صالحة');
                }
              },
              child: const Text('استعادة نسخة'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: kRed, side: const BorderSide(color: kRed)),
              onPressed: () async {
                if (await confirmDialog(context, 'إعادة البيانات التجريبية',
                        'ستُحذف كل البيانات الحالية. المتابعة؟') &&
                    context.mounted) {
                  st.resetDemo();
                }
              },
              child: const Text('إعادة البيانات التجريبية'),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

String _stamp12(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? 'غير محدد' : fmtDT12(date);
}

String _stampDate(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? 'غير محدد' : fmtDate(date);
}

String _stampTime(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? 'غير محدد' : fmtTime12(date);
}

String _userStatusLabel(String value) => switch (value) {
      'closed' => 'مغلق نهائيًا',
      'disabled' => 'معطل مؤقتًا',
      _ => 'فعال',
    };

/// صورة المستخدم الدائرية مع نقطة الحالة.
class _UserAvatar extends StatelessWidget {
  final AppStore store;
  final AppUser user;
  final double radius;
  final Color statusColor;
  final Color borderColor;
  const _UserAvatar({
    required this.store,
    required this.user,
    required this.radius,
    required this.statusColor,
    this.borderColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        user.name.trim().isEmpty ? '؟' : user.name.trim().substring(0, 1);
    return SizedBox(
      width: radius * 2 + 6,
      height: radius * 2 + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
              ),
              border: Border.all(color: borderColor, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: .35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: FutureBuilder<Uint8List?>(
                key: ValueKey(user.photoId),
                future: user.photoId.isEmpty
                    ? null
                    : store.attachmentBytes(user.photoId),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  return bytes == null
                      ? Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: radius * .9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : Image.memory(bytes, fit: BoxFit.cover);
                },
              ),
            ),
          ),
          PositionedDirectional(
            end: 0,
            bottom: 2,
            child: Container(
              width: radius * .48,
              height: radius * .48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريحة زجاجية للرأس الداكن.
class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(9, 4, 11, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: .92)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      );
}

/// شريحة معلومات ملونة (حبة).
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 12, 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.p.isDark ? .16 : .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.p.text,
            ),
          ),
        ]),
      );
}

/// عنصر نصي صغير مع أيقونة.
class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.p.muted),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.p.muted),
          ),
        ],
      );
}

/// بطاقة إحصاء حسابات.
class _UserStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _UserStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 218,
        height: 92,
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    color.withValues(alpha: .28),
                    color.withValues(alpha: .09),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.p.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// بطاقة مستخدم (عرض وإجراءات).
class _UserCard extends StatelessWidget {
  final AppStore store;
  final AppUser user;
  final String managerName;
  final VoidCallback onHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;
  final VoidCallback? onClose;
  const _UserCard({
    required this.store,
    required this.user,
    required this.managerName,
    required this.onHistory,
    required this.onEdit,
    required this.onToggleActive,
    required this.onClose,
  });

  Color get _statusColor => switch (user.status) {
        'closed' => kRed,
        'disabled' => kGold,
        _ => const Color(0xFF34C759),
      };

  @override
  Widget build(BuildContext context) {
    final creationDate = _stampDate(user.createdAt);
    final creationTime = _stampTime(user.createdAt);
    final creator = user.createdBy.trim();
    final division = kDivisionNames[user.division] ??
        kDivisions[user.division] ??
        user.division;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _UserAvatar(
              store: store,
              user: user,
              radius: 30,
              statusColor: _statusColor,
              borderColor: context.p.surface,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      StatusBadge(_userStatusLabel(user.status)),
                      if (user.passwordChangeRequired)
                        const StatusBadge('تغيير كلمة المرور مطلوب'),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      color: context.p.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _MetaChip(
                icon: CupertinoIcons.briefcase_fill,
                label: kRoles[user.role] ?? user.role,
                color: kPrimary2),
            if (division.isNotEmpty)
              _MetaChip(
                  icon: CupertinoIcons.building_2_fill,
                  label: division,
                  color: kPrimary2),
            _MetaChip(
                icon: CupertinoIcons.person_2_fill,
                label: 'المسؤول: $managerName',
                color: kGold),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _MetaItem(
                  icon: CupertinoIcons.phone_fill,
                  text: user.phone.isEmpty ? '—' : user.phone),
              _MetaItem(
                  icon: CupertinoIcons.calendar,
                  text: 'أُنشئ: $creationDate'),
              _MetaItem(
                  icon: CupertinoIcons.clock,
                  text: 'الوقت: $creationTime'),
              _MetaItem(
                  icon: CupertinoIcons.person_badge_plus,
                  text: 'من: ${creator.isEmpty ? 'غير محدد' : creator}'),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.p.border),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'صفحة المستخدم',
                onPressed: () => context.go('/users/${user.id}/profile'),
                icon: const Icon(CupertinoIcons.person_crop_circle_fill,
                    size: 22, color: kPrimary2),
              ),
              IconButton(
                tooltip: 'تفاصيل وسجل الحساب',
                onPressed: onHistory,
                icon: const Icon(CupertinoIcons.info,
                    size: 22, color: kGold),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'تعديل المستخدم',
                  onPressed: onEdit,
                  icon: const Icon(CupertinoIcons.pencil,
                      size: 19, color: kPrimary2),
                ),
              if (onToggleActive != null)
                IconButton(
                  tooltip: user.active ? 'تعطيل مؤقتًا' : 'إعادة تفعيل',
                  onPressed: onToggleActive,
                  icon: Icon(
                    user.active
                        ? CupertinoIcons.pause_circle_fill
                        : CupertinoIcons.checkmark_seal_fill,
                    size: 20,
                    color: user.active ? kGold : const Color(0xFF34C759),
                  ),
                ),
              if (onClose != null)
                IconButton(
                  tooltip: 'إغلاق الحساب نهائيًا',
                  onPressed: onClose,
                  icon: const Icon(CupertinoIcons.lock_fill,
                      size: 19, color: kRed),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// قسم داخل حوار سجل الحساب.
class _HistorySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final List<Widget> rows;
  const _HistorySection({
    required this.icon,
    required this.title,
    required this.accent,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      accent.withValues(alpha: .26),
                      accent.withValues(alpha: .08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              row,
              if (row != rows.last) const Divider(height: 14),
            ],
          ],
        ),
      );
}

/// صف معلومة في سجل الحساب.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  const _InfoRow({
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: accent ?? context.p.muted),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 2),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.p.muted, fontSize: 12.5),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent ?? context.p.text,
              ),
            ),
          ),
        ],
      );
}

/// صف فترة تعطيل/تفعيل في السجل.
class _StatusPeriodRow extends StatelessWidget {
  final int index;
  final AccountStatusPeriod period;
  const _StatusPeriodRow({
    required this.index,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final ongoing = period.endedAt.isEmpty;
    final color = ongoing ? kRed : const Color(0xFF34C759);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .18),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.2),
          ),
          child: Center(
            child: Text(
              '$index',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'من ${_stamp12(period.startedAt)} إلى ${ongoing ? 'مستمر' : _stamp12(period.endedAt)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'بدأها: ${period.startedBy}'
                '${period.endedBy.isEmpty ? '' : ' · أعاد التفعيل: ${period.endedBy}'}',
                style: TextStyle(
                  color: context.p.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// قائمة منسدلة بأيقونة ولون — مظهر أفخم لحقل الفلاتر.
class _IconDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _IconDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20, color: kPrimary2),
            filled: true,
            fillColor: context.p.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(CupertinoIcons.chevron_down, size: 17),
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => onChanged(v ?? ''),
            ),
          ),
        ),
      );
}
