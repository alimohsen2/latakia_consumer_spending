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

/// حوار تعديل الحساب — متاح لأصحاب صلاحية إدارة المستخدمين.
void showEditUserDialog(BuildContext context, AppStore store, AppUser user) {
  showDialog<void>(
    context: context,
    builder: (_) => _EditUserDialog(store: store, user: user),
  );
}

/// إغلاق الحساب نهائيًا بخطوتين: كلمة المرور + تأكيد إضافي ثم تُحفظ فورًا.
/// تُستخدم من جدول المستخدمين ومن صفحة الملف الشخصي.
Future<void> closeAccountWithConfirmation(
    BuildContext context, AppStore st, AppUser user) async {
  final credentials = await showDialog<({String reason, String password})>(
    context: context,
    builder: (_) => const _CloseAccountDialog(),
  );
  if (credentials == null || !context.mounted) return;
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
  if (confirmed != true || !context.mounted) return;
  try {
    final result = await st.closeUser(
      user.id,
      credentials.reason,
      adminPassword: credentials.password,
    );
    if (context.mounted) {
      toast(context, result ?? 'أُغلق الحساب نهائيًا وحُفظت جميع سجلاته');
    }
  } catch (error) {
    if (context.mounted) toast(context, 'تعذر حفظ إغلاق الحساب: $error');
  }
}

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
  String view = 'table';
  bool searchOpen = true;
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
    final statusLabel = switch (user.status) {
      'closed' => 'مغلق نهائيًا',
      'disabled' => 'معطل مؤقتًا',
      _ => 'فعال',
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.p.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(34)),
        titlePadding: EdgeInsets.zero,
        contentPadding:
            const EdgeInsets.fromLTRB(22, 18, 22, 8),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Color(0xFF24695C),
                Color(0xFF17574E),
                Color(0xFF0E3A34),
              ],
            ),
          ),
          child: Stack(children: [
            PositionedDirectional(
              top: -50,
              end: -50,
              child: _GlowCircle(color: kGold.withValues(alpha: .26), size: 180),
            ),
            PositionedDirectional(
              bottom: -60,
              start: -60,
              child: _GlowCircle(
                  color: kPrimary2.withValues(alpha: .32), size: 220),
            ),
            Row(
              children: [
                _LargeAvatar(
                  store: context.read<AppStore>(),
                  user: user,
                  statusColor: statusColor,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            11, 5, 11, 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: .22)),
                        ),
                        child: Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .92),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _GlassPill(
                            icon: CupertinoIcons.briefcase_fill,
                            label: kRoles[user.role] ?? user.role,
                          ),
                          if (user.division.isNotEmpty)
                            _GlassPill(
                              icon: CupertinoIcons.building_2_fill,
                              label: kDivisionNames[user.division] ??
                                  kDivisions[user.division] ??
                                  user.division,
                            ),
                          _StatusPill(label: statusLabel, color: statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480, maxWidth: 580),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HistorySection(
                  icon: CupertinoIcons.person_crop_rectangle,
                  title: 'بيانات الحساب',
                  accent: kPrimary2,
                  rows: [
                    _InfoRow(
                        icon: CupertinoIcons.person_fill,
                        label: 'الاسم الكامل',
                        value: user.name),
                    _InfoRow(
                        icon: CupertinoIcons.at,
                        label: 'اسم المستخدم',
                        value: user.username),
                    _InfoRow(
                        icon: CupertinoIcons.phone_fill,
                        label: 'رقم الموبايل',
                        value: user.phone.isEmpty ? '—' : user.phone),
                    _InfoRow(
                        icon: CupertinoIcons.briefcase_fill,
                        label: 'الدور',
                        value: kRoles[user.role] ?? user.role,
                        accent: kGold),
                    if (user.division.isNotEmpty)
                      _InfoRow(
                          icon: CupertinoIcons.building_2_fill,
                          label: 'الشعبة',
                          value: kDivisionNames[user.division] ??
                              kDivisions[user.division] ??
                              user.division),
                    _InfoRow(
                        icon: CupertinoIcons.person_2_fill,
                        label: 'المسؤول المباشر',
                        value: roleHasManager(user.role)
                            ? (manager?.name ?? '—')
                            : ''),
                  ],
                ),
                const SizedBox(height: 14),
                _HistorySection(
                  icon: CupertinoIcons.calendar_badge_plus,
                  title: 'الإنشاء والإغلاق',
                  accent: kGold,
                  rows: [
                    _InfoRow(
                      icon: CupertinoIcons.calendar_circle,
                      label: 'تاريخ الإنشاء',
                      value: _stampDate(user.createdAt),
                    ),
                    _InfoRow(
                      icon: CupertinoIcons.clock,
                      label: 'وقت الإنشاء',
                      value: _stampTime(user.createdAt),
                    ),
                    _InfoRow(
                      icon: CupertinoIcons.person_badge_plus,
                      label: 'أنشئ من قبل',
                      value: creatorName,
                    ),
                    if (user.status == 'closed') ...[
                      _InfoRow(
                        icon: CupertinoIcons.lock_fill,
                        label: 'تاريخ الإغلاق',
                        value: _stamp12(user.closedAt),
                        accent: kRed,
                      ),
                      if (user.closedBy.isNotEmpty)
                        _InfoRow(
                          icon: CupertinoIcons.xmark_circle_fill,
                          label: 'أغلقه',
                          value: user.closedBy,
                          accent: kRed,
                        ),
                      if (user.closureReason.isNotEmpty)
                        _InfoRow(
                          icon: CupertinoIcons.exclamationmark_circle,
                          label: 'سبب الإغلاق',
                          value: user.closureReason,
                          accent: kRed,
                        ),
                    ],
                  ],
                ),
                if (user.statusPeriods.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _HistorySection(
                    icon: CupertinoIcons.clock,
                    title: 'سجل التعطيل وإعادة التفعيل',
                    accent: kGold,
                    subtitle:
                        'الفترات التي أُوقف فيها الحساب وأعيد تفعيله',
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
                  const SizedBox(height: 14),
                  _BannerNote(
                    icon: CupertinoIcons.exclamationmark_triangle_fill,
                    text:
                        'كلمة مرور مؤقتة — التغيير مطلوب عند الدخول التالي.',
                    color: kGold,
                  ),
                ],
                if (user.status == 'disabled') ...[
                  const SizedBox(height: 14),
                  _BannerNote(
                    icon: CupertinoIcons.pause_circle_fill,
                    text: 'هذا الحساب معطل مؤقتًا ولا يستطيع الدخول.',
                    color: kGold,
                  ),
                ],
                if (user.status == 'closed') ...[
                  const SizedBox(height: 14),
                  _BannerNote(
                    icon: CupertinoIcons.lock_fill,
                    text: 'هذا الحساب مغلق نهائيًا ولا يمكن إعادة تفعيله.',
                    color: kRed,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: ctx.p.muted,
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
            ),
            child: const Text('إغلاق',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.go('/users/${user.id}/activity');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimary,
              padding:
                  const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
              shape: const StadiumBorder(),
              side: BorderSide(
                  color: kPrimary.withValues(alpha: .35), width: 1),
            ),
            icon: const Icon(CupertinoIcons.time, size: 18),
            label: const Text(
              'سجل نشاطه',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.go('/users/${user.id}/profile');
            },
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              padding:
                  const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            icon: const Icon(CupertinoIcons.person_crop_circle_fill,
                size: 18),
            label: const Text(
              'عرض الملف الشخصي',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _managerNameOf(AppUser user) {
    if (!roleHasManager(user.role)) return '';
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
              onPressed: () => context.go('/users/new'),
              icon: const Icon(CupertinoIcons.person_add, size: 18),
              label: const Text('إنشاء حساب'),
            ),
          ]),
      StatGrid(
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
              Tooltip(
                message: searchOpen ? 'طي البحث' : 'فتح البحث',
                child: Material(
                  color: context.p.surfaceAlt,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => searchOpen = !searchOpen),
                    child: AnimatedRotation(
                      turns: searchOpen ? 0.5 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(CupertinoIcons.chevron_down, size: 19),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
            Text('ابحث في الحسابات',
                style: TextStyle(
                    color: context.p.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: query,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المستخدم أو اسمه الكامل أو حسابه…',
                hintStyle: TextStyle(
                    color: context.p.muted, fontSize: 13.5),
                filled: true,
                fillColor: context.p.surfaceAlt,
                contentPadding:
                    const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: kPrimary2.withValues(alpha: .6), width: 1.5),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kPrimary2.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(CupertinoIcons.search,
                        size: 17, color: kPrimary2),
                  ),
                ),
                suffixIcon: query.text.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () => setState(() => query.clear()),
                        icon: const Icon(CupertinoIcons.clear_circled_solid,
                            size: 19),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 16, 7),
                decoration: BoxDecoration(
                  color: kPrimary2.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kPrimary2.withValues(alpha: .18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${list.length}',
                      style: const TextStyle(
                          color: kPrimary2,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  Text('/ ${st.users.length}',
                      style: TextStyle(
                          color: context.p.muted.withValues(alpha: .45),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('حساب',
                      style: TextStyle(
                          color: context.p.muted.withValues(alpha: .62),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                _LabeledDrop(
                    label: 'الدور',
                    icon: CupertinoIcons.briefcase_fill,
                    value: role,
                    options: const {'': 'الكل', ...kRoles},
                    onChanged: (v) => setState(() => role = v)),
                _LabeledDrop(
                    label: 'الشعبة',
                    icon: CupertinoIcons.building_2_fill,
                    value: div,
                    options: const {'': 'الكل', ...kDivisionNames},
                    onChanged: (v) => setState(() => div = v)),
                _LabeledDrop(
                    label: 'الحالة',
                    icon: CupertinoIcons.lock_fill,
                    value: status,
                    options: const {
                      '': 'كل الحالات',
                      'active': 'فعال',
                      'disabled': 'معطل مؤقتًا',
                      'closed': 'مغلق نهائيًا',
                    },
                    onChanged: (v) => setState(() => status = v)),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      side: BorderSide(color: context.p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: query.text.trim().isNotEmpty ||
                            role.isNotEmpty ||
                            div.isNotEmpty ||
                            status.isNotEmpty
                        ? () => setState(() {
                              query.clear();
                              role = '';
                              div = '';
                              status = '';
                            })
                        : null,
                    icon: const Icon(CupertinoIcons.refresh, size: 13),
                    label: const Text('إعادة ضبط',
                        style: TextStyle(fontSize: 11)),
                  ),
                ),
                    ],
                  ),
                ),
              ],
            ),
            ],
          ),
          crossFadeState: searchOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
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
                decoration: const BoxDecoration(
                    color: kPrimary2,
                    borderRadius: BorderRadius.all(Radius.circular(2)))),
            const SizedBox(width: 9),
            const Text('قائمة المستخدمين',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -.2)),
          ]);
          final toggle = Seg(
            const ['بطاقات', 'جدول'],
            view == 'cards' ? 0 : 1,
            (i) => setState(() => view = i == 0 ? 'cards' : 'table'),
            icons: const [
              CupertinoIcons.square_grid_2x2_fill,
              CupertinoIcons.table,
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: toggle,
                ),
              ],
            );
          }
          return Row(children: [
            heading,
            const SizedBox(width: 14),
            Expanded(child: Container(height: .6, color: context.p.border)),
            const SizedBox(width: 14),
            toggle,
          ]);
        }),
      ),
      if (view == 'table' && list.isNotEmpty)
        GridTable(
          onRowTap: (index) => context.go('/users/${list[index].id}/profile'),
          centerColumns: const {0, 1, 9, 10},
          heads: const [
            '#',
            'الأيقونة',
            'الدور',
            'اسم المستخدم',
            'الشعبة',
            'المسؤول',
            'الموبايل',
            'تاريخ الإنشاء',
            'وقت الإنشاء',
            'الحالة',
            'إجراءات',
          ],
          flex: const [1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3],
          rows: [
            for (var index = 0; index < list.length; index++)
              [
                cellText('${index + 1}', bold: true),
                Tooltip(
                  message: kRoles[list[index].role] ?? list[index].role,
                  child: _RoleIcon(role: list[index].role),
                ),
                cellText(kRoles[list[index].role] ?? list[index].role),
                cellText(list[index].username),
                cellText(kDivisionNames[list[index].division] ??
                    kDivisions[list[index].division] ??
                    list[index].division),
                cellText(_managerNameOf(list[index])),
                cellText(list[index].phone.isEmpty ? '—' : list[index].phone),
                cellText(_stampDate(list[index].createdAt)),
                cellText(_stampTime(list[index].createdAt)),
                StatusBadge(_userStatusLabel(list[index].status)),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                  _CircleIconButton(
                    tooltip: 'صفحة المستخدم',
                    onPressed: () =>
                        context.go('/users/${list[index].id}/profile'),
                    icon: CupertinoIcons.person_crop_circle_fill,
                    color: kPrimary2,
                    size: 40,
                  ),
                  _CircleIconButton(
                    tooltip: 'تفاصيل وسجل الحساب',
                    onPressed: () => _showAccountHistory(list[index]),
                    icon: CupertinoIcons.info,
                    color: kGold,
                    size: 40,
                  ),
                  if (list[index].status != 'closed')
                    _CircleIconButton(
                      tooltip: 'تعديل المستخدم',
                      onPressed: () => _edit(st, list[index]),
                      icon: CupertinoIcons.pencil,
                      color: kPrimary2,
                      size: 40,
                    ),
                  if (list[index].id != st.me?.id && list[index].status != 'closed')
                    _CircleIconButton(
                      tooltip:
                          list[index].active ? 'تعطيل مؤقتًا' : 'إعادة تفعيل',
                      onPressed: () {
                        final error = st.setUserActive(
                            list[index], !list[index].active);
                        if (error != null) toast(context, error);
                      },
                      icon: list[index].active
                          ? CupertinoIcons.pause_circle_fill
                          : CupertinoIcons.checkmark_seal_fill,
                      color: list[index].active
                          ? kGold
                          : const Color(0xFF34C759),
                      size: 40,
                    ),
                  if (list[index].id != st.me?.id && list[index].status != 'closed')
                    _CircleIconButton(
                      tooltip: 'إغلاق الحساب نهائيًا',
                      onPressed: () => closeAccountWithConfirmation(context, st, list[index]),
                      icon: CupertinoIcons.lock_fill,
                      color: kRed,
                      size: 40,
                    ),
                  ],
                ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            const cols = 2;
            const double spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final u in list)
                  SizedBox(
                    width: itemWidth,
                    child: _UserCard(
                      store: st,
                      user: u,
                      managerName: _managerNameOf(u),
                      onHistory: () => _showAccountHistory(u),
                      onEdit: u.status == 'closed' ? null : () => _edit(st, u),
                      onToggleActive:
                          u.id != st.me?.id && u.status != 'closed'
                              ? () {
                                  final error = st.setUserActive(u, !u.active);
                                  if (error != null) toast(context, error);
                                }
                              : null,
                      onClose: u.id != st.me?.id && u.status != 'closed'
                          ? () => closeAccountWithConfirmation(context, st, u)
                          : null,
                    ),
                  ),
              ],
            );
          },
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

