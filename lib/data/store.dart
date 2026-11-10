import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/util.dart';
import 'attachments.dart';
import 'models.dart';
import 'sales_api.dart';

class DeclineInfo {
  final Taxpayer t;
  final double vsPrev, vsYear, vs3;
  final String severity;
  DeclineInfo(this.t, this.vsPrev, this.vsYear, this.vs3, this.severity);
  double get worst => [vsPrev, vsYear, vs3].reduce(min);
}

class IntegrityCheck {
  final String title, detail;
  final bool ok;
  IntegrityCheck(this.title, this.ok, this.detail);
}

class VerifyResult {
  final bool ok;
  final String msg;
  final Report? report;
  VerifyResult(this.ok, this.msg, [this.report]);
}

/// مخزن البيانات المحلي. تُسلسل الكتابات لضمان حفظ أحدث نسخة بالترتيب.
class AppStore extends ChangeNotifier {
  static const _key = 'lcs_db_v1';
  static const _sessionKey = 'lcs_session_user_v1';
  // مفتاح توقيع تجريبي. في الإنتاج يبقى على الخادم فقط ولا يوضع في التطبيق.
  static const _secret = 'LTX-DEMO-SECRET-MOVE-TO-SERVER';

  final SalesApi salesApi = MockSalesApi();

  /// مرفقات المحاضر. الملفات منفصلة عن ملف البيانات.
  final AttachmentStore attachmentStore = AttachmentStore();
  SharedPreferences? _p;
  Future<void> _pendingWrites = Future<void>.value();
  String? persistenceError;

  List<AppUser> users = [];
  List<Taxpayer> taxpayers = [];
  List<Report> reports = [];
  List<FollowUp> followups = [];
  List<MonthlyStatement> statements = [];
  List<AuditEntry> audit = [];
  List<SerialBook> books = [];
  List<Map<String, dynamic>> savedFilters = [];
  List<Map<String, dynamic>> alertLog = [];
  Map<String, List<String>> perms = defaultPerms();

  /// صلاحيات مخصصة لكل حساب على حدة (تُضاف/تُستثنى فوق صلاحيات دوره).
  Map<String, List<String>> userPerms = {};
  Map<String, List<String>> routing = defaultRouting();
  Map<String, dynamic> settings = {};
  Map<String, SalesSeries> sales = {};
  AppUser? me;

  bool get loggedIn => me != null;

