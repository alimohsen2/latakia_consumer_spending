import '../core/util.dart';

const kStatuses = ['فعال', 'متوقف مؤقتاً', 'متوقف نهائياً'];
const kCategories = ['صاغة', 'مطاعم', 'شركات شامبو', 'أخرى'];
const kDivisions = {
  'field': 'الشعبة الميدانية',
  'office': 'الشعبة المكتبية',
  'archive': 'شعبة الأرشيف'
};
const kDivisionNames = {
  'field': 'الميدانية',
  'office': 'المكتبية',
  'archive': 'الأرشيف',
};
const kDivisionHeadRoles = {
  'field': 'fieldHead',
  'office': 'officeHead',
  'archive': 'archiveHead',
};

String? divisionForHeadRole(String role) {
  for (final entry in kDivisionHeadRoles.entries) {
    if (entry.value == role) return entry.key;
  }
  return null;
}

String? headRoleForDivision(String division) => kDivisionHeadRoles[division];

bool isDivisionHeadRole(String role) => divisionForHeadRole(role) != null;

const kRoles = {
  'sysadmin': 'مدير النظام',
  'financeDirector': 'مدير المالية',
  'sectionHead': 'رئيس قسم الواردات',
  'infoSectionHead': 'رئيس قسم المعلوماتية',
  'deptHead': 'رئيس دائرة الإنفاق الإستهلاكي',
  'fieldHead': 'رئيس الشعبة الميدانية',
  'officeHead': 'رئيس الشعبة المكتبية',
  'archiveHead': 'رئيس شعبة الأرشيف',
  'monitor': 'مراقب',
  'user': 'موظف',
};

/// قائمة الصلاحيات. يعدّلها مدير النظام من شاشة الصلاحيات.
const kPerms = {
  'taxpayers.view': 'عرض المكلفين والبحث',
  'taxpayers.edit': 'إضافة وتعديل المكلفين',
  'taxpayers.status': 'تغيير حالة المكلف',
  'reports.view': 'عرض المحاضر',
  'reports.create': 'إنشاء محضر',
  'reports.approve': 'اعتماد المحضر (رئيس الشعبة)',
  'reports.endorse': 'تصديق المحضر (رئيس دائرة الإنفاق الإستهلاكي)',
  'reports.print': 'طباعة المحضر وقفله',
  'reports.cancel': 'إلغاء المحضر',
  'registers.view': 'عرض سجل المخالفات والمتابعة',
  'registers.edit': 'تعديل سجل المخالفات والمتابعة',
  'statements.edit': 'تسجيل البيانات الشهرية',
  'analytics.view': 'مبيعات المكلفين وانخفاضها',
  'alerts.view': 'التنبيهات',
  'reports.center': 'التقارير',
  'users.manage': 'إدارة المستخدمين',
  'permissions.manage': 'إدارة الصلاحيات',
  'alerts.route': 'توزيع التنبيهات',
  'serials.manage': 'دفاتر أرقام المحاضر',
  'audit.view': 'سجل العمليات',
  'integrity.view': 'سلامة السجلات',
  'settings.manage': 'الإعدادات والنسخ الاحتياطي',
  'archive.view': 'عرض الأرشيف والبحث فيه',
  'archive.edit': 'تسجيل موقع المحضر في الأرشيف',
  'archive.attachments': 'إضافة مرفقات المحاضر وحذفها',
  'field.view': 'العمل الميداني وقائمة المسودات',
  'field.create': 'إنشاء محضر ميداني',
  'field.sync': 'مزامنة المسودات الميدانية',
};

const kAlertTypes = {
  'sales.critical': 'انخفاض مبيعات (حرج)',
  'sales.high': 'انخفاض مبيعات (مرتفع)',
  'sales.medium': 'انخفاض مبيعات (متوسط)',
  'statements.late': 'تأخر البيانات الشهرية',
  'objection.deadline': 'اقتراب انتهاء مهلة الاعتراض',
  'report.cancelled': 'إلغاء محضر',
  'serial.gap': 'رقم محضر ناقص أو مكرر',
  'security': 'حدث أمني',
};