const _rolePalette = [
  kPrimary2,
  kGold,
  Color(0xFF7FB8FF),
  Color(0xFF9FE3C0),
  Color(0xFFFFA99B),
  Color(0xFF9EC5FF),
  Color(0xFFFFD27A),
  Color(0xFFB9C6D8),
  Color(0xFFD6C2FF),
  Color(0xFF8ADCE3),
];

const _roleIcons = <String, IconData>{
  'sysadmin': CupertinoIcons.shield_fill,
  'financeDirector': CupertinoIcons.building_2_fill,
  'sectionHead': CupertinoIcons.person_2_fill,
  'infoSectionHead': CupertinoIcons.desktopcomputer,
  'deptHead': CupertinoIcons.building_2_fill,
  'fieldHead': CupertinoIcons.map_fill,
  'officeHead': CupertinoIcons.briefcase_fill,
  'archiveHead': CupertinoIcons.archivebox_fill,
  'monitor': CupertinoIcons.eye_fill,
  'user': CupertinoIcons.person_fill,
};

/// صفحة إدارة مصفوفة الصلاحيات — تصميم فخم يحافظ على الشكل العام.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final roles = kRoles.keys.toList();
    final grantedCount = roles.fold<int>(
        0, (sum, r) => sum + (st.perms[r]?.length ?? 0));
    final dark = context.p.isDark;

    return PageBody(
      contentMaxWidth: double.infinity,
      children: [
      PageHeader(
        'مصفوفة الصلاحيات',
        subtitle:
            'يحدد مدير النظام لكل دور ما يستطيع فعله. كل تغيير يُسجَّل في سجل العمليات',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/audit'),
            icon: const Icon(CupertinoIcons.time, size: 17),
            label: const Text('سجل العمليات'),
          ),
        ],
      ),
      StatGrid(
        children: [
          _UserStat(
              label: 'عدد الأدوار',
              value: '${roles.length}',
              icon: CupertinoIcons.person_3_fill,
              color: kPrimary2),
          _UserStat(
              label: 'عدد الصلاحيات',
              value: '${kPerms.length}',
              icon: CupertinoIcons.lock_shield_fill,
              color: kGold),
          _UserStat(
              label: 'صلاحيات ممنوحة',
              value: '$grantedCount',
              icon: CupertinoIcons.checkmark_seal_fill,
              color: const Color(0xFF34C759)),
        ],
      ),
      AppCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: context.p.surfaceAlt,
                border: Border(bottom: BorderSide(color: context.p.border)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [kPrimary2, Color(0xFF17574E)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.lock_shield_fill,
                      size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'مصفوفة الصلاحيات',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'انقر أي خلية لتفعيل أو إلغاء الصلاحية — يُحفظ فورًا',
                        style: TextStyle(
                            color: context.p.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final table =
                    _permMatrixTable(context, st, roles, dark: dark);
                if (constraints.maxWidth >= 980) return table;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 980),
                    child: table,
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _PermGroup {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> keys;
  const _PermGroup(this.icon, this.title, this.color, this.keys);
}

const _definedPermGroups = <(IconData, String, Color, List<String>)>[
  (
    CupertinoIcons.person_3_fill,
    'المكلفون والبحث',
    Color(0xFF7FB8FF),
    ['taxpayers.view', 'taxpayers.edit', 'taxpayers.status']
  ),
  (
    CupertinoIcons.doc_text,
    'المحاضر',
    Color(0xFF9FE3C0),
    [
      'reports.view',
      'reports.create',
      'reports.approve',
      'reports.endorse',
      'reports.print',
      'reports.cancel'
    ]
  ),
  (
    CupertinoIcons.book,
    'السجلات والمتابعة',
    kGold,
    ['registers.view', 'registers.edit', 'statements.edit']
  ),
  (
    CupertinoIcons.eye_fill,
    'التحليلات والتنبيهات',
    Color(0xFFFFA99B),
    ['analytics.view', 'alerts.view', 'alerts.route']
  ),
  (
    CupertinoIcons.briefcase_fill,
    'التقارير',
    Color(0xFFD6C2FF),
    ['reports.center']
  ),
  (
    CupertinoIcons.lock_shield_fill,
    'المستخدمون والصلاحيات',
    kPrimary2,
    [
      'users.manage',
      'permissions.view',
      'permissions.manage',
      'serials.manage'
    ]
  ),
  (
    CupertinoIcons.checkmark_shield_fill,
    'التدقيق والسلامة',
    Color(0xFF9EC5FF),
    ['audit.view', 'integrity.view']
  ),
  (
    CupertinoIcons.archivebox_fill,
    'الأرشيف',
    Color(0xFFFFD27A),
    ['archive.view', 'archive.edit', 'archive.attachments']
  ),
  (
    CupertinoIcons.map_fill,
    'العمل الميداني',
    Color(0xFFB7F0D8),
    ['field.view']
  ),
  (
    CupertinoIcons.square_grid_2x2_fill,
    'الإعدادات',
    Color(0xFFE8B4B8),
    ['settings.manage']
  ),
];

final _permGroups = _computePermGroups();

/// يجمع الصلاحيات حسب الأقسام، ويُلحق أي صلاحية جديدة في مجموعة «أخرى»
/// حتى لا تضيع عند إضافة صلاحيات مستقبلًا.
List<_PermGroup> _computePermGroups() {
  final used = <String>{};
  final groups = <_PermGroup>[];
  for (final (icon, title, color, keys) in _definedPermGroups) {
    final valid = <String>[
      for (final key in keys)
        if (kPerms.containsKey(key) && used.add(key)) key,
    ];
    if (valid.isNotEmpty) groups.add(_PermGroup(icon, title, color, valid));
  }
  final rest = kPerms.keys.where((key) => !used.contains(key)).toList();
  if (rest.isNotEmpty) {
    groups.add(_PermGroup(CupertinoIcons.square_grid_2x2_fill,
        'صلاحيات أخرى', kPrimary, rest));
  }
  return groups;
}

Widget _permMatrixTable(BuildContext context, AppStore st,
    List<String> roles, {required bool dark}) {
  final grants = <String, Set<String>>{
    for (final r in roles) r: (st.perms[r] ?? const <String>[]).toSet(),
  };
  var zebra = 0;
  return Table(
    border: TableBorder.all(color: context.p.border, width: .6),
    columnWidths: const {0: FlexColumnWidth(3.2)},
    defaultColumnWidth: const FlexColumnWidth(1.1),
    children: [
      TableRow(
        decoration: BoxDecoration(color: context.p.surfaceAlt),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.lock_shield_fill,
                        size: 14, color: kPrimary2),
                    const SizedBox(width: 7),
                    Text('الإجراء',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: context.p.text)),
                  ],
                ),
                const SizedBox(height: 3),
                Text('الاسم البرمجي لكل صلاحية',
                    style:
                        TextStyle(color: context.p.muted, fontSize: 10.5)),
              ],
            ),
          ),
          for (var i = 0; i < roles.length; i++)
            _RoleHeaderCell(
              roleKey: roles[i],
              accentIndex: i,
              granted: grants[roles[i]]!.length,
              total: kPerms.length,
            ),
        ],
      ),
      for (final group in _permGroups) ...[
        TableRow(
          decoration: BoxDecoration(
            color: group.color.withValues(alpha: dark ? .20 : .10),
          ),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: group.color.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(group.icon, size: 17, color: group.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.title,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('${group.keys.length} صلاحية',
                            style: TextStyle(
                                fontSize: 9.5, color: context.p.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final _ in roles) const SizedBox(height: 36),
          ],
        ),
        for (final key in group.keys)
          _permRow(context, st, MapEntry(key, kPerms[key]!), roles,
              zebra: zebra++ % 2 == 1,
              dark: dark,
              granted: {
                for (final r in roles) r: grants[r]!.contains(key),
              }),
      ],
      TableRow(
        decoration: BoxDecoration(
          color: kPrimary2.withValues(alpha: dark ? .16 : .08),
        ),
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            child: Text('إجمالي الصلاحيات',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          for (final r in roles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${grants[r]!.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('من ${kPerms.length}',
                        style:
                            TextStyle(fontSize: 9, color: context.p.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

TableRow _permRow(BuildContext context, AppStore st,
    MapEntry<String, String> entry, List<String> roles,
    {required bool zebra,
    required bool dark,
    required Map<String, bool> granted}) {
  return TableRow(
    decoration: BoxDecoration(
      color: zebra
          ? (dark
              ? Colors.white.withValues(alpha: .035)
              : const Color(0xFFFAFBFA))
          : null,
    ),
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.value,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 2),
            Text(
              entry.key,
              style: TextStyle(fontSize: 9.5, color: context.p.muted),
            ),
          ],
        ),
      ),
      for (final r in roles)
        Tooltip(
          message: '${kRoles[r] ?? r}: ${entry.value}',
          child: _PermCell(
            granted: granted[r]!,
            onToggle: () => st.togglePerm(r, entry.key),
          ),
        ),
    ],
  );
}

/// زر تفعيل مدور فخم بدل مربع الاختيار الافتراضي.
class _PermCell extends StatelessWidget {
  final bool granted;
  final VoidCallback onToggle;
  const _PermCell({required this.granted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      splashColor: kPrimary2.withValues(alpha: .18),
      highlightColor: kPrimary2.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: granted
                  ? const LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [Color(0xFF2E8B6F), Color(0xFF17574E)])
                  : null,
              color: granted ? null : context.p.surface,
              border: Border.all(
                color: granted
                    ? Colors.transparent
                    : context.p.muted.withValues(alpha: .45),
                width: 1.3,
              ),
              boxShadow: granted
                  ? [
                      BoxShadow(
                        color: kPrimary2.withValues(alpha: .30),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              CupertinoIcons.checkmark_alt,
              size: granted ? 18 : 15,
              color: granted
                  ? Colors.white
                  : context.p.muted.withValues(alpha: .35),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleHeaderCell extends StatelessWidget {
  final String roleKey;
  final int accentIndex;
  final int granted;
  final int total;
  const _RoleHeaderCell({
    required this.roleKey,
    required this.accentIndex,
    required this.granted,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final color = _rolePalette[accentIndex % _rolePalette.length];
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                color.withValues(alpha: .42),
                color.withValues(alpha: .14),
              ],
            ),
            shape: BoxShape.circle,
            border:
                Border.all(color: color.withValues(alpha: .45), width: 1.2),
          ),
          child: Icon(_roleIcons[roleKey] ?? CupertinoIcons.person_fill,
              size: 21, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          kRoles[roleKey]!,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.25),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$granted / $total',
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ]),
    );
  }
}

/// توزيع التنبيهات — من يصله كل تنبيه. مدير النظام يستلم دائماً.
class RoutingScreen extends StatelessWidget {
  const RoutingScreen({super.key});

  static const _roleCols = <String, (IconData, String, Color)>{
    'role:sectionHead':
        (CupertinoIcons.person_2_fill, 'رئيس قسم الواردات', kPrimary2),
    'role:deptHead': (CupertinoIcons.person_2_fill, 'رئيس الدائرة', kGold),
    'role:fieldHead': (CupertinoIcons.person_2_fill, 'الشعبة الميدانية', Color(0xFF7FB8FF)),
    'role:officeHead':
        (CupertinoIcons.person_2_fill, 'الشعبة المكتبية', Color(0xFF9FE3C0)),
    'role:archiveHead':
        (CupertinoIcons.person_2_fill, 'شعبة الأرشيف', Color(0xFFD6C2FF)),
  };
  static const _divCols = <String, (String, Color)>{
    'div:field': ('الميدانية', Color(0xFF7FB8FF)),
    'div:office': ('المكتبية', Color(0xFF9FE3C0)),
    'div:archive': ('الأرشيف', Color(0xFFFFD27A)),
  };

  Future<void> _users(BuildContext context, String type) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => _AlertUsersDialog(type: type),
      );

  Color _alertColor(String key) {
    if (key.contains('critical') || key.contains('security')) return kRed;
    if (key.contains('high')) return const Color(0xFFFF9F0A);
    if (key.contains('medium')) return kGold;
    if (key.contains('late')) return const Color(0xFF7FB8FF);
    if (key.contains('cancelled')) return const Color(0xFF9FE3C0);
    if (key.contains('gap')) return const Color(0xFFD6C2FF);
    if (key.contains('objection')) return const Color(0xFFFFA99B);
    return kPrimary2;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final designated = <String>{};
    for (final entries in st.routing.values) {
      for (final e in entries) {
        if (e.startsWith('user:')) designated.add(e);
      }
    }

    return PageBody(
      contentMaxWidth: double.infinity,
      children: [
        PageHeader(
          'توزيع التنبيهات',
          subtitle:
              'حدّد لكل تنبيه الجهات المستهدفة. يُحفظ أي تغيير فورًا ويُسجَّل في سجل العمليات.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => context.go('/audit'),
              icon: const Icon(CupertinoIcons.time, size: 17),
              label: const Text('سجل العمليات'),
            ),
          ],
        ),
        StatGrid(
          children: [
            _UserStat(
                label: 'أنواع التنبيهات',
                value: '${kAlertTypes.length}',
                icon: CupertinoIcons.bell_fill,
                color: kGold),
            _UserStat(
                label: 'نقطة توزيع',
                value: '${_roleCols.length + _divCols.length}',
                icon: CupertinoIcons.building_2_fill,
                color: kPrimary2),
            _UserStat(
                label: 'مستخدمون محددون',
                value: '${designated.length}',
                icon: CupertinoIcons.person_badge_plus,
                color: const Color(0xFF7FB8FF)),
          ],
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: context.p.surfaceAlt,
                  border: Border(
                      bottom: BorderSide(color: context.p.border)),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [kGold, Color(0xFFB8860B)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withValues(alpha: .35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(CupertinoIcons.bell_fill,
                        size: 21, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مصفوفة توزيع التنبيهات',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'انقر أي خلية لتفعيل أو إلغاء الوجهة — يُحفظ فورًا',
                          style: TextStyle(
                              color: context.p.muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final table = _routingTable(context, st);
                  if (constraints.maxWidth >= 880) return table;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 880),
                      child: table,
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: kPrimary2.withValues(alpha: context.p.isDark ? .14 : .07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kPrimary2.withValues(alpha: .25)),
          ),
          child: Row(children: [
            const Icon(CupertinoIcons.shield_fill, size: 22, color: kPrimary2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'مدير النظام يستلم كل التنبيهات دائمًا — لا يمكن استثناء حسابه من التوزيع.',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _routingTable(BuildContext context, AppStore st) {
    final columns = <String, _RouteCol>{
      for (final e in _roleCols.entries)
        e.key: _RouteCol(_roleIcons[e.key.substring(5)] ?? e.value.$1,
            e.value.$2, e.value.$3),
      for (final e in _divCols.entries)
        e.key: _RouteCol(
            CupertinoIcons.building_2_fill, e.value.$1, e.value.$2),
    };
    return Table(
      columnWidths: const {0: FlexColumnWidth(3)},
      defaultColumnWidth: const FlexColumnWidth(1.15),
      border: TableBorder.all(color: context.p.border, width: .6),
      children: [
        TableRow(
          decoration: BoxDecoration(color: context.p.surfaceAlt),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
              child: Row(children: [
                const Icon(CupertinoIcons.bell_fill,
                    size: 14, color: kPrimary2),
                const SizedBox(width: 8),
                const Text('التنبيه',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
            for (final c in columns.entries) _routeHeadCell(c.value),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary2.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.person_crop_circle_fill,
                      size: 19, color: kPrimary2),
                ),
                const SizedBox(height: 6),
                Text('مستخدمون',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.p.muted)),
              ]),
            ),
          ],
        ),
        for (var index = 0; index < kAlertTypes.entries.length; index++)
          _routeRow(context, st, kAlertTypes.entries.elementAt(index),
              columns, index.isOdd),
      ],
    );
  }

  Widget _routeHeadCell(_RouteCol col) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: col.color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col.color.withValues(alpha: .30)),
            ),
            child: Icon(col.icon, size: 17, color: col.color),
          ),
          const SizedBox(height: 6),
          Text(
            col.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.25),
          ),
        ]),
      );

  TableRow _routeRow(BuildContext context, AppStore st,
      MapEntry<String, String> entry, Map<String, _RouteCol> columns, bool zebra) {
    final selected = (st.routing[entry.key] ?? [])
        .where((e) => e.startsWith('user:'))
        .length;
    final dark = context.p.isDark;
    return TableRow(
      decoration: BoxDecoration(
        color: zebra
            ? (dark
                ? Colors.white.withValues(alpha: .035)
                : const Color(0xFFFAFBFA))
            : null,
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 7, 14, 7),
          child: Row(children: [
            Container(
              width: 8,
              height: 34,
              decoration: BoxDecoration(
                color: _alertColor(entry.key),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
          ]),
        ),
        for (final c in columns.keys)
          _PermCell(
            granted: (st.routing[entry.key] ?? []).contains(c),
            onToggle: () => st.toggleRoute(entry.key, c),
          ),
        Center(
          child: InkWell(
            onTap: () => _users(context, entry.key),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 12, 7),
              decoration: BoxDecoration(
                color: selected > 0
                    ? kPrimary2.withValues(alpha: .12)
                    : context.p.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected > 0
                      ? kPrimary2.withValues(alpha: .40)
                      : context.p.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected > 0
                        ? CupertinoIcons.person_crop_circle_fill
                        : CupertinoIcons.plus_circle,
                    size: 15,
                    color: selected > 0 ? kPrimary2 : context.p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected > 0 ? '$selected مستخدم' : 'تحديد',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected > 0 ? kPrimary2 : context.p.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteCol {
  final IconData icon;
  final String label;
  final Color color;
  const _RouteCol(this.icon, this.label, this.color);
}

class _AlertUsersDialog extends StatefulWidget {
  final String type;
  const _AlertUsersDialog({required this.type});
  @override
  State<_AlertUsersDialog> createState() => _AlertUsersDialogState();
}

class _AlertUsersDialogState extends State<_AlertUsersDialog> {
  final q = TextEditingController();

  static const _palette = [
    kPrimary2,
    kGold,
    Color(0xFF7FB8FF),
    Color(0xFF9FE3C0),
    Color(0xFFFFA99B),
    Color(0xFF9EC5FF),
    Color(0xFFFFD27A),
    Color(0xFFD6C2FF),
  ];

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Color _colorFor(String id) => _palette[id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final query = normAr(q.text.trim());
    final users = st.users
        .where((u) =>
            query.isEmpty ||
            normAr('${u.name} ${u.username}').contains(query))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final routing = st.routing[widget.type] ?? [];
    final selectedCount = routing.where((e) => e.startsWith('user:')).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kGold.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(CupertinoIcons.bell_fill, size: 21, color: kGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تسليم: ${kAlertTypes[widget.type]}',
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$selectedCount مستخدم محدد — يصله التنبيه إضافةً للوجهات العامة',
                style: TextStyle(color: context.p.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ]),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(children: [
          TextField(
            controller: q,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث باسم المستخدم أو حسابه…',
              hintStyle: TextStyle(color: context.p.muted, fontSize: 13),
              prefixIcon: Icon(CupertinoIcons.search,
                  size: 18, color: context.p.muted),
              filled: true,
              fillColor: context.p.surfaceAlt,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: kPrimary2.withValues(alpha: .55), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final key = 'user:${user.id}';
                final checked = routing.contains(key);
                final color = _colorFor(user.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 12, 9),
                  decoration: BoxDecoration(
                    color: checked
                        ? kPrimary2.withValues(alpha: .08)
                        : context.p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: checked
                          ? kPrimary2.withValues(alpha: .35)
                          : context.p.border,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0],
                          style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700)),
                          Text(
                            kRoles[user.role] ?? user.role,
                            style: TextStyle(
                                color: context.p.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: checked,
                      activeThumbColor: Colors.white,
                      activeTrackColor: kPrimary2,
                      onChanged: (_) => st.toggleRoute(widget.type, key),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('تم'),
        ),
      ],
    );
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
  final String? userId;
  const AuditScreen({super.key, this.userId});
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

  static const _avatarPalette = [
    kPrimary2,
    kGold,
    Color(0xFF7FB8FF),
    Color(0xFF9FE3C0),
    Color(0xFFFFA99B),
    Color(0xFF9EC5FF),
    Color(0xFFFFD27A),
    Color(0xFFD6C2FF),
  ];

  Color _avatarColor(String key) {
    final hash = key.hashCode & 0x7fffffff;
    return _avatarPalette[hash % _avatarPalette.length];
  }

  (IconData, Color) _actionMeta(String action) {
    if (action.contains('مزامنة')) {
      return (CupertinoIcons.arrow_clockwise_circle_fill, kPrimary2);
    }
    if (action.contains('إنشاء') || action.contains('إضافة') ||
        action.contains('استلام')) {
      return (CupertinoIcons.plus_circle_fill, const Color(0xFF34C759));
    }
    if (action.contains('تعديل') || action.contains('تحديث') ||
        action.contains('تغيير') || action.contains('ترحيل') ||
        action.contains('تحديث')) {
      return (CupertinoIcons.pencil, kGold);
    }
    if (action.contains('إلغاء') || action.contains('حذف')) {
      return (CupertinoIcons.trash, kRed);
    }
    if (action.contains('إغلاق')) {
      return (CupertinoIcons.lock_fill, kRed);
    }
    if (action.contains('اعتماد') || action.contains('قفل') ||
        action.contains('ختم')) {
      return (CupertinoIcons.checkmark_seal_fill, kGold);
    }
    if (action.contains('تصدير') || action.contains('استعادة')) {
      return (CupertinoIcons.arrow_down_circle_fill, const Color(0xFF7FB8FF));
    }
    if (action.contains('دخول') || action.contains('خروج') ||
        action.contains('تسجيل الدخول')) {
      return (CupertinoIcons.person_crop_circle, const Color(0xFF9EC5FF));
    }
    if (action.contains('كلمة مرور')) {
      return (CupertinoIcons.lock_shield_fill, kGold);
    }
    if (action.contains('توقيع')) {
      return (CupertinoIcons.signature, kPrimary2);
    }
    return (CupertinoIcons.info, kPrimary2);
  }

  AppUser? _findUser(AppStore store, String id) {
    for (final u in store.users) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppStore>();
    final nq = normAr(q.text);
    final scopedUser =
        widget.userId == null ? null : _findUser(st, widget.userId!);
    final scopedName = scopedUser?.name;
    final scopedMode = scopedName != null;
    final users = scopedMode
        ? [scopedName]
        : {
            for (final user in st.users)
              if (user.name.trim().isNotEmpty) user.name.trim(),
            for (final entry in st.audit)
              if (entry.user.trim().isNotEmpty) entry.user.trim(),
          }.toList()
          ..sort();
    final userOptions = scopedMode
        ? {scopedName: scopedName}
        : {
            '': 'كل المستخدمين',
            for (final user in users) user: user,
          };
    final effectiveFilter = scopedMode ? scopedName : userFilter;
    final list = st.audit.reversed
        .where((e) =>
            (effectiveFilter.isEmpty || e.user == effectiveFilter) &&
            (nq.isEmpty ||
                normAr('${e.user} ${e.action} ${e.entity} ${e.detail}')
                    .contains(nq)))
        .toList();
    final uniqueActions = <String>{};
    final uniqueUsers = <String>{};
    for (final e in st.audit) {
      if (widget.userId != null && e.user != scopedName) continue;
      uniqueActions.add(e.action);
      uniqueUsers.add(e.user);
    }

    return PageBody(children: [
      if (scopedMode)
        BackBreadcrumb(
          parent: 'الملف الشخصي',
          current: 'سجل نشاطه',
          fallbackLocation: '/users/${widget.userId}/profile',
        ),
      PageHeader(
        scopedMode ? 'سجل عمليات $scopedName' : 'سجل العمليات',
        subtitle: scopedMode
            ? 'كل ما فعله هذا المستخدم في النظام — من تعديل وإضافة وفتح وتصدير'
            : 'منفذ العملية هو المستخدم الذي أجراها، والعنصر المتأثر هو السجل الذي عُدّل. '
                'التفاصيل تعرض معلومات إضافية. السجل للقراءة فقط ومترابط ببصمات تكشف التعديل أو الحذف.',
        actions: [
          OutlinedButton.icon(
            onPressed: () => context.go('/integrity'),
            icon: const Icon(CupertinoIcons.checkmark_shield_fill, size: 17),
            label: const Text('فحص السلامة'),
          ),
        ],
      ),
      StatGrid(
        children: [
          _UserStat(
              label: 'إجمالي السجلات',
              value: '${st.audit.length}',
              icon: CupertinoIcons.doc_text,
              color: kPrimary2),
          _UserStat(
              label: 'المعروض حالياً',
              value: '${list.length}',
              icon: CupertinoIcons.eye_fill,
              color: kGold),
          _UserStat(
              label: 'المستخدمون',
              value: '${uniqueUsers.length}',
              icon: CupertinoIcons.person_2_fill,
              color: const Color(0xFF7FB8FF)),
          _UserStat(
              label: 'أنواع العمليات',
              value: '${uniqueActions.length}',
              icon: CupertinoIcons.square_grid_2x2_fill,
              color: const Color(0xFF9FE3C0)),
        ],
      ),
      AppCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [kPrimary2, Color(0xFF17574E)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: .28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.doc_text,
                    size: 22, color: Colors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'العثور على العمليات',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ابحث بالمستخدم • العملية • العنصر المتأثر',
                      style: TextStyle(
                          color: context.p.muted, fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(11, 7, 11, 7),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: context.p.isDark ? .16 : .10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGold.withValues(alpha: .4)),
                ),
                child: Row(children: [
                  const Icon(CupertinoIcons.lock_fill,
                      size: 12, color: Color(0xFF8A5A00)),
                  const SizedBox(width: 6),
                  Text(
                    'للقراءة فقط',
                    style: TextStyle(
                      color: context.p.isDark
                          ? const Color(0xFFE9CEA8)
                          : const Color(0xFF6B4A0C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: q,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث بكلمة من السجل…',
                prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                suffixIcon: q.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill,
                            size: 19),
                        onPressed: () {
                          q.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: context.p.surfaceAlt,
                contentPadding:
                    const EdgeInsetsDirectional.fromSTEB(15, 17, 15, 17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: kPrimary2.withValues(alpha: .6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _IconDropdown(
                    icon: CupertinoIcons.person_crop_circle,
                    label: scopedMode
                        ? 'المستخدم: $scopedName'
                        : 'عرض عمليات المستخدم',
                    value: scopedMode ? scopedName : userFilter,
                    options: userOptions,
                    onChanged: (v) {
                      if (scopedMode) return;
                      setState(() => userFilter = v);
                    },
                  ),
                ),
                if (!scopedMode && (userFilter.isNotEmpty || q.text.isNotEmpty)) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      q.clear();
                      setState(() => userFilter = '');
                    },
                    icon: const Icon(CupertinoIcons.clear, size: 15),
                    label: const Text(
                      'مسح',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(CupertinoIcons.doc_text_search,
                      size: 13, color: kPrimary2),
                  const SizedBox(width: 6),
                  Text(
                    'عدد العمليات المعروضة: ${list.length}',
                    style: TextStyle(
                        color: context.p.muted, fontSize: 12, height: 1),
                  ),
                ]),
                if (list.isNotEmpty)
                  Text(
                    'من ${st.audit.length} سجل',
                    style: TextStyle(
                        color: context.p.muted, fontSize: 11, height: 1),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (list.isEmpty)
        AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(CupertinoIcons.doc_text_search,
                  size: 46, color: context.p.muted),
              const SizedBox(height: 10),
              const Text(
                'لا توجد عمليات مطابقة',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'جرّب مسح البحث أو تغيير الفلتر.',
                style: TextStyle(color: context.p.muted, fontSize: 13),
              ),
            ]),
          ),
        )
      else
        GridTable(
          heads: const [
            'منفذ العملية',
            'نوع العملية',
            'العنصر المتأثر',
            'تفاصيل إضافية',
            'الوقت',
            'البصمة',
          ],
          flex: const [2, 3, 2, 4, 2, 2],
          minWidth: 1120,
          rows: [
            for (final e in list)
              [
                Tooltip(
                  message: e.user,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            _avatarColor(e.user).withValues(alpha: .2),
                        child: Text(
                          e.user.trim().isEmpty
                              ? '؟'
                              : e.user.trim().substring(0, 1),
                          style: TextStyle(
                              color: _avatarColor(e.user),
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          e.user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActionCell(action: e.action, meta: _actionMeta),
                _auditCell(e.entity),
                _auditCell(e.detail.isEmpty ? '—' : e.detail),
                Tooltip(
                  message: e.ts,
                  child: cellText(fmtDT12(DateTime.parse(e.ts))),
                ),
                _FingerprintCell(hash: e.hash),
              ],
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
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
}

class _ActionCell extends StatelessWidget {
  final String action;
  final (IconData, Color) Function(String) meta;
  const _ActionCell({required this.action, required this.meta});

  @override
  Widget build(BuildContext context) {
    final m = meta(action);
    return Tooltip(
      message: action,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: m.$2.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: Icon(m.$1, size: 13, color: m.$2),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 8, 3),
              decoration: BoxDecoration(
                color: m.$2.withValues(alpha: context.p.isDark ? .18 : .09),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: m.$2.withValues(alpha: .3)),
              ),
              child: Text(
                action,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: m.$2,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FingerprintCell extends StatelessWidget {
  final String hash;
  const _FingerprintCell({required this.hash});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'بصمة العملية: $hash',
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 6, 3),
          decoration: BoxDecoration(
            color: context.p.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.lock_fill, size: 10, color: kPrimary2),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  hash.substring(0, 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ],
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
    final serialMode = st.settings['serialMode'] as String? ?? 'manual';

    return PageBody(
      contentMaxWidth: double.infinity,
      children: [
        PageHeader(
          'الإعدادات والنسخ الاحتياطي',
          subtitle: 'قواعد النظام والنسخ والاستعادة',
          actions: [
            FilledButton.icon(
              onPressed: () {
                for (final k in nums.keys) {
                  final v = num.tryParse(ctl[k]?.text ?? '');
                  if (v != null) st.setSetting(k, v);
                }
                toast(context, 'حُفظت الإعدادات');
              },
              icon: const Icon(CupertinoIcons.checkmark_alt, size: 17),
              label: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
        StatGrid(children: [
          _UserStat(
              label: 'أنواع المخالفات',
              value: '${types.length}',
              icon: CupertinoIcons.doc_text,
              color: kPrimary2),
          _UserStat(
              label: 'الترقيم الحالي',
              value: serialMode == 'manual' ? 'يدوي' : 'تلقائي',
              icon: CupertinoIcons.list_number,
              color: kGold),
          _UserStat(
              label: 'المظهر',
              value: st.darkMode ? 'داكن' : 'فاتح',
              icon: st.darkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max,
              color: const Color(0xFF9BB0FF)),
        ]),
        _premiumSection(
          context,
          icon: CupertinoIcons.list_number,
          accent: kGold,
          title: 'ترقيم المحاضر',
          subtitle: 'كيف يأخذ كل محضر رقمه التسلسلي',
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final manual = _serialOption(context,
                icon: CupertinoIcons.pencil,
                title: 'يدوي — رقم مطبوع مسبقاً',
                subtitle:
                    'الرقم مدوّن في الدفتر يدخله الموظف، ويتحقق النظام من التكرار ومن دفاتر الأرقام المسلّمة.',
                selected: serialMode == 'manual',
                onTap: () => st.setSetting('serialMode', 'manual'));
            final auto = _serialOption(context,
                icon: CupertinoIcons.number,
                title: 'تلقائي — رقمه من النظام',
                subtitle:
                    'النظام يولّد رقماً متسلسلاً تلقائياً عند إنشاء كل محضر دون تدخل الموظف.',
                selected: serialMode == 'auto',
                onTap: () => st.setSetting('serialMode', 'auto'));
            if (wide) {
              return Row(
                children: [
                  Expanded(child: manual),
                  const SizedBox(width: 14),
                  Expanded(child: auto),
                ],
              );
            }
            return Column(
              children: [
                manual,
                const SizedBox(height: 10),
                auto,
              ],
            );
          }),
        ),
        _premiumSection(
          context,
          icon: st.darkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max,
          accent: const Color(0xFF9BB0FF),
          title: 'المظهر',
          subtitle: 'يُطبَّق فوراً ويُحفظ مع الإعدادات — متاح أيضاً من زر القمر/الشمس أعلى الشاشة',
          child: Row(children: [
            Expanded(
              child: Text(
                st.darkMode ? 'الوضع الداكن مفعّل' : 'الوضع الفاتح مفعّل',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
            Switch(
              value: st.darkMode,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF3D4A7A),
              onChanged: st.setDarkMode,
            ),
          ]),
        ),
        _premiumSection(
          context,
          icon: CupertinoIcons.square_grid_2x2_fill,
          accent: kPrimary2,
          title: 'القواعد والعتبات',
          subtitle: 'القيم الافتراضية التي يعتمدها النظام في التحليلات والغرامات',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in nums.entries)
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: c(st, e.key),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: e.value,
                      filled: true,
                      fillColor: context.p.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      labelStyle:
                          TextStyle(color: context.p.muted, fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: kPrimary2.withValues(alpha: .6), width: 1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _premiumSection(
          context,
          icon: CupertinoIcons.doc_text,
          accent: kGold,
          title: 'أنواع المخالفات',
          subtitle: 'مخالفات يضيفها الموظف عند إنشاء محضر',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
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
                  icon: const Icon(CupertinoIcons.add, size: 17),
                  label: const Text('إضافة نوع'),
                ),
              ]),
              const SizedBox(height: 10),
              if (types.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'لا توجد أنواع مخالفات — أضف أول نوع.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.p.muted, fontSize: 12.5),
                  ),
                )
              else
                for (var i = 0; i < types.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: context.p.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.p.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            size: 17,
                            color: kGold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          types[i]['name'] as String,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف النوع',
                        icon: Icon(CupertinoIcons.trash,
                            size: 20, color: kRed.withValues(alpha: .85)),
                        onPressed: () =>
                            st.setViolationTypes([...types]..removeAt(i))),
                    ]),
                  ),
            ],
          ),
        ),
        _premiumSection(
          context,
          icon: CupertinoIcons.arrow_down_circle_fill,
          accent: kPrimary2,
          title: 'النسخ الاحتياطي',
          subtitle: 'خذ نسخة من بيانات النظام أو استعدها — في الإنتاج تُؤخذ النسخ من SQL Server على الخادم',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _backupAction(context,
                    icon: CupertinoIcons.arrow_down_circle_fill,
                    color: kPrimary2,
                    title: 'نسخ نسخة احتياطية',
                    subtitle: 'نسخ كل بيانات النظام إلى الحافظة للاحتفاظ بها',
                    onTap: () async {
                      await Clipboard.setData(
                          ClipboardData(text: st.exportAll()));
                      if (context.mounted) {
                        toast(context, 'نُسخت النسخة الاحتياطية إلى الحافظة');
                      }
                    }),
                _backupAction(context,
                    icon: CupertinoIcons.arrow_clockwise_circle_fill,
                    color: kGold,
                    title: 'استعادة نسخة',
                    subtitle: 'الصق محتوى نسخة صالحة لاسترجاع البيانات',
                    onTap: () => _restoreBackup(context)),
                _backupAction(context,
                    icon: CupertinoIcons.trash,
                    color: kRed,
                    title: 'إعادة البيانات التجريبية',
                    subtitle: 'مسح كل البيانات الحالية وإرجاع العرض التوضيحي',
                    onTap: () async {
                      if (await confirmDialog(context,
                              'إعادة البيانات التجريبية',
                              'ستُحذف كل البيانات الحالية. المتابعة؟') &&
                          context.mounted) {
                        st.resetDemo();
                      }
                    }),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
                decoration: BoxDecoration(
                  color: kGold.withValues(alpha: context.p.isDark ? .10 : .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGold.withValues(alpha: .30)),
                ),
                child: Row(children: [
                  const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                      size: 18, color: kGold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الاستعادة تعيد البيانات فوراً ولا يمكن التراجع عنها — تأكد من حفظ نسخة قبل أي استعادة.',
                      style: TextStyle(
                          color: context.p.muted, fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final st = context.read<AppStore>();
    final t = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('استعادة نسخة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: t,
            maxLines: 10,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'الصق محتوى النسخة هنا…',
              hintStyle: TextStyle(color: context.p.muted, fontSize: 13),
              filled: true,
              fillColor: context.p.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: kGold.withValues(alpha: .6), width: 1.5),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      toast(
          context,
          st.importAll(t.text)
              ? 'تمت الاستعادة. سجّل الدخول من جديد'
              : 'النسخة غير صالحة');
    }
  }
}

/// ترويسة قسم مميز في الإعدادات — أيقونة متدرجة وعنوان ووصف.
Widget _premiumSection(
  BuildContext context, {
  required IconData icon,
  required Color accent,
  required String title,
  required String subtitle,
  required Widget child,
}) =>
    AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
            decoration: BoxDecoration(
              color: context.p.surfaceAlt,
              border: Border(bottom: BorderSide(color: context.p.border)),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      accent,
                      accent.withValues(alpha: .55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(color: context.p.muted, fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: child,
          ),
        ]),
      ),
    );

/// خيار اختيار في صفحة الإعدادات (ترقيم المحاضر).
Widget _serialOption(BuildContext context,
    {required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: selected ? kGold.withValues(alpha: .08) : context.p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? kGold.withValues(alpha: .7)
              : context.p.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: kGold.withValues(alpha: .18),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  kGold.withValues(alpha: .5),
                  kGold.withValues(alpha: .15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: kGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? kGold : Colors.transparent,
              border: Border.all(
                color: selected
                    ? kGold
                    : context.p.muted.withValues(alpha: .4),
                width: 1.6,
              ),
            ),
            child: selected
                ? const Icon(CupertinoIcons.checkmark_alt,
                    size: 15, color: Colors.white)
                : null,
          ),
        ]),
        const SizedBox(height: 12),
        Text(subtitle,
            style: TextStyle(
                color: context.p.muted, fontSize: 11.5, height: 1.55)),
      ]),
    ),
  );
}

/// مربّع إجراء في النسخ الاحتياطي.
Widget _backupAction(BuildContext context,
    {required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      width: 255,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: TextStyle(
                  color: context.p.muted, fontSize: 11, height: 1.45)),
        ],
      ),
    ),
  );
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

/// توهج دائري للرأس الداكن.
class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
        child: SizedBox(width: size, height: size),
      );
}

/// صورة دائرية كبيرة مع حلقة ذهبية ونقطة حالة.
class _LargeAvatar extends StatelessWidget {
  final AppStore store;
  final AppUser user;
  final Color statusColor;
  const _LargeAvatar({
    required this.store,
    required this.user,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final initial =
        user.name.trim().isEmpty ? '؟' : user.name.trim().substring(0, 1);
    return SizedBox(
      width: size + 16,
      height: size + 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFFE9D9B4), Color(0xFFA98545)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [Color(0xFF2E8C7E), Color(0xFF17574E)],
                  ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : Image.memory(bytes, fit: BoxFit.cover);
                    },
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 2,
            bottom: 6,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 6,
                    spreadRadius: -2,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريحة زجاجية فاخرة للرأس الداكن.
class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .22)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: .95)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .95),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ]),
      );
}