  Map<String, dynamic> _defaultSettings() => {
        'serialMode': 'manual',
        'lateFeePct': 5,
        'objectionDays': 7,
        'declineCritical': 40,
        'declineHigh': 25,
        'declineMedium': 15,
        'statementsDeadlineDay': 10,
        'archiveLocationRequired': false,
        'darkMode': false,
        'violationTypes': [
          {'name': 'عدم إصدار فواتير', 'article': '', 'fine': 0},
          {'name': 'عدم تقديم بيان المبيعات', 'article': '', 'fine': 0},
          {'name': 'عدم عرض بيان مزاولة المهنة', 'article': '', 'fine': 0},
        ],
      };

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    await attachmentStore.init();
    final raw = _p!.getString(_key);
    if (raw == null) {
      _seed();
    } else {
      try {
        final migrated = _load(jsonDecode(raw) as Map<String, dynamic>);
        if (migrated || _normalizeUserHierarchy()) _save();
        if (_isLegacyEmptyDemo()) {
          _seedDemoRecords();
          _log('تحديث بيانات العرض', 'النظام', 'إضافة سجلات تجريبية مترابطة');
          _save();
        }
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError(
            'تعذر قراءة البيانات المحلية. لم تُستبدل ببيانات افتراضية: $error',
          ),
          stackTrace,
        );
      }
    }
    await _restoreSession();
    await _pendingWrites;
    await loadSales();
  }

  Future<void> _restoreSession() async {
    final userId = _p?.getString(_sessionKey);
    if (userId == null) return;
    for (final user in users) {
      if (user.id == userId && user.active) {
        me = user;
        return;
      }
    }
    _queueRemove(_sessionKey);
  }

  // ---------- حفظ وتحميل ----------
  Map<String, dynamic> _toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'taxpayers': taxpayers.map((e) => e.toJson()).toList(),
        'reports': reports.map((e) => e.toJson()).toList(),
        'followups': followups.map((e) => e.toJson()).toList(),
        'statements': statements.map((e) => e.toJson()).toList(),
        'audit': audit.map((e) => e.toJson()).toList(),
        'books': books.map((e) => e.toJson()).toList(),
        'savedFilters': savedFilters,
        'alertLog': alertLog,
        'perms': perms,
        'userPerms': userPerms,
        'routing': routing,
        'settings': settings,
      };

  bool _load(Map<String, dynamic> j) {
    var migrated = false;
    List<T> l<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    users = l('users', AppUser.fromJson);
    for (final user in users.where((user) => user.role == 'divisionHead')) {
      final role = headRoleForDivision(user.division);
      if (role != null) {
        user.role = role;
        migrated = true;
      }
    }
    taxpayers = l('taxpayers', Taxpayer.fromJson);
    reports = l('reports', Report.fromJson);
    followups = l('followups', FollowUp.fromJson);
    statements = l('statements', MonthlyStatement.fromJson);
    audit = l('audit', AuditEntry.fromJson);
    books = l('books', SerialBook.fromJson);
    savedFilters = ((j['savedFilters'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    alertLog = ((j['alertLog'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    perms = ((j['perms'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, List<String>.from(v as List)));
    if (perms.isEmpty) perms = defaultPerms();
    userPerms = ((j['userPerms'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, List<String>.from(v as List)));
    final defaultRolePerms = defaultPerms();
    final oldDivisionHeadPerms = perms.remove('divisionHead');
    for (final role in ['financeDirector', 'infoSectionHead', 'monitor']) {
      perms.putIfAbsent(role, () => defaultRolePerms[role]!);
    }
    for (final role in kDivisionHeadRoles.values) {
      if (!perms.containsKey(role)) {
        perms[role] = List<String>.from(
          oldDivisionHeadPerms ?? defaultRolePerms[role]!,
        );
        if (oldDivisionHeadPerms != null) migrated = true;
      }
    }
    // تُضاف صلاحية «عرض صلاحيات المستخدم» للنسخ المحفوظة قبل إضافتها.
    for (final role in perms.keys.toList()) {
      if (role == 'sysadmin') {
        perms[role] = kPerms.keys.toList();
        continue;
      }
      if (!perms[role]!.contains('permissions.view')) {
        perms[role]!.add('permissions.view');
        migrated = true;
      }
    }
    // مدير النظام يملك كل الصلاحيات دائماً، حتى في النسخ المحفوظة قبل إضافة صلاحيات جديدة.
    perms['sysadmin'] = kPerms.keys.toList();
    routing = ((j['routing'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, List<String>.from(v as List)));
    for (final routes in routing.values) {
      if (routes.remove('role:divisionHead')) {
        routes.addAll(kDivisionHeadRoles.values.map((role) => 'role:$role'));
        migrated = true;
      }
    }
    if (routing.isEmpty) routing = defaultRouting();
    settings = Map<String, dynamic>.from((j['settings'] as Map?) ?? {});
    _defaultSettings().forEach((k, v) {
      settings.putIfAbsent(k, () => v);
    });
    return migrated;
  }

  bool _normalizeUserHierarchy() {
    var changed = false;
    for (final user
        in users.where((user) => user.active && user.managerId.isEmpty)) {
      final managerRole = switch (user.role) {
        'sectionHead' || 'infoSectionHead' => 'financeDirector',
        'deptHead' => 'sectionHead',
        'fieldHead' || 'officeHead' || 'archiveHead' => 'deptHead',
        'monitor' || 'user' => headRoleForDivision(user.division),
        _ => null,
      };
      if (managerRole == null) continue;
      final managers = users.where((candidate) =>
          candidate.active &&
          candidate.role == managerRole &&
          (!isDivisionHeadRole(managerRole) ||
              candidate.division == user.division));
      if (managers.length == 1) {
        user.managerId = managers.first.id;
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _queueWrite(String key, String value) =>
      _queuePreference((prefs) => prefs.setString(key, value));

  Future<void> _queueRemove(String key) =>
      _queuePreference((prefs) => prefs.remove(key));

  Future<void> _queuePreference(
      Future<bool> Function(SharedPreferences) action) {
    final write = _pendingWrites.then((_) async {
      final prefs = _p;
      if (prefs == null) throw StateError('مخزن البيانات المحلي غير جاهز');
      if (!await action(prefs)) {
        throw StateError('رفض التخزين المحلي كتابة البيانات');
      }
      persistenceError = null;
    });
    _pendingWrites = write.catchError((Object error, StackTrace stackTrace) {
      persistenceError = 'تعذر حفظ البيانات محليًا: $error';
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'التخزين المحلي',
        context: ErrorDescription('أثناء حفظ بيانات التطبيق'),
      ));
      notifyListeners();
    });
    return _pendingWrites;
  }

  Future<void> flushPersistence() async {
    await _pendingWrites;
    final error = persistenceError;
    if (error != null) throw StateError(error);
  }

  Future<void> retryPersistence() async {
    await _queueWrite(_key, jsonEncode(_toJson()));
    await flushPersistence();
  }

  void _save() {
    _queueWrite(_key, jsonEncode(_toJson()));
    notifyListeners();
  }

  void _seed() {
    AppUser mk(String id, String name, String un, String role,
            {String div = '', String mgr = ''}) =>
        AppUser(
            id: id,
            name: name,
            username: un,
            passHash: AppUser.hashPassword(un, '123456'),
            role: role,
            division: div,
            managerId: mgr,
            createdBy: 'النظام');
    users = [
      mk('u1', 'مدير النظام', 'admin', 'sysadmin'),
      mk('u10', 'مدير المالية', 'finance', 'financeDirector'),
      mk('u2', 'رئيس قسم الواردات', 'head', 'sectionHead', mgr: 'u10'),
      mk('u11', 'رئيس قسم المعلوماتية', 'info_head', 'infoSectionHead',
          mgr: 'u10'),
      mk('u3', 'رئيس دائرة الإنفاق الإستهلاكي', 'dept', 'deptHead', mgr: 'u2'),
      mk('u4', 'رئيس الشعبة الميدانية', 'field_head', 'fieldHead',
          div: 'field', mgr: 'u3'),
      mk('u5', 'رئيس الشعبة المكتبية', 'office_head', 'officeHead',
          div: 'office', mgr: 'u3'),
      mk('u6', 'رئيس شعبة الأرشيف', 'archive_head', 'archiveHead',
          div: 'archive', mgr: 'u3'),
      mk('u7', 'مستخدم ميداني', 'field1', 'user', div: 'field', mgr: 'u4'),
      mk('u8', 'مستخدم مكتبي', 'office1', 'user', div: 'office', mgr: 'u5'),
      mk('u9', 'مستخدم أرشيف', 'archive1', 'user', div: 'archive', mgr: 'u6'),
    ];
    _seedDemoRecords();
    audit = [];
    books = [SerialBook(id: 'b1', from: 1, to: 50, assignee: 'مستخدم ميداني')];
    savedFilters = [];
    alertLog = [];
    perms = defaultPerms();
    routing = defaultRouting();
    settings = _defaultSettings();
    me = null;
    _log('تهيئة', 'النظام', 'إنشاء بيانات تجريبية');
    _save();
  }

  bool _isLegacyEmptyDemo() {
    if (taxpayers.length != 10 ||
        reports.isNotEmpty ||
        followups.isNotEmpty ||
        statements.isNotEmpty) {
      return false;
    }
    for (var index = 0; index < taxpayers.length; index++) {
      final i = index + 1;
      final taxpayer = taxpayers[index];
      if (taxpayer.id != 't$i' ||
          taxpayer.name != 'منشأة تجريبية $i' ||
          taxpayer.owner != 'مالك تجريبي $i' ||
          taxpayer.category != kCategories[i % 3] ||
          taxpayer.taxNo != '${1000000 + i}' ||
          taxpayer.address != 'اللاذقية - [عنوان $i]' ||
          taxpayer.profession.isNotEmpty ||
          taxpayer.status != (i == 7 ? 'متوقف مؤقتاً' : 'فعال') ||
          taxpayer.history.isNotEmpty ||
          taxpayer.attachments.isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  void _seedDemoRecords() {
    taxpayers = [
      Taxpayer(
        id: 't1',
        name: 'مخبز السنابل',
        owner: 'مالك افتراضي 1',
        category: 'أخرى',
        taxNo: '90000001',
        address: 'اللاذقية - شارع الجمهورية',
        profession: 'مخبز',
      ),
      Taxpayer(
        id: 't2',
        name: 'مطعم المرفأ',
        owner: 'مالك افتراضي 2',
        category: 'مطاعم',
        taxNo: '90000002',
        address: 'اللاذقية - الكورنيش الجنوبي',
        profession: 'مطعم',
      ),
      Taxpayer(
        id: 't3',
        name: 'مطعم الياسمين',
        owner: 'مالك افتراضي 3',
        category: 'مطاعم',
        taxNo: '90000003',
        address: 'اللاذقية - شارع القوتلي',
        profession: 'مطعم ومقهى',
      ),
      Taxpayer(
        id: 't4',
        name: 'مجوهرات اللؤلؤة',
        owner: 'مالك افتراضي 4',
        category: 'صاغة',
        taxNo: '90000004',
        address: 'اللاذقية - سوق الصاغة',
        profession: 'صياغة وبيع المجوهرات',
      ),
      Taxpayer(
        id: 't5',
        name: 'مجوهرات الساحل',
        owner: 'مالك افتراضي 5',
        category: 'صاغة',
        taxNo: '90000005',
        address: 'اللاذقية - شارع 8 آذار',
        profession: 'صياغة وبيع المجوهرات',
      ),
      Taxpayer(
        id: 't6',
        name: 'الشام لمستحضرات العناية',
        owner: 'مالك افتراضي 6',
        category: 'شركات شامبو',
        taxNo: '90000006',
        address: 'اللاذقية - المنطقة الصناعية',
        profession: 'تجارة مستحضرات العناية',
      ),
      Taxpayer(
        id: 't7',
        name: 'مطعم الموج',
        owner: 'مالك افتراضي 7',
        category: 'مطاعم',
        taxNo: '90000007',
        address: 'اللاذقية - الرمل الجنوبي',
        profession: 'مطعم',
        status: 'متوقف مؤقتاً',
      ),
      Taxpayer(
        id: 't8',
        name: 'نسيم الساحل للتجارة',
        owner: 'مالك افتراضي 8',
        category: 'شركات شامبو',
        taxNo: '90000008',
        address: 'اللاذقية - شارع بغداد',
        profession: 'تجارة عامة',
      ),
      Taxpayer(
        id: 't9',
        name: 'حلويات الميناء',
        owner: 'مالك افتراضي 9',
        category: 'أخرى',
        taxNo: '90000009',
        address: 'اللاذقية - حي الزراعة',
        profession: 'حلويات شرقية وغربية',
      ),
      Taxpayer(
        id: 't10',
        name: 'مطعم الساحة',
        owner: 'مالك افتراضي 10',
        category: 'مطاعم',
        taxNo: '90000010',
        address: 'اللاذقية - ساحة اليمن',
        profession: 'مطعم',
      ),
    ];
    final now = DateTime.now();
    DateTime daysAgo(int days) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    reports = [
      Report(
        id: 'r1',
        serial: '001',
        taxpayerId: 't2',
        date: daysAgo(24),
        status: 'معتمد',
        createdBy: 'مستخدم مكتبي',
        division: 'office',
        items: [
          Violation(
              type: 'عدم إصدار فواتير', article: 'مثال تجريبي', fine: 250000),
        ],
        servedName: 'ممثل المنشأة',
        servedCapacity: 'مفوّض',
        servedDate: fmtDate(daysAgo(22)),
        referralDate: fmtDate(daysAgo(18)),
        committee: 'القضائية',
        referralValue: 250000,
      ),
      Report(
        id: 'r2',
        serial: '002',
        taxpayerId: 't4',
        date: daysAgo(15),
        status: 'بانتظار رئيس الشعبة',
        createdBy: 'مستخدم ميداني',
        division: 'field',
        items: [
          Violation(
              type: 'عدم عرض بيان مزاولة المهنة',
              article: 'مثال تجريبي',
              fine: 150000),
        ],
        inspectors: 'مفتش ميداني',
      ),
      Report(
        id: 'r3',
        serial: '003',
        taxpayerId: 't1',
        date: daysAgo(8),
        status: 'مسودة',
        createdBy: 'مستخدم مكتبي',
        division: 'office',
        items: [
          Violation(
              type: 'عدم تقديم بيان المبيعات',
              article: 'مثال تجريبي',
              fine: 100000),
        ],
      ),
      Report(
        id: 'r4',
        serial: '004',
        taxpayerId: 't6',
        date: daysAgo(11),
        status: 'بانتظار رئيس الدائرة',
        createdBy: 'رئيس الشعبة المكتبية',
        division: 'office',
        items: [
          Violation(
              type: 'عدم تقديم بيان المبيعات',
              article: 'مثال تجريبي',
              fine: 300000),
        ],
        referralDate: fmtDate(daysAgo(5)),
        committee: 'تقدير البيانات',
        referralValue: 300000,
      ),
      Report(
        id: 'r5',
        serial: '005',
        taxpayerId: 't9',
        date: daysAgo(35),
        status: 'ملغى',
        createdBy: 'مستخدم مكتبي',
        division: 'office',
        items: [
          Violation(
              type: 'عدم إصدار فواتير', article: 'مثال تجريبي', fine: 200000),
        ],
        cancelReason: 'سجل توضيحي لمحضر ملغى',
      ),
    ];
    followups = [
      FollowUp('r1', {
        'judicialNo': 'ق/101',
        'judicialDate': fmtDate(daysAgo(10)),
        'judicialContent': 'تسديد الغرامة',
        'feesRealized': '250000',
        'receiptNo': 'إيصال تجريبي 501',
      }),
      FollowUp('r4', {
        'estimationNo': 'ت/204',
        'estimationDate': fmtDate(daysAgo(2)),
        'estimationContent': 'قيد الدراسة',
        'notes': 'بيانات توضيحية تجريبية',
      }),
    ];
    statements = [
      for (final t in taxpayers.where((t) => t.status == 'فعال'))
        for (var monthsAgo = 0; monthsAgo < 3; monthsAgo++)
          MonthlyStatement(
            t.id,
            ymOf(DateTime(now.year, now.month - monthsAgo, 1)),
            monthsAgo > 0 || (t.id != 't9' && t.id != 't10'),
            monthsAgo > 0 || (t.id != 't9' && t.id != 't10')
                ? fmtDate(DateTime(now.year, now.month - monthsAgo, 1))
                : '',
          ),
    ];
  }

  // ---------- سجل العمليات (سلسلة بصمات) ----------
  void _log(String action, String entity, String detail) {
    final prev = audit.isEmpty ? 'GENESIS' : audit.last.hash;
    final ts = DateTime.now().toIso8601String();
    final u = me?.name ?? 'النظام';
    audit.add(AuditEntry(
        id: newId(),
        ts: ts,
        user: u,
        action: action,
        entity: entity,
        detail: detail,
        prev: prev,
        hash: AuditEntry.compute(prev, ts, u, action, entity, detail)));
  }

  // ---------- الدخول والصلاحيات ----------
  bool login(String u, String p) {
    final un = u.trim();
    final f = users.where((x) =>
        x.username == un &&
        x.active &&
        x.passHash == AppUser.hashPassword(un, p));
    if (f.isEmpty) {
      _log('محاولة دخول فاشلة', un, '');
      _save();
      return false;
    }
    me = f.first;
    _queueWrite(_sessionKey, me!.id);
    _log('دخول', me!.username, '');
    _save();
    return true;
  }

  void logout() {
    _log('خروج', me?.username ?? '', '');
    me = null;
    _queueRemove(_sessionKey);
    _save();
  }

  bool can(String perm) {
    if (me == null) return false;
    // مدير النظام يملك كل الصلاحيات (يمنع اختفاء أقسام من القائمة بحساب admin).
    if (me!.role == 'sysadmin') return true;
    final list = userPerms[me!.id] ?? perms[me!.role] ?? [];
    return perm.split('|').any(list.contains);
  }

  /// الصلاحيات الفعلية لحساب (مدير النظام → كاملة، وإلا المخصص للحساب ثم دور حساب).
  List<String> effectivePermsFor(AppUser user) {
    if (user.role == 'sysadmin') return kPerms.keys.toList();
    final override = userPerms[user.id];
    return List<String>.from(override ?? perms[user.role] ?? const []);
  }

  /// هل لدى هذا الحساب استثناءات صلاحيات مخصصة؟
  bool hasPermOverride(String userId) => userPerms.containsKey(userId);

  void addUserPerm(String userId, String perm) {
    final user = _findUserById(userId);
    if (user == null || user.role == 'sysadmin') return;
    final list = List<String>.from(effectivePermsFor(user));
    if (list.contains(perm)) return;
    list.add(perm);
    userPerms[userId] = list;
    _log('إضافة صلاحية للحساب', user.name, kPerms[perm] ?? perm);
    _save();
  }

  void removeUserPerm(String userId, String perm) {
    final user = _findUserById(userId);
    if (user == null || user.role == 'sysadmin') return;
    final list = List<String>.from(effectivePermsFor(user));
    if (!list.remove(perm)) return;
    userPerms[userId] = list;
    _log('إزالة صلاحية من الحساب', user.name, kPerms[perm] ?? perm);
    _save();
  }

  void resetUserPerms(String userId) {
    final user = _findUserById(userId);
    if (user == null) return;
    userPerms.remove(userId);
    _log('مسح استثناءات الصلاحيات', user.name, '');
    _save();
  }

  AppUser? _findUserById(String id) {
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  bool get inArchiveDivision => me?.division == 'archive';
  bool get inFieldDivision => me?.division == 'field';

  /// موظف الأرشيف يستطيع التسجيل بحكم شعبة الأرشيف حتى لو كان دوره «مستخدم».
  bool canArchiveEdit() => can('archive.edit') || inArchiveDivision;
  bool canArchiveAttach() => can('archive.attachments') || inArchiveDivision;

  /// العمل الميداني متاح لشعبة الميدان، وللمشرفين، ولمن يملك الصلاحية صراحة.
  bool canField() =>
      can('field.view') &&
      (inFieldDivision ||
          me?.role == 'sysadmin' ||
          me?.role == 'deptHead' ||
          me?.role == 'sectionHead');

  /// إدارة صور أضبارة المكلف: لمن يعدّل المكلفين أو لشعبة الأرشيف.
  bool canTaxpayerFiles() => can('taxpayers.edit') || inArchiveDivision;

  int get attachmentCount =>
      reports.fold<int>(0, (a, r) => a + r.attachments.length) +
      taxpayers.fold<int>(0, (a, t) => a + t.attachments.length);

  // ---------- المكلفون ----------
  Taxpayer? tp(String id) {
    for (final t in taxpayers) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Taxpayer> searchTaxpayers(
      {String q = '',
      String mode = 'all',
      String cat = '',
      String status = ''}) {
    final nq = normAr(q);
    return taxpayers.where((t) {
      if (cat.isNotEmpty && t.category != cat) return false;
      if (status.isNotEmpty && t.status != status) return false;
      if (nq.isEmpty) return true;
      final byName = normAr('${t.name} ${t.owner}').contains(nq);
      final byNo = t.taxNo.contains(nq);
      return mode == 'name'
          ? byName
          : mode == 'tax'
              ? byNo
              : (byName || byNo);
    }).toList();
  }

  String? addTaxpayer(Taxpayer t) {
    if (taxpayers.any((x) => x.taxNo == t.taxNo)) {
      return 'الرقم الضريبي مسجّل من قبل';
    }
    taxpayers.add(t);
    _log('إضافة مكلف', t.name, t.taxNo);
    _save();
    loadSales();
    return null;
  }

  void updateTaxpayer(Taxpayer t, {String detail = ''}) {
    _log('تعديل مكلف', t.name, detail);
    _save();
  }

  // ---------- أضبارة المكلف ----------
  Future<Attachment?> addTaxpayerAttachment(
    Taxpayer t, {
    required String name,
    required String mime,
    required Uint8List bytes,
    String kind = 'photo',
    String note = '',
  }) async {
    final a = await createAttachment(
        ownerId: t.id,
        name: name,
        mime: mime,
        bytes: bytes,
        kind: kind,
        note: note);
    if (a == null) return null;
    t.attachments.add(a);
    _log('إضافة صورة للأضبارة', t.name, a.name);
    _save();
    return a;
  }

  Future<void> removeTaxpayerAttachment(Taxpayer t, Attachment a) async {
    t.attachments.removeWhere((x) => x.id == a.id);
    if (!attachmentReferenced(a.id)) await attachmentStore.delete(a.id);
    _log('حذف صورة من الأضبارة', t.name, a.name);
    _save();
  }

  void changeStatus(List<String> ids, String status, String reason) {
    for (final id in ids) {
      final t = tp(id);
      if (t == null || t.status == status) continue;
      t.history.add({
        'date': fmtDT(DateTime.now()),
        'from': t.status,
        'to': status,
        'reason': reason,
        'by': me?.name ?? ''
      });
      _log('تغيير حالة مكلف', t.name, '${t.status} ← $status ($reason)');
      t.status = status;
    }
    _save();
  }

  /// استيراد من نص ملصوق من Excel: اسم المنشأة، المالك، الفئة، الرقم الضريبي، العنوان.
  List<int> importTaxpayers(String text) {
    var added = 0, skipped = 0;
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final c = (line.contains('\t') ? line.split('\t') : line.split(','))
          .map((e) => e.trim())
          .toList();
      if (c.length < 4 || c[3].contains('الرقم الضريبي')) {
        skipped++;
        continue;
      }
      if (taxpayers.any((x) => x.taxNo == c[3])) {
        skipped++;
        continue;
      }
      taxpayers.add(Taxpayer(
          id: newId(),
          name: c[0],
          owner: c[1],
          category: kCategories.contains(c[2]) ? c[2] : 'أخرى',
          taxNo: c[3],
          address: c.length > 4 ? c[4] : ''));
      added++;
    }
    _log('استيراد مكلفين', 'Excel', 'أُضيف $added وتُجوهل $skipped');
    _save();
    loadSales();
    return [added, skipped];
  }

  String exportTaxpayersTsv(List<Taxpayer> l) => [
        'اسم المنشأة\tالمالك\tالفئة\tالرقم الضريبي\tالعنوان\tالحالة',
        ...l.map((t) =>
            '${t.name}\t${t.owner}\t${t.category}\t${t.taxNo}\t${t.address}\t${t.status}'),
      ].join('\n');

  void saveFilter(Map<String, dynamic> f) {
    savedFilters.add(f);
    _save();
  }

  void removeFilter(int i) {
    savedFilters.removeAt(i);
    _save();
  }

  // ---------- المحاضر ----------
  Report? report(String id) {
    for (final r in reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  String nextSerial() {
    var mx = 0;
    for (final r in reports) {
      final n = int.tryParse(r.serial);
      if (n != null && n > mx) mx = n;
    }
    return '${mx + 1}';
  }

  String? validateSerial(String s, {String? exceptId}) {
    final v = s.trim();
    if (v.isEmpty) return 'أدخل رقم المحضر';
    if (reports.any((r) => r.serial == v && r.id != exceptId)) {
      return 'هذا الرقم مستخدم من قبل';
    }
    if (books.isNotEmpty && settings['serialMode'] == 'manual') {
      final n = int.tryParse(v);
      if (n == null || !books.any((b) => !b.closed && b.contains(n))) {
        return 'الرقم خارج الدفاتر المسلَّمة';
      }
    }
    return null;
  }

  void saveReport(Report r) {
    final i = reports.indexWhere((x) => x.id == r.id);
    if (i < 0) {
      reports.insert(0, r);
      _log('إنشاء محضر', r.serial, 'مسودة');
    } else {
      reports[i] = r;
      _log('تعديل محضر', r.serial, '');
    }
    _save();
  }

  void _setStatus(Report r, String st, String act, [String detail = '']) {
    r.status = st;
    _log(act, r.serial, detail);
    _save();
  }

  void submit(Report r) =>
      _setStatus(r, 'بانتظار رئيس الشعبة', 'إرسال للاعتماد');
  void approveDivision(Report r) =>
      _setStatus(r, 'بانتظار رئيس الدائرة', 'اعتماد رئيس الشعبة');
  void endorse(Report r) => _setStatus(r, 'معتمد', 'تصديق رئيس الدائرة');
  void sendBack(Report r, String note) {
    r.returnNote = note;
    _setStatus(r, 'مسودة', 'إرجاع للتعديل', note);
  }

  /// الطباعة تقفل المحضر وتثبّت بصمته. لا يُعدَّل بعدها؛ التصحيح بالإلغاء والاستبدال.
  void lock(Report r) {
    r.fingerprint = sha256Hex(r.canonical());
    r.printedAt = DateTime.now();
    _setStatus(
        r, 'مقفل', 'طباعة وقفل', 'بصمة ${r.fingerprint!.substring(0, 8)}');
  }

  void cancel(Report r, String reason) {
    r.cancelReason = reason;
    _setStatus(r, 'ملغى', 'إلغاء محضر', reason);
  }

  void saveRegisterFields(Report r) {
    _log('تعديل سجل المخالفات', r.serial, '');
    _save();
  }

  // ---------- المرفقات ----------
  /// رسالة خطأ مناسبة إن كان الملف أكبر من الحد أو فارغاً، وإلا null.
  String? attachmentError(Uint8List bytes) {
    if (bytes.isEmpty) return 'الملف فارغ';
    if (bytes.length > AttachmentStore.maxBytes) {
      return 'حجم الملف ${(bytes.length / 1000000).toStringAsFixed(1)} ميغابايت ويتجاوز الحد المسموح (1.5). اضغط الصورة أو ارفع نسخة أصغر.';
    }
    return null;
  }

  Future<Attachment?> createAttachment({
    required String ownerId,
    required String name,
    required String mime,
    required Uint8List bytes,
    String kind = 'document',
    String note = '',
  }) async {
    if (attachmentError(bytes) != null) return null;
    final a = Attachment(
      id: newId(),
      ownerId: ownerId,
      name: name,
      mime: mime,
      kind: kind,
      size: bytes.length,
      note: note,
      uploadedAt: DateTime.now().toIso8601String(),
      uploadedBy: me?.name ?? '',
    );
    await attachmentStore.put(a.id, bytes);
    return a;
  }

  Future<Uint8List?> attachmentBytes(String id) => attachmentStore.get(id);

  Future<String?> setUserPhoto(
    String userId, {
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    if (!mime.startsWith('image/')) return 'اختر ملف صورة صالحًا';
    final sizeError = attachmentError(bytes);
    if (sizeError != null) return sizeError;
    final matches = users.where((user) => user.id == userId);
    if (matches.isEmpty) return 'الحساب غير موجود';
    final user = matches.first;
    if (user.status == 'closed') return 'لا يمكن تعديل صورة حساب مغلق نهائيًا';

    final photoId = newId();
    await attachmentStore.put(photoId, bytes);
    final previousPhotoId = user.photoId;
    user.photoId = photoId;
    _log('تغيير صورة المستخدم', user.username, name);
    _save();
    if (previousPhotoId.isNotEmpty) {
      await attachmentStore.delete(previousPhotoId);
    }
    return null;
  }

  Future<Attachment?> addReportAttachment(
    Report r, {
    required String name,
    required String mime,
    required Uint8List bytes,
    String kind = 'document',
    String note = '',
  }) async {
    final a = await createAttachment(
        ownerId: r.id,
        name: name,
        mime: mime,
        bytes: bytes,
        kind: kind,
        note: note);
    if (a == null) return null;
    r.attachments.add(a);
    _log('إضافة مرفق', r.serial.isEmpty ? r.id : r.serial, a.name);
    _save();
    return a;
  }

  Future<void> removeReportAttachment(Report r, Attachment a) async {
    r.attachments.removeWhere((x) => x.id == a.id);
    // قد يشترك ملف المرفق بين محضر واحد فقط؛ يُحذف عند عدم استخدامه.
    if (!attachmentReferenced(a.id)) await attachmentStore.delete(a.id);
    _log('حذف مرفق', r.serial.isEmpty ? r.id : r.serial, a.name);
    _save();
  }

  /// هل ما زال المرفق مستخدماً في أي محضر أو مكلف؟
  bool attachmentReferenced(String id) {
    for (final r in reports) {
      if (r.attachments.any((a) => a.id == id)) return true;
    }
    for (final t in taxpayers) {
      if (t.attachments.any((a) => a.id == id)) return true;
    }
    return false;
  }

  // ---------- الأرشيف ----------
  /// المحاضر التي تدخل دائرة الأرشيف: المقفلة، والمعتمدة بانتظار الطباعة،
  /// والملغاة (تبقى للتوثيق ولا تُحذف).
  List<Report> archiveReports() => reports
      .where((r) =>
          r.status == 'مقفل' || r.status == 'معتمد' || r.status == 'ملغى')
      .toList();

  List<Report> archivedReports() =>
      archiveReports().where((r) => r.archived).toList();

  void setArchiveInfo(Report r,
      {required String ref, required String box, required String notes}) {
    r.archiveRef = ref.trim();
    r.archiveBox = box.trim();
    r.archiveNotes = notes.trim();
    if (r.hasArchiveLocation && !r.archived) {
      r.archivedAt = DateTime.now().toIso8601String();
      r.archivedBy = me?.name ?? '';
    }
    _log('تسجيل موقع أرشيف', r.serial.isEmpty ? r.id : r.serial,
        'مرجع ${r.archiveRef.isEmpty ? "—" : r.archiveRef} · صندوق ${r.archiveBox.isEmpty ? "—" : r.archiveBox}');
    _save();
  }

  void clearArchiveInfo(Report r) {
    r.archiveRef = '';
    r.archiveBox = '';
    r.archiveNotes = '';
    r.archivedAt = '';
    r.archivedBy = '';
    _log('إلغاء موقع أرشيف', r.serial.isEmpty ? r.id : r.serial, '');
    _save();
  }

  // ---------- QR والتحقق ----------
  String qrPayload(Report r) {
    final fp = (r.fingerprint ?? sha256Hex(r.canonical())).substring(0, 16);
    final sig = hmacHex(_secret, '${r.serial}|$fp').substring(0, 16);
    return 'LTX1|${r.serial}|$fp|$sig';
  }

  VerifyResult verifyPayload(String s) {
    final p = s.trim().split('|');
    if (p.length != 4 || p[0] != 'LTX1') {
      return VerifyResult(false, 'صيغة الرمز غير صحيحة');
    }
    final sig = hmacHex(_secret, '${p[1]}|${p[2]}').substring(0, 16);
    if (sig != p[3]) {
      return VerifyResult(false, 'التوقيع غير صحيح: الرمز مزوّر أو معدّل');
    }
    final r = reports.where((x) => x.serial == p[1]).toList();
    if (r.isEmpty) {
      return VerifyResult(
          false, 'التوقيع سليم لكن المحضر غير موجود في هذا السجل');
    }
    final rep = r.first;
    if (sha256Hex(rep.canonical()).substring(0, 16) != p[2]) {
      return VerifyResult(false, 'محتوى المحضر تغيّر بعد طباعته', rep);
    }
    if (rep.status == 'ملغى') {
      return VerifyResult(false, 'المحضر ملغى ولم يعد معتمداً', rep);
    }
    return VerifyResult(true, 'المحضر صحيح ومطابق للسجلات', rep);
  }

  // ---------- السجلات ----------
  FollowUp followUpFor(String reportId) {
    for (final f in followups) {
      if (f.reportId == reportId) return f;
    }
    final f = FollowUp(reportId);
    followups.add(f);
    return f;
  }

  void saveFollowUp(FollowUp f) {
    _log('تعديل سجل المتابعة', report(f.reportId)?.serial ?? '', '');
    _save();
  }

  // ---------- البيانات الشهرية ----------
  bool submitted(String taxId, String ym) {
    for (final s in statements) {
      if (s.taxId == taxId && s.ym == ym) return s.submitted;
    }
    return false;
  }

  void setSubmitted(String taxId, String ym, bool v) {
    final i = statements.indexWhere((s) => s.taxId == taxId && s.ym == ym);
    final d = fmtDate(DateTime.now());
    if (i < 0) {
      statements.add(MonthlyStatement(taxId, ym, v, v ? d : ''));
    } else {
      statements[i].submitted = v;
      statements[i].date = v ? d : '';
    }
    _log(
        'بيان شهري', tp(taxId)?.name ?? '', '$ym ${v ? "مقدّم" : "غير مقدّم"}');
    _save();
  }

  List<Taxpayer> nonSubmitters(String ym) => taxpayers
      .where((t) => t.status == 'فعال' && !submitted(t.id, ym))
      .toList();

  // ---------- المبيعات والانخفاض ----------
  Future<void> loadSales() async {
    for (final t in taxpayers) {
      if (!sales.containsKey(t.id)) {
        sales[t.id] = await salesApi.fetchSales(t.taxNo);
      }
    }
    notifyListeners();
  }

  SalesSeries? salesOf(String taxId) => sales[taxId]; // ← إضافة جديدة

  double _num(String k) => (settings[k] as num).toDouble();

  DeclineInfo? declineOf(Taxpayer t) {
    final s = sales[t.id];
    if (s == null || t.status != 'فعال') return null;
    final m = s.monthly;
    double pct(double a, double b) => b == 0 ? 0 : (a - b) / b * 100;
    final dp = pct(m[11], m[10]);
    final dy = pct(m[11], s.prevYear[11]);
    final d3 = pct(m[11], (m[8] + m[9] + m[10]) / 3);
    final drop = -min(dp, min(dy, d3));
    String sev;
    if (drop >= _num('declineCritical')) {
      sev = 'critical';
    } else if (drop >= _num('declineHigh')) {
      sev = 'high';
    } else if (drop >= _num('declineMedium')) {
      sev = 'medium';
    } else {
      return null;
    }
    return DeclineInfo(t, dp, dy, d3, sev);
  }

  List<DeclineInfo> declines() {
    final l = <DeclineInfo>[];
    for (final t in taxpayers) {
      final d = declineOf(t);
      if (d != null) l.add(d);
    }
    l.sort((a, b) => a.worst.compareTo(b.worst));
    return l;
  }

  void sendDeclineAlert(DeclineInfo d, String note) {
    alertLog.add({
      'type': 'sales.${d.severity}',
      'title': 'تنبيه يدوي: ${d.t.name}',
      'detail': note.isEmpty ? 'انخفاض ${d.worst.toStringAsFixed(0)}%' : note,
      'severity': d.severity,
      'link': '/analytics/${d.t.id}',
      'ts': fmtDT(DateTime.now())
    });
    _log('إرسال تنبيه انخفاض', d.t.name, note);
    _save();
  }

  // ---------- التنبيهات وتوزيعها (بيد المدير) ----------
  bool receives(AppUser u, String type) {
    if (u.role == 'sysadmin') return true;
    final r = routing[type] ?? [];
    return r.contains('role:${u.role}') ||
        r.contains('user:${u.id}') ||
        (u.division.isNotEmpty && r.contains('div:${u.division}'));
  }

  List<AlertItem> alertsFor(AppUser u) {
    final out = <AlertItem>[];
    void add(AlertItem a) {
      if (receives(u, a.type)) out.add(a);
    }

    for (final d in declines()) {
      add(AlertItem(
          'sales.${d.severity}',
          'انخفاض مبيعات: ${d.t.name}',
          '${d.worst.toStringAsFixed(0)}% عن أضعف مقارنة',
          d.severity,
          '/analytics/${d.t.id}'));
    }
    final now = DateTime.now();
    if (now.day > (settings['statementsDeadlineDay'] as num)) {
      final n = nonSubmitters(ymOf(now)).length;
      if (n > 0) {
        add(AlertItem('statements.late', 'تأخر البيانات الشهرية',
            '$n مكلف لم يقدّم بيان ${ymOf(now)}', 'high', '/reports-center'));
      }
    }
    for (final r in reports) {
      if (r.status == 'ملغى') {
        add(AlertItem('report.cancelled', 'محضر ملغى: ${r.serial}',
            r.cancelReason ?? '', 'medium', '/reports/${r.id}'));
      }
      if (r.servedDate.isNotEmpty &&
          r.objectionNo.isEmpty &&
          r.status != 'ملغى') {
        final sd = DateTime.tryParse(r.servedDate.replaceAll('/', '-'));
        if (sd != null) {
          final left = (settings['objectionDays'] as num).toInt() -
              now.difference(sd).inDays;
          if (left >= 0 && left <= 2) {
            add(AlertItem(
                'objection.deadline',
                'تنتهي مهلة الاعتراض: ${r.serial}',
                'المتبقي $left يوم',
                'high',
                '/reports/${r.id}'));
          }
        }
      }
    }
    final g = totalGaps();
    if (g > 0) {
      add(AlertItem('serial.gap', 'أرقام محاضر غير مُحاسَب عليها', '$g رقم',
          'high', '/serials'));
    }
    for (final a in alertLog) {
      if (receives(u, a['type'] as String)) {
        out.add(AlertItem(
            a['type'] as String,
            a['title'] as String,
            a['detail'] as String,
            a['severity'] as String,
            a['link'] as String?));
      }
    }
    return out;
  }

  void togglePerm(String role, String perm) {
    final l = perms.putIfAbsent(role, () => []);
    if (l.contains(perm)) {
      l.remove(perm);
    } else {
      l.add(perm);
    }
    _log('تعديل صلاحية', role, perm);
    _save();
  }

  void toggleRoute(String type, String key) {
    final l = routing.putIfAbsent(type, () => []);
    if (l.contains(key)) {
      l.remove(key);
    } else {
      l.add(key);
    }
    _log('تعديل توزيع التنبيهات', type, key);
    _save();
  }

  // ---------- دفاتر الأرقام ----------
  List<int> usedIn(SerialBook b) {
    final u = <int>[];
    for (final r in reports) {
      final n = int.tryParse(r.serial);
      if (n != null && b.contains(n)) u.add(n);
    }
    return u;
  }

  /// أرقام أصغر من أكبر رقم مستخدم ولم يُسجَّل لها محضر ولا تسوية.
  List<int> gaps(SerialBook b) {
    final used = usedIn(b).toSet();
    if (used.isEmpty) return [];
    final mx = used.reduce(max);
    return [
      for (var n = b.from; n < mx; n++)
        if (!used.contains(n) && !b.reconciled.containsKey('$n')) n
    ];
  }

  int totalGaps() => books.fold<int>(0, (a, b) => a + gaps(b).length);

  String? addBook(int from, int to, String assignee) {
    if (from > to) return 'نطاق غير صحيح';
    if (books.any((b) => from <= b.to && to >= b.from)) {
      return 'النطاق يتداخل مع دفتر مُسلَّم';
    }
    books.add(SerialBook(id: newId(), from: from, to: to, assignee: assignee));
    _log('تسليم دفتر', assignee, '$from-$to');
    _save();
    return null;
  }

  void reconcile(SerialBook b, int n, String reason) {
    b.reconciled['$n'] = reason;
    _log('تسوية رقم محضر', '$n', reason);
    _save();
  }

  // ---------- المستخدمون والإعدادات ----------
  String? _expectedManagerRole(String role, String division) => switch (role) {
        'sectionHead' || 'infoSectionHead' => 'financeDirector',
        'deptHead' => 'sectionHead',
        'fieldHead' || 'officeHead' || 'archiveHead' => 'deptHead',
        'monitor' || 'user' => headRoleForDivision(division),
        _ => null,
      };

  ({String role, String division})? get nextRequiredLeadershipAccount {
    for (final role in [
      'financeDirector',
      'sectionHead',
      'infoSectionHead',
      'deptHead'
    ]) {
      if (!users.any((user) => user.active && user.role == role)) {
        return (role: role, division: '');
      }
    }
    for (final division in kDivisions.keys) {
      final role = headRoleForDivision(division)!;
      if (!users.any((user) =>
          user.active && user.role == role && user.division == division)) {
        return (role: role, division: division);
      }
    }
    return null;
  }

  String? _leadershipSetupError(AppUser user) {
    final required = nextRequiredLeadershipAccount;
    if (required == null || user.role == 'sysadmin') return null;
    if (user.role == required.role &&
        (!isDivisionHeadRole(required.role) ||
            user.division == required.division)) {
      return null;
    }
    final division =
        required.division.isEmpty ? '' : ' في ${kDivisions[required.division]}';
    return 'يجب إنشاء حساب «${kRoles[required.role]}»$division أولاً';
  }

  String? _uniqueRoleError(AppUser user) {
    final headDivision = divisionForHeadRole(user.role);
    if (headDivision != null && user.division != headDivision) {
      return 'الدور المختار لا يطابق الشعبة';
    }
    final duplicate = users.any((existing) {
      if (existing.id == user.id || !existing.active || !user.active) {
        return false;
      }
      return user.role == 'financeDirector' ||
              user.role == 'sectionHead' ||
              user.role == 'infoSectionHead' ||
              user.role == 'deptHead' ||
              isDivisionHeadRole(user.role)
          ? existing.role == user.role
          : false;
    });
    if (!duplicate) return null;
    return switch (user.role) {
      'financeDirector' => 'يوجد مدير مالية نشط بالفعل',
      'sectionHead' => 'يوجد رئيس قسم واردات نشط بالفعل',
      'infoSectionHead' => 'يوجد رئيس قسم معلوماتية نشط بالفعل',
      'deptHead' => 'يوجد رئيس دائرة إنفاق إستهلاكي نشط بالفعل',
      'fieldHead' => 'يوجد رئيس للشعبة الميدانية نشط بالفعل',
      'officeHead' => 'يوجد رئيس للشعبة المكتبية نشط بالفعل',
      'archiveHead' => 'يوجد رئيس لشعبة الأرشيف نشط بالفعل',
      _ => null,
    };
  }

  String? _managerError(AppUser user) {
    final expectedRole = _expectedManagerRole(user.role, user.division);
    if (expectedRole == null) {
      return user.managerId.isEmpty
          ? null
          : 'لهذا الدور لا يُحدَّد مسؤول مباشر';
    }
    if ((isDivisionHeadRole(user.role) ||
            ['monitor', 'user'].contains(user.role)) &&
        user.division.isEmpty) {
      return 'اختر الشعبة لهذا الدور';
    }
    final manager = users.where((candidate) =>
        candidate.id == user.managerId &&
        candidate.active &&
        candidate.role == expectedRole &&
        (!isDivisionHeadRole(expectedRole) ||
            candidate.division == user.division));
    if (manager.isEmpty) {
      final expectedName = kRoles[expectedRole] ?? expectedRole;
      return 'اختر المسؤول المباشر من دور «$expectedName»'
          '${isDivisionHeadRole(expectedRole) ? ' في الشعبة نفسها' : ''}';
    }
    return null;
  }

  String? addUser(AppUser u, String password) {
    final username = u.username.trim();
    if (u.name.trim().isEmpty || username.isEmpty) {
      return 'أدخل الاسم الكامل واسم المستخدم';
    }
    if (password.length < 6) {
      return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
    }
    if (users.any((x) => x.username.toLowerCase() == username.toLowerCase())) {
      return 'اسم المستخدم مستخدم';
    }
    final setupError = _leadershipSetupError(u);
    if (setupError != null) return setupError;
    final roleError = _uniqueRoleError(u);
    if (roleError != null) return roleError;
    final managerError = _managerError(u);
    if (managerError != null) return managerError;
    u
      ..name = u.name.trim()
      ..username = username
      ..passHash = AppUser.hashPassword(username, password)
      ..passwordChangeRequired = true;
    if (u.createdAt.isEmpty) u.createdAt = DateTime.now().toIso8601String();
    if (u.createdBy.isEmpty) u.createdBy = me?.name ?? 'النظام';
    users.add(u);
    _normalizeUserHierarchy();
    _log(
      'إنشاء حساب',
      u.username,
      '${kRoles[u.role] ?? u.role} · كلمة مرور مؤقتة، يلزم تغييرها عند أول دخول',
    );
    _save();
    return null;
  }

  String? updateUser(AppUser updated, {String? newPassword}) {
    final current = users.where((user) => user.id == updated.id);
    if (current.isEmpty) return 'الحساب غير موجود';
    final existing = current.first;
    if (existing.status == 'closed') {
      return 'الحساب مغلق نهائيًا ولا يمكن تعديله';
    }
    final username = updated.username.trim();
    final usernameChanged = username != existing.username;
    if (username.isEmpty) return 'أدخل اسم المستخدم';
    if (usernameChanged && me?.role != 'sysadmin') {
      return 'تعديل اسم المستخدم متاح لمدير النظام فقط';
    }
    if (users.any((user) =>
        user.id != updated.id &&
        user.username.toLowerCase() == username.toLowerCase())) {
      return 'اسم المستخدم مستخدم';
    }
    final password = newPassword?.trim() ?? '';
    if (usernameChanged && password.isEmpty) {
      return 'أدخل كلمة مرور جديدة عند تغيير اسم المستخدم';
    }
    if (password.isNotEmpty && password.length < 6) {
      return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
    }
    final roleError = _uniqueRoleError(updated);
    if (roleError != null) return roleError;
    if (existing.role == 'sysadmin' &&
        updated.role != 'sysadmin' &&
        users.where((user) => user.active && user.role == 'sysadmin').length <=
            1) {
      return 'لا يمكن تغيير دور آخر مدير نظام نشط';
    }
    final managerError = _managerError(updated);
    if (managerError != null) return managerError;
    for (final subordinate
        in users.where((user) => user.active && user.managerId == updated.id)) {
      final expectedRole =
          _expectedManagerRole(subordinate.role, subordinate.division);
      if (expectedRole != updated.role ||
          (isDivisionHeadRole(expectedRole ?? '') &&
              subordinate.division != updated.division)) {
        return 'لا يمكن تغيير الدور أو الشعبة؛ يوجد موظفون تابعون لهذا الحساب';
      }
    }
    final changes = <String>[];
    void addChange(String label, String before, String after) {
      if (before != after) changes.add('$label: $before ← $after');
    }

    addChange('الاسم', existing.name, updated.name.trim());
    addChange('رقم الموبايل', existing.phone, updated.phone.trim());
    addChange('اسم المستخدم', existing.username, username);
    addChange('الدور', kRoles[existing.role] ?? existing.role,
        kRoles[updated.role] ?? updated.role);
    addChange(
      'الشعبة',
      kDivisionNames[existing.division] ?? '—',
      kDivisionNames[updated.division] ?? '—',
    );
    String managerName(String id) {
      for (final user in users) {
        if (user.id == id) return user.name;
      }
      return '—';
    }

    final oldManager = managerName(existing.managerId);
    final newManager = managerName(updated.managerId);
    addChange('المسؤول المباشر', oldManager, newManager);
    if (password.isNotEmpty) changes.add('كلمة المرور: تم تغييرها');

    existing
      ..name = updated.name
      ..phone = updated.phone.trim()
      ..username = username
      ..role = updated.role
      ..division = updated.division
      ..managerId = updated.managerId;
    if (password.isNotEmpty) {
      existing.passHash = AppUser.hashPassword(existing.username, password);
      existing.passwordChangeRequired = true;
    }
    _normalizeUserHierarchy();
    _log('تعديل حساب', existing.username, changes.join(' · '));
    _save();
    return null;
  }

  String? setUserActive(AppUser u, bool v) {
    if (u.status == 'closed') {
      return 'الحساب مغلق نهائيًا ولا يمكن إعادة تفعيله';
    }
    if (u.active == v) return null;
    if (!v &&
        u.role == 'sysadmin' &&
        users.where((user) => user.active && user.role == 'sysadmin').length <=
            1) {
      return 'لا يمكن تعطيل آخر حساب مدير نظام نشط';
    }
    if (!v &&
        users.any((report) => report.active && report.managerId == u.id)) {
      return 'لا يمكن تعطيل المستخدم قبل إسناد مسؤول مباشر بديل للموظفين التابعين';
    }
    final roleError = _uniqueRoleError(AppUser(
        id: u.id,
        name: u.name,
        username: u.username,
        passHash: u.passHash,
        role: u.role,
        division: u.division,
        managerId: u.managerId,
        active: v));
    if (roleError != null) return roleError;
    final now = DateTime.now().toIso8601String();
    final actor = me?.name ?? 'النظام';
    if (v) {
      final openPeriod = u.statusPeriods.lastWhere(
        (period) => period.endedAt.isEmpty,
        orElse: () => AccountStatusPeriod(startedAt: '', startedBy: ''),
      );
      if (openPeriod.startedAt.isNotEmpty) {
        openPeriod
          ..endedAt = now
          ..endedBy = actor;
      }
    } else {
      u.statusPeriods.add(AccountStatusPeriod(
        startedAt: now,
        startedBy: actor,
      ));
    }
    u.active = v;
    _log(v ? 'إعادة تفعيل حساب' : 'تعطيل حساب مؤقت', u.username, '');
    _save();
    return null;
  }

  Future<String?> closeUser(
    String userId,
    String reason, {
    required String adminPassword,
  }) async {
    if (me?.role != 'sysadmin') {
      return 'إغلاق الحساب متاح لمدير النظام فقط';
    }
    if (me!.passHash != AppUser.hashPassword(me!.username, adminPassword)) {
      return 'كلمة مرور مدير النظام غير صحيحة';
    }
    final matches = users.where((user) => user.id == userId);
    if (matches.isEmpty) return 'الحساب غير موجود';
    final user = matches.first;
    if (user.id == me?.id) {
      return 'لا يمكن إغلاق حسابك أثناء تسجيل الدخول به';
    }
    if (user.status == 'closed') return 'الحساب مغلق نهائيًا بالفعل';
    if (user.active &&
        user.role == 'sysadmin' &&
        users
                .where((candidate) =>
                    candidate.active && candidate.role == 'sysadmin')
                .length <=
            1) {
      return 'لا يمكن إغلاق آخر حساب مدير نظام نشط';
    }
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return 'أدخل سبب إغلاق الحساب';
    if (users.any((subordinate) =>
        subordinate.active && subordinate.managerId == user.id)) {
      return 'لا يمكن إغلاق الحساب قبل إسناد مسؤول بديل للموظفين التابعين';
    }

    final now = DateTime.now().toIso8601String();
    final actor = me?.name ?? 'النظام';
    final openPeriod = user.statusPeriods.lastWhere(
      (period) => period.endedAt.isEmpty,
      orElse: () => AccountStatusPeriod(startedAt: '', startedBy: ''),
    );
    if (openPeriod.startedAt.isNotEmpty) {
      openPeriod
        ..endedAt = now
        ..endedBy = actor;
    }
    user
      ..active = false
      ..closedAt = now
      ..closedBy = actor
      ..closureReason = trimmedReason;
    _log('إغلاق حساب نهائي', user.username, trimmedReason);
    _save();
    await flushPersistence();
    return null;
  }

  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = me;
    if (user == null || !user.active) return 'يجب تسجيل الدخول أولاً';
    if (user.passHash != AppUser.hashPassword(user.username, currentPassword)) {
      return 'كلمة المرور الحالية غير صحيحة';
    }
    if (newPassword.length < 6) {
      return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
    }
    if (newPassword == currentPassword) {
      return 'اختر كلمة مرور مختلفة عن الحالية';
    }
    user
      ..passHash = AppUser.hashPassword(user.username, newPassword)
      ..passwordChangeRequired = false;
    _log('تغيير كلمة المرور', user.username, 'تحديث كلمة المرور بنجاح');
    _save();
    await flushPersistence();
    return null;
  }

  void setSetting(String k, dynamic v) {
    settings[k] = v;
    _log('تعديل إعداد', k, '$v');
    _save();
  }

  /// الوضع الداكن: يُحفظ في الإعدادات ويُطبَّق فوراً على كل الواجهة.
  bool get darkMode => settings['darkMode'] == true;
  void setDarkMode(bool v) => setSetting('darkMode', v);
  void toggleDarkMode() => setDarkMode(!darkMode);

  List<Map<String, dynamic>> get violationTypes =>
      ((settings['violationTypes'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  void setViolationTypes(List<Map<String, dynamic>> l) =>
      setSetting('violationTypes', l);

  // ---------- فحص السلامة والنسخ ----------
  List<IntegrityCheck> runIntegrity() {
    final out = <IntegrityCheck>[];
    var ok = true;
    var prev = 'GENESIS';
    var bad = -1;
    for (var i = 0; i < audit.length; i++) {
      final e = audit[i];
      if (e.prev != prev ||
          e.hash !=
              AuditEntry.compute(
                  e.prev, e.ts, e.user, e.action, e.entity, e.detail)) {
        ok = false;
        bad = i;
        break;
      }
      prev = e.hash;
    }
    out.add(IntegrityCheck(
        'سلسلة سجل العمليات',
        ok,
        ok
            ? '${audit.length} سجلاً متصلاً'
            : 'انكسرت السلسلة عند السجل رقم ${bad + 1}'));
    final tampered = reports
        .where((r) => r.locked && r.fingerprint != sha256Hex(r.canonical()))
        .toList();
    out.add(IntegrityCheck(
        'بصمات المحاضر المقفلة',
        tampered.isEmpty,
        tampered.isEmpty
            ? 'جميعها مطابقة'
            : 'محاضر معدّلة: ${tampered.map((r) => r.serial).join("، ")}'));
    final seen = <String>{};
    final dups = <String>{};
    for (final r in reports) {
      if (r.serial.isNotEmpty && !seen.add(r.serial)) dups.add(r.serial);
    }
    out.add(IntegrityCheck('أرقام المحاضر المكررة', dups.isEmpty,
        dups.isEmpty ? 'لا تكرار' : 'مكررة: ${dups.join("، ")}'));
    final g = totalGaps();
    out.add(IntegrityCheck('أرقام ناقصة في الدفاتر', g == 0,
        g == 0 ? 'كل الأرقام مُحاسَب عليها' : '$g رقم غير مُحاسَب عليه'));
    return out;
  }

  String exportAll() => const JsonEncoder.withIndent('  ').convert(_toJson());

  bool importAll(String s) {
    try {
      _load(jsonDecode(s) as Map<String, dynamic>);
      me = null;
      _log('استعادة نسخة', 'النظام', '');
      _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  void resetDemo() {
    sales = {};
    attachmentStore.clearAll();
    userPerms = {};
    _seed();
    loadSales();
  }
}