Map<String, List<String>> defaultPerms() {
  final divisionHeadPerms = [
    'taxpayers.view',
    'taxpayers.edit',
    'taxpayers.status',
    'reports.view',
    'reports.create',
    'reports.approve',
    'reports.print',
    'registers.view',
    'registers.edit',
    'statements.edit',
    'analytics.view',
    'alerts.view',
    'reports.center',
    'archive.view',
    'archive.attachments',
    'field.view',
    'field.create',
    'field.sync'
  ];
  return {
    'sysadmin': kPerms.keys.toList(),
    'financeDirector': [
      'taxpayers.view',
      'taxpayers.edit',
      'taxpayers.status',
      'reports.view',
      'reports.endorse',
      'reports.print',
      'reports.cancel',
      'registers.view',
      'registers.edit',
      'statements.edit',
      'analytics.view',
      'alerts.view',
      'reports.center',
      'audit.view',
      'integrity.view',
      'archive.view',
      'archive.edit',
      'archive.attachments',
      'field.view'
    ],
    'sectionHead': [
      'taxpayers.view',
      'reports.view',
      'registers.view',
      'analytics.view',
      'alerts.view',
      'reports.center',
      'audit.view',
      'integrity.view',
      'archive.view',
      'field.view'
    ],
    'infoSectionHead': [
      'taxpayers.view',
      'reports.view',
      'registers.view',
      'analytics.view',
      'alerts.view',
      'reports.center',
      'audit.view',
      'integrity.view',
      'archive.view',
      'field.view'
    ],
    'deptHead': [
      'taxpayers.view',
      'taxpayers.edit',
      'taxpayers.status',
      'reports.view',
      'reports.endorse',
      'reports.print',
      'reports.cancel',
      'registers.view',
      'registers.edit',
      'statements.edit',
      'analytics.view',
      'alerts.view',
      'reports.center',
      'audit.view',
      'integrity.view',
      'archive.view',
      'archive.edit',
      'archive.attachments',
      'field.view'
    ],
    for (final role in kDivisionHeadRoles.values)
      role: List<String>.from(divisionHeadPerms),
    'monitor': [
      'reports.view',
      'reports.create',
      'reports.print',
      'field.view',
      'field.create',
      'field.sync'
    ],
    'user': [
      'taxpayers.view',
      'reports.view',
      'reports.create',
      'reports.print',
      'registers.view',
      'registers.edit',
      'statements.edit',
      'alerts.view',
      'archive.view',
      'field.view',
      'field.create',
      'field.sync'
    ],
  };
}

Map<String, List<String>> defaultRouting() => {
      'sales.critical': ['role:sectionHead', 'role:deptHead', 'div:office'],
      'sales.high': ['role:deptHead', 'div:office'],
      'sales.medium': ['div:office'],
      'statements.late': ['role:deptHead', 'div:office'],
      'objection.deadline': ['div:office'],
      'report.cancelled': ['role:sectionHead', 'role:deptHead'],
      'serial.gap': ['role:sectionHead', 'role:deptHead'],
      'security': [],
    };

class Taxpayer {
  String id, name, owner, category, taxNo, address, profession, status;
  List<Map<String, dynamic>> history;

  /// صور الأوراق والمستندات داخل أضبارة المكلف (سجل تجاري، هوية، إجازة...).
  /// البايتات في AttachmentStore، وهنا الوصف فقط.
  List<Attachment> attachments;