/// شارة حالة بجانب الاسم في الرأس.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(11, 5, 11, 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .55)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      );
}

/// لافتة تنبيه ذهبية/حمراء داخل الحوار.
class _BannerNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _BannerNote(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.p.isDark ? .16 : .1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.p.isDark
                    ? Colors.white.withValues(alpha: .92)
                    : context.p.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
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
  Widget build(BuildContext context) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
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
      onTap: () => context.go('/users/${user.id}/profile'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _UserAvatar(
              store: store,
              user: user,
              radius: 36,
              statusColor: _statusColor,
              borderColor: context.p.surface,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      StatusBadge(_userStatusLabel(user.status)),
                      if (user.passwordChangeRequired)
                        const StatusBadge('تغيير كلمة المرور مطلوب'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      color: context.p.muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _MetaChip(
                icon: CupertinoIcons.briefcase_fill,
                label: kRoles[user.role] ?? user.role,
                color: kPrimary2),
            if (division.isNotEmpty)
              _MetaChip(
                  icon: CupertinoIcons.building_2_fill,
                  label: division,
                  color: kPrimary2),
            if (managerName.isNotEmpty)
              _MetaChip(
                  icon: CupertinoIcons.person_2_fill,
                  label: 'المسؤول: $managerName',
                  color: kGold),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
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
          const SizedBox(height: 14),
          Divider(height: 1, color: context.p.border),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _CircleIconButton(
                tooltip: 'صفحة المستخدم',
                onPressed: () => context.go('/users/${user.id}/profile'),
                icon: CupertinoIcons.person_crop_circle_fill,
                color: kPrimary2,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                tooltip: 'تفاصيل وسجل الحساب',
                onPressed: onHistory,
                icon: CupertinoIcons.info,
                color: kGold,
              ),
              const SizedBox(width: 8),
              if (onEdit != null)
                _CircleIconButton(
                  tooltip: 'تعديل المستخدم',
                  onPressed: onEdit,
                  icon: CupertinoIcons.pencil,
                  color: kPrimary2,
                ),
              if (onEdit != null) const SizedBox(width: 8),
              if (onToggleActive != null)
                _CircleIconButton(
                  tooltip: user.active ? 'تعطيل مؤقتًا' : 'إعادة تفعيل',
                  onPressed: onToggleActive,
                  icon: user.active
                      ? CupertinoIcons.pause_circle_fill
                      : CupertinoIcons.checkmark_seal_fill,
                  color: user.active ? kGold : const Color(0xFF34C759),
                ),
              if (onToggleActive != null) const SizedBox(width: 8),
              if (onClose != null)
                _CircleIconButton(
                  tooltip: 'إغلاق الحساب نهائيًا',
                  onPressed: onClose,
                  icon: CupertinoIcons.lock_fill,
                  color: kRed,
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
  final String? subtitle;
  final Color accent;
  final List<Widget> rows;
  const _HistorySection({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      accent.withValues(alpha: .28),
                      accent.withValues(alpha: .1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: accent.withValues(alpha: .35)),
                ),
                child: Icon(icon, size: 21, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                            color: context.p.muted, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            for (final row in rows) ...[
              row,
              if (row != rows.last) const Divider(height: 16),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (accent ?? kPrimary2).withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 17,
                    color: accent ?? kPrimary2),
              ),
              const SizedBox(width: 12),
            ] else
              const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        color: context.p.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accent ?? context.p.text,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

/// شاشة إنشاء حساب جديد — تصميم أفخم: رأس ترقية، صورة المستخدم، حقول مصقولة.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final un = TextEditingController();
  final pw = TextEditingController();
  PickedUserPhoto? selectedPhoto;
  String? err;
  late String role;
  late String division;
  late String managerId;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final required = store.nextRequiredLeadershipAccount;
    role = required?.role ?? 'user';
    division = required?.division ?? 'field';
    final candidates = _managersFor(role, division);
    managerId = candidates.length == 1 ? candidates.first.id : '';
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    un.dispose();
    pw.dispose();
    super.dispose();
  }

  bool _roleAvailable(String role, String division) {
    final store = context.read<AppStore>();
    return !store.users.any((user) =>
        user.active &&
        user.role == role &&
        (!isDivisionHeadRole(role) || user.division == division));
  }

  String? _managerRoleFor(String role, String division) => switch (role) {
        'sectionHead' || 'infoSectionHead' => 'financeDirector',
        'deptHead' => 'sectionHead',
        'fieldHead' || 'officeHead' || 'archiveHead' => 'deptHead',
        'monitor' || 'user' => headRoleForDivision(division),
        _ => null,
      };

  List<AppUser> _managersFor(String role, String division) {
    final expectedRole = _managerRoleFor(role, division);
    if (expectedRole == null) return [];
    final store = context.read<AppStore>();
    return store.users
        .where((user) =>
            user.active &&
            user.role == expectedRole &&
            (!isDivisionHeadRole(expectedRole) || user.division == division))
        .toList();
  }

  List<String> _rolesFor(String division) {
    final store = context.read<AppStore>();
    final required = store.nextRequiredLeadershipAccount;
    if (required != null) {
      return division == required.division ? [required.role] : [];
    }
    if (division.isEmpty) {
      return [
        if (_roleAvailable('financeDirector', '')) 'financeDirector',
        if (_roleAvailable('sectionHead', '') &&
            _managersFor('sectionHead', '').isNotEmpty)
          'sectionHead',
        if (_roleAvailable('infoSectionHead', '') &&
            _managersFor('infoSectionHead', '').isNotEmpty)
          'infoSectionHead',
        if (_roleAvailable('deptHead', '') &&
            _managersFor('deptHead', '').isNotEmpty)
          'deptHead',
        'sysadmin',
      ];
    }
    return [
      if (_roleAvailable('financeDirector', '')) 'financeDirector',
      if (_roleAvailable('sectionHead', '') &&
          _managersFor('sectionHead', '').isNotEmpty)
        'sectionHead',
      if (_roleAvailable('infoSectionHead', '') &&
          _managersFor('infoSectionHead', '').isNotEmpty)
        'infoSectionHead',
      if (_roleAvailable('deptHead', '') &&
          _managersFor('deptHead', '').isNotEmpty)
        'deptHead',
      if (roleAvailableSafe(headRoleForDivision(division), division) &&
          _managersFor(headRoleForDivision(division) ?? '', division)
              .isNotEmpty)
        headRoleForDivision(division)!,
      if (division == 'field' &&
          _managersFor('monitor', division).isNotEmpty)
        'monitor',
      'user',
      'sysadmin',
    ];
  }

  bool roleAvailableSafe(String? role, String division) {
    if (role == null) return false;
    return _roleAvailable(role, division);
  }

  void _chooseDefaultManager() {
    final candidates = _managersFor(role, division);
    final id = candidates.length == 1 ? candidates.first.id : '';
    setState(() => managerId = id);
  }

  String _managerLabel(AppUser manager) =>
      '${manager.name} (${kRoles[manager.role]})';

  Future<void> _create(BuildContext context, AppStore store) async {
    if (name.text.trim().isEmpty ||
        un.text.trim().isEmpty ||
        pw.text.length < 6) {
      setState(() => err = 'أكمل الحقول. كلمة المرور 6 أحرف على الأقل');
      return;
    }
    if (_managerRoleFor(role, division) != null && managerId.isEmpty) {
      setState(() => err = 'لا يوجد مسؤول مباشر مناسب لهذا الدور والشعبة');
      return;
    }
    final account = AppUser(
      id: newId(),
      name: name.text.trim(),
      phone: phone.text.trim(),
      username: un.text.trim(),
      passHash: '',
      role: role,
      division: division,
      managerId: managerId,
    );
    final e = store.addUser(account, pw.text);
    if (e != null) {
      setState(() => err = e);
      return;
    }
    if (selectedPhoto != null) {
      try {
        final photoError = await store.setUserPhoto(
          account.id,
          name: selectedPhoto!.name,
          mime: selectedPhoto!.mime,
          bytes: selectedPhoto!.bytes,
        );
        if (photoError != null && context.mounted) {
          toast(context, 'تم إنشاء الحساب لكن تعذر حفظ الصورة: $photoError');
        }
      } catch (error) {
        if (context.mounted) {
          toast(context, 'تم إنشاء الحساب لكن تعذر حفظ الصورة: $error');
        }
      }
    }
    if (!context.mounted) return;
    toast(context, 'تم إنشاء الحساب بنجاح');
    context.go('/users');
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

  Widget _hero(BuildContext context, ({String role, String division})? required) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color(0xFF1D6054),
            Color(0xFF17574E),
            Color(0xFF0E3A34),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
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
            padding: const EdgeInsetsDirectional.fromSTEB(26, 22, 26, 22),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [Color(0xFFA98545), Color(0xFF7C5A1E)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .35)),
                    boxShadow: [
                      BoxShadow(
                        color: kGold.withValues(alpha: .4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(CupertinoIcons.person_add,
                      size: 30, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'أضف حسابات الفريق بأدوارهم وشعبهم ومسؤوليهم المباشرين',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      if (required != null) ...[
                        const SizedBox(height: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: .2),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: kGold.withValues(alpha: .45)),
                          ),
                          child: const Padding(
                            padding:
                                EdgeInsetsDirectional.fromSTEB(12, 7, 12, 7),
                            child: Text(
                              'أكمل إنشاء الحسابات الإدارية بالترتيب قبل إضافة الموظفين والمراقبين.',
                              style: TextStyle(
                                color: Color(0xFFE9CEA8),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final required = store.nextRequiredLeadershipAccount;
    return PageBody(children: [
      BackBreadcrumb(
        parent: 'المستخدمون',
        current: 'إنشاء حساب',
        fallbackLocation: '/users',
      ),
      _hero(context, required),
      AppCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          final accountSection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FormSectionHeader(
                icon: CupertinoIcons.person_crop_rectangle,
                title: 'بيانات الحساب',
                subtitle: 'الصورة والاسم واسم المستخدم وكلمة المرور المؤقتة',
                accent: kPrimary2,
              ),
              const SizedBox(height: 16),
              Center(
                child: _UserPhotoPicker(
                  store: store,
                  onChanged: (photo) =>
                      setState(() => selectedPhoto = photo),
                ),
              ),
              const SizedBox(height: 16),
              rowOf([
                Field('الاسم الكامل', ctl: name),
                Field('رقم الموبايل', ctl: phone, type: TextInputType.phone),
              ]),
              const SizedBox(height: 12),
              rowOf([Field('اسم المستخدم', ctl: un)]),
              const SizedBox(height: 12),
              rowOf([
                Field('كلمة مرور مؤقتة (6 أحرف على الأقل)', ctl: pw),
              ]),
              if (err != null) ...[
                const SizedBox(height: 14),
                _errorBox(err!),
              ],
            ],
          );
          final accessSection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FormSectionHeader(
                icon: CupertinoIcons.lock_shield_fill,
                title: 'الوصول والمسؤول',
                subtitle: 'الدور والشعبة والمسؤول المباشر',
                accent: kGold,
              ),
              const SizedBox(height: 16),
              rowOf([
                Drop(
                  'الدور',
                  role,
                  {
                    for (final r in _rolesFor(division)) r: kRoles[r]!,
                  },
                  (v) => setState(() {
                    role = v;
                    if (isDivisionHeadRole(v)) {
                      division = divisionForHeadRole(v)!;
                    } else if (!['monitor', 'user'].contains(v)) {
                      division = '';
                    } else if (division.isEmpty || (v == 'monitor' && division != 'field')) {
                      division = 'field';
                    }
                    _chooseDefaultManager();
                  }),
                ),
              ]),
              if (required == null && ['monitor', 'user'].contains(role)) ...[
                const SizedBox(height: 12),
                rowOf([
                  Drop(
                    'الشعبة',
                    division,
                    kDivisionNames,
                    (v) => setState(() {
                      division = v;
                      if (!_rolesFor(division).contains(role)) {
                        role = division.isEmpty
                            ? _rolesFor(division).first
                            : (_rolesFor(division).contains('user')
                                ? 'user'
                                : _rolesFor(division).first);
                      }
                      _chooseDefaultManager();
                    }),
                    enabled: ['monitor', 'user'].contains(role),
                  ),
                ]),
              ],
              if (_managerRoleFor(role, division) != null) ...[
                const SizedBox(height: 12),
                if (['monitor', 'user'].contains(role))
                  rowOf([
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'المسؤول المباشر',
                          enabled: false,
                        ),
                        child: Text(_directManagerValue()),
                      ),
                    ),
                  ])
                else
                  rowOf([
                    Drop(
                      'المسؤول المباشر',
                      managerId,
                      {
                        if (_managersFor(role, division).isEmpty)
                          '': 'لا يوجد مسؤول متاح',
                        for (final u in _managersFor(role, division))
                          u.id: '${u.name} (${kRoles[u.role]})',
                      },
                      (v) => setState(() => managerId = v),
                    ),
                  ]),
              ],
            ],
          );
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                accountSection,
                const SizedBox(height: 18),
                accessSection,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: accountSection),
              const SizedBox(width: 22),
              Expanded(flex: 5, child: accessSection),
            ],
          );
        }),
      ),
      AppCard(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(CupertinoIcons.chevron_right, size: 17),
              label: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => _create(context, store),
              icon: const Icon(CupertinoIcons.person_add, size: 18),
              label: const Text('إنشاء الحساب'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  String _directManagerValue() {
    final candidates = _managersFor(role, division);
    return candidates.length == 1
        ? _managerLabel(candidates.first)
        : 'لا يوجد رئيس شعبة مفعّل لهذه الشعبة';
  }

  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kRed.withValues(alpha: .25)),
        ),
        child: Row(children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill,
              color: kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: kRed,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ]),
      );
}

/// عنوان قسم داخل نموذج إنشاء الحساب.
class _FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  const _FormSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = kPrimary2,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                accent.withValues(alpha: .28),
                accent.withValues(alpha: .10),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.p.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]);
}

/// زر إجراء دائري بحدود وأيقونة متناسبة — فاخر وواضح.
class _CircleIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double size;
  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size * .48),
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: .12),
        shape: const CircleBorder(),
        fixedSize: Size(size, size),
        foregroundColor: color,
        elevation: 0,
        highlightColor: color.withValues(alpha: .18),
        hoverColor: color.withValues(alpha: .2),
        side: BorderSide(color: color.withValues(alpha: .35), width: 1),
      ),
    );
  }
}

/// أيقونة فخمة للدور — دائرة بتدرج لوني وأيقونة متناسقة.
class _RoleIcon extends StatelessWidget {
  final String role;
  const _RoleIcon({required this.role});

  @override
  Widget build(BuildContext context) {
    final roles = kRoles.keys.toList();
    final index = roles.indexOf(role);
    final accentIndex = index < 0 ? 0 : index;
    final color = _rolePalette[accentIndex % _rolePalette.length];
    final icon = _roleIcons[role] ?? CupertinoIcons.person_fill;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            color.withValues(alpha: .36),
            color.withValues(alpha: .12),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: .45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .25),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// قائمة منسدلة مدعومة بالتسمية فوقها — مثل لوحة المكلفين.
class _LabeledDrop extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final Map<String, String> options;
  final void Function(String) onChanged;
  const _LabeledDrop({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue =
        options.containsKey(value) ? value : options.keys.first;
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
            child: Text(label,
                style: TextStyle(
                  color: context.p.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.1,
                )),
          ),
          Container(
            height: 38,
            padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
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
                icon: Icon(CupertinoIcons.chevron_down,
                    size: 15, color: context.p.muted),
                items: options.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Icon(icon,
                                  size: 14,
                                  color: context.p.muted),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(entry.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                              ),
                            ],
                          ),
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
}