  Taxpayer(
      {required this.id,
      required this.name,
      this.owner = '',
      this.category = 'أخرى',
      required this.taxNo,
      this.address = '',
      this.profession = '',
      this.status = 'فعال',
      List<Map<String, dynamic>>? history,
      List<Attachment>? attachments})
      : history = history ?? [],
        attachments = attachments ?? [];
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner': owner,
        'category': category,
        'taxNo': taxNo,
        'address': address,
        'profession': profession,
        'status': status,
        'history': history,
        'attachments': attachments.map((e) => e.toJson()).toList()
      };
  factory Taxpayer.fromJson(Map<String, dynamic> j) => Taxpayer(
        id: j['id'] as String,
        name: j['name'] as String,
        owner: (j['owner'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'أخرى',
        taxNo: (j['taxNo'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        profession: (j['profession'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'فعال',
        history: ((j['history'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        attachments: ((j['attachments'] as List?) ?? [])
            .map(
                (e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Violation {
  String type, article;
  num fine;
  Violation({required this.type, this.article = '', this.fine = 0});
  Map<String, dynamic> toJson() =>
      {'type': type, 'article': article, 'fine': fine};
  factory Violation.fromJson(Map<String, dynamic> j) => Violation(
      type: j['type'] as String,
      article: (j['article'] as String?) ?? '',
      fine: (j['fine'] as num?) ?? 0);
}

/// مرفق (صورة مخالفة، إشعار، ضبط، قرار...) مرتبط بمحضر أو بمسودة ميدانية.
/// ملف البايتات يُحفظ منفصلاً في AttachmentStore، ويُحفظ هنا الوصف فقط.
class Attachment {
  String id, ownerId, name, mime, kind, note, uploadedAt, uploadedBy;
  int size;

  Attachment({
    required this.id,
    required this.ownerId,
    required this.name,
    this.mime = 'application/octet-stream',
    this.kind = 'document',
    this.size = 0,
    this.note = '',
    this.uploadedAt = '',
    this.uploadedBy = '',
  });

  bool get isImage => mime.startsWith('image/');
  bool get isPdf => mime == 'application/pdf';

  Attachment copyWith({String? ownerId}) => Attachment(
        id: id,
        ownerId: ownerId ?? this.ownerId,
        name: name,
        mime: mime,
        kind: kind,
        size: size,
        note: note,
        uploadedAt: uploadedAt,
        uploadedBy: uploadedBy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'mime': mime,
        'kind': kind,
        'size': size,
        'note': note,
        'uploadedAt': uploadedAt,
        'uploadedBy': uploadedBy,
      };

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        ownerId: (j['ownerId'] as String?) ?? '',
        name: (j['name'] as String?) ?? 'ملف',
        mime: (j['mime'] as String?) ?? 'application/octet-stream',
        kind: (j['kind'] as String?) ?? 'document',
        size: (j['size'] as num?)?.toInt() ?? 0,
        note: (j['note'] as String?) ?? '',
        uploadedAt: (j['uploadedAt'] as String?) ?? '',
        uploadedBy: (j['uploadedBy'] as String?) ?? '',
      );
}

class Report {
  String id,
      serial,
      taxpayerId,
      orderNo,
      orderDate,
      status,
      createdBy,
      division;
  DateTime date;
  List<Violation> items;
  num lateFeePct;
  String servedName,
      servedCapacity,
      servedFather,
      servedMother,
      servedNationalNo,
      inspectors,
      fieldHead,
      deptHead;
  String servedDate, objectionNo, objectionDate, referralDate, committee;
  num referralValue;
  String? cancelReason, fingerprint, returnNote;
  DateTime? printedAt;
  // بيانات الأرشيف الورقي: مرجع الملف، رقم الصندوق، ملاحظات، ومن أرشفه ومتى.
  String archiveRef, archiveBox, archiveNotes, archivedAt, archivedBy;
  List<Attachment> attachments;

  Report({
    required this.id,
    required this.serial,
    required this.taxpayerId,
    required this.date,
    this.orderNo = '',
    this.orderDate = '',
    this.status = 'مسودة',
    this.createdBy = '',
    this.division = '',
    List<Violation>? items,
    this.lateFeePct = 0,
    this.servedName = '',
    this.servedCapacity = '',
    this.servedFather = '',
    this.servedMother = '',
    this.servedNationalNo = '',
    this.inspectors = '',
    this.fieldHead = '',
    this.deptHead = '',
    this.servedDate = '',
    this.objectionNo = '',
    this.objectionDate = '',
    this.referralDate = '',
    this.committee = '',
    this.referralValue = 0,
    this.cancelReason,
    this.fingerprint,
    this.returnNote,
    this.printedAt,
    this.archiveRef = '',
    this.archiveBox = '',
    this.archiveNotes = '',
    this.archivedAt = '',
    this.archivedBy = '',
    List<Attachment>? attachments,
  })  : items = items ?? [],
        attachments = attachments ?? [];

  num get total => items.fold<num>(0, (a, v) => a + v.fine);
  bool get locked => status == 'مقفل';
  bool get archived => archivedAt.isNotEmpty;
  bool get hasArchiveLocation => archiveRef.isNotEmpty || archiveBox.isNotEmpty;

  /// النص الذي تُحسب منه بصمة المحضر عند القفل.
  String canonical() =>
      '$serial|$taxpayerId|${date.toIso8601String()}|$orderNo|$orderDate|${items.map((e) => '${e.type}:${e.article}:${e.fine}').join(',')}|$lateFeePct|$servedName|$servedNationalNo|$total';

  Map<String, dynamic> toJson() => {
        'id': id,
        'serial': serial,
        'taxpayerId': taxpayerId,
        'date': date.toIso8601String(),
        'orderNo': orderNo,
        'orderDate': orderDate,
        'status': status,
        'createdBy': createdBy,
        'division': division,
        'items': items.map((e) => e.toJson()).toList(),
        'lateFeePct': lateFeePct,
        'servedName': servedName,
        'servedCapacity': servedCapacity,
        'servedFather': servedFather,
        'servedMother': servedMother,
        'servedNationalNo': servedNationalNo,
        'inspectors': inspectors,
        'fieldHead': fieldHead,
        'deptHead': deptHead,
        'servedDate': servedDate,
        'objectionNo': objectionNo,
        'objectionDate': objectionDate,
        'referralDate': referralDate,
        'committee': committee,
        'referralValue': referralValue,
        'cancelReason': cancelReason,
        'fingerprint': fingerprint,
        'returnNote': returnNote,
        'printedAt': printedAt?.toIso8601String(),
        'archiveRef': archiveRef,
        'archiveBox': archiveBox,
        'archiveNotes': archiveNotes,
        'archivedAt': archivedAt,
        'archivedBy': archivedBy,
        'attachments': attachments.map((e) => e.toJson()).toList(),
      };
  factory Report.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] as String?) ?? '';
    return Report(
      id: j['id'] as String,
      serial: s('serial'),
      taxpayerId: s('taxpayerId'),
      date: DateTime.parse(j['date'] as String),
      orderNo: s('orderNo'),
      orderDate: s('orderDate'),
      status: s('status'),
      createdBy: s('createdBy'),
      division: s('division'),
      items: ((j['items'] as List?) ?? [])
          .map((e) => Violation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      lateFeePct: (j['lateFeePct'] as num?) ?? 0,
      servedName: s('servedName'),
      servedCapacity: s('servedCapacity'),
      servedFather: s('servedFather'),
      servedMother: s('servedMother'),
      servedNationalNo: s('servedNationalNo'),
      inspectors: s('inspectors'),
      fieldHead: s('fieldHead'),
      deptHead: s('deptHead'),
      servedDate: s('servedDate'),
      objectionNo: s('objectionNo'),
      objectionDate: s('objectionDate'),
      referralDate: s('referralDate'),
      committee: s('committee'),
      referralValue: (j['referralValue'] as num?) ?? 0,
      cancelReason: j['cancelReason'] as String?,
      fingerprint: j['fingerprint'] as String?,
      returnNote: j['returnNote'] as String?,
      printedAt: j['printedAt'] == null
          ? null
          : DateTime.parse(j['printedAt'] as String),
      archiveRef: s('archiveRef'),
      archiveBox: s('archiveBox'),
      archiveNotes: s('archiveNotes'),
      archivedAt: s('archivedAt'),
      archivedBy: s('archivedBy'),
      attachments: ((j['attachments'] as List?) ?? [])
          .map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// سجل المتابعة: قرارات اللجنة القضائية ولجنة تقدير البيانات والتحصيل.
class FollowUp {
  String reportId;
  Map<String, String> data;
  FollowUp(this.reportId, [Map<String, String>? d]) : data = d ?? {};
  Map<String, dynamic> toJson() => {'reportId': reportId, 'data': data};
  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
      j['reportId'] as String, Map<String, String>.from(j['data'] as Map));
}

class AccountStatusPeriod {
  String startedAt, startedBy, reason, endedAt, endedBy;

  AccountStatusPeriod({
    required this.startedAt,
    required this.startedBy,
    this.reason = '',
    this.endedAt = '',
    this.endedBy = '',
  });

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt,
        'startedBy': startedBy,
        'reason': reason,
        'endedAt': endedAt,
        'endedBy': endedBy,
      };

  factory AccountStatusPeriod.fromJson(Map<String, dynamic> json) =>
      AccountStatusPeriod(
        startedAt: (json['startedAt'] as String?) ?? '',
        startedBy: (json['startedBy'] as String?) ?? '',
        reason: (json['reason'] as String?) ?? '',
        endedAt: (json['endedAt'] as String?) ?? '',
        endedBy: (json['endedBy'] as String?) ?? '',
      );
}

class AppUser {
  String id, name, username, passHash, role, division, managerId;
  String phone, photoId;
  String createdAt, createdBy, closedAt, closedBy, closureReason;
  bool active, passwordChangeRequired;
  List<AccountStatusPeriod> statusPeriods;

  String get status => closedAt.isNotEmpty
      ? 'closed'
      : active
          ? 'active'
          : 'disabled';

  AppUser(
      {required this.id,
      required this.name,
      required this.username,
      required this.passHash,
      required this.role,
      this.division = '',
      this.managerId = '',
      this.phone = '',
      this.photoId = '',
      this.active = true,
      this.passwordChangeRequired = false,
      String? createdAt,
      this.createdBy = '',
      this.closedAt = '',
      this.closedBy = '',
      this.closureReason = '',
      List<AccountStatusPeriod>? statusPeriods})
      : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        statusPeriods = statusPeriods ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'passHash': passHash,
        'role': role,
        'division': division,
        'managerId': managerId,
        'phone': phone,
        'photoId': photoId,
        'active': active,
        'passwordChangeRequired': passwordChangeRequired,
        'status': status,
        'createdAt': createdAt,
        'createdBy': createdBy,
        'closedAt': closedAt,
        'closedBy': closedBy,
        'closureReason': closureReason,
        'statusPeriods':
            statusPeriods.map((period) => period.toJson()).toList(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
      id: j['id'] as String,
      name: j['name'] as String,
      username: j['username'] as String,
      passHash: j['passHash'] as String,
      role: j['role'] as String,
      division: (j['division'] as String?) ?? '',
      managerId: (j['managerId'] as String?) ?? '',
      phone: (j['phone'] as String?) ?? '',
      photoId: (j['photoId'] as String?) ?? '',
      active: switch (j['status']) {
        'active' => true,
        'disabled' || 'closed' => false,
        _ => (j['active'] as bool?) ?? true,
      },
      passwordChangeRequired: (j['passwordChangeRequired'] as bool?) ?? false,
      createdAt: (j['createdAt'] as String?) ?? '',
      createdBy: (j['createdBy'] as String?) ?? '',
      closedAt: (j['closedAt'] as String?) ?? '',
      closedBy: (j['closedBy'] as String?) ?? '',
      closureReason: (j['closureReason'] as String?) ?? '',
      statusPeriods: ((j['statusPeriods'] as List?) ?? [])
          .map((period) => AccountStatusPeriod.fromJson(
              Map<String, dynamic>.from(period as Map)))
          .toList());
  static String hashPassword(String username, String password) =>
      sha256Hex('$username:$password');
}

class AuditEntry {
  String id, ts, user, action, entity, detail, prev, hash;
  AuditEntry(
      {required this.id,
      required this.ts,
      required this.user,
      required this.action,
      required this.entity,
      required this.detail,
      required this.prev,
      required this.hash});
  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'user': user,
        'action': action,
        'entity': entity,
        'detail': detail,
        'prev': prev,
        'hash': hash
      };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
      id: j['id'] as String,
      ts: j['ts'] as String,
      user: j['user'] as String,
      action: j['action'] as String,
      entity: j['entity'] as String,
      detail: j['detail'] as String,
      prev: j['prev'] as String,
      hash: j['hash'] as String);
  static String compute(String prev, String ts, String user, String action,
          String entity, String detail) =>
      sha256Hex('$prev|$ts|$user|$action|$entity|$detail');
}

class SerialBook {
  String id, assignee;
  int from, to;
  bool closed;
  Map<String, String> reconciled;
  SerialBook(
      {required this.id,
      required this.from,
      required this.to,
      required this.assignee,
      this.closed = false,
      Map<String, String>? reconciled})
      : reconciled = reconciled ?? {};
  bool contains(int n) => n >= from && n <= to;
  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'assignee': assignee,
        'closed': closed,
        'reconciled': reconciled
      };
  factory SerialBook.fromJson(Map<String, dynamic> j) => SerialBook(
      id: j['id'] as String,
      from: j['from'] as int,
      to: j['to'] as int,
      assignee: j['assignee'] as String,
      closed: (j['closed'] as bool?) ?? false,
      reconciled: Map<String, String>.from((j['reconciled'] as Map?) ?? {}));
}

class MonthlyStatement {
  String taxId, ym;
  bool submitted;
  String date;
  MonthlyStatement(this.taxId, this.ym, this.submitted, this.date);
  Map<String, dynamic> toJson() =>
      {'taxId': taxId, 'ym': ym, 'submitted': submitted, 'date': date};
  factory MonthlyStatement.fromJson(Map<String, dynamic> j) => MonthlyStatement(
      j['taxId'] as String,
      j['ym'] as String,
      j['submitted'] as bool,
      (j['date'] as String?) ?? '');
}

class AlertItem {
  final String type, title, detail, severity;
  final String? link;
  AlertItem(this.type, this.title, this.detail, this.severity, [this.link]);
}
