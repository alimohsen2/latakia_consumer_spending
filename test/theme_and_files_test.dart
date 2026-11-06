import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/data/models.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('مدير النظام يرى أقسام المبيعات والمحاضر والبيانات دون ضبط يدوي',
      () async {
    final st = AppStore();
    await st.init();
    expect(st.login('admin', '123456'), isTrue);
    expect(st.can('analytics.view'), isTrue);
    expect(st.can('reports.view'), isTrue);
    expect(st.can('statements.edit'), isTrue);
    expect(st.can('registers.view'), isTrue);
    expect(st.can('taxpayers.edit'), isTrue);
  });

  test('ترحيل أدوار رؤساء الشعب والصلاحيات المحفوظة القديمة', () async {
    final original = AppStore();
    await original.init();
    final prefs = await SharedPreferences.getInstance();
    final data =
        jsonDecode(prefs.getString('lcs_db_v1')!) as Map<String, dynamic>;
    final users = (data['users'] as List).cast<Map<String, dynamic>>();
    for (final user in users.where((user) =>
        ['fieldHead', 'officeHead', 'archiveHead'].contains(user['role']))) {
      user['role'] = 'divisionHead';
    }

    final permissions = (data['perms'] as Map).cast<String, dynamic>();
    final oldHeadPermissions = permissions.remove('fieldHead') as List;
    permissions.remove('officeHead');
    permissions.remove('archiveHead');
    permissions['divisionHead'] = oldHeadPermissions;
    final routing = (data['routing'] as Map).cast<String, dynamic>();
    routing['report.cancelled'] = ['role:divisionHead'];

    await prefs.setString('lcs_db_v1', jsonEncode(data));
    final migrated = AppStore();
    await migrated.init();

    expect(
        migrated.users.firstWhere((user) => user.id == 'u4').role, 'fieldHead');
    expect(migrated.users.firstWhere((user) => user.id == 'u5').role,
        'officeHead');
    expect(migrated.users.firstWhere((user) => user.id == 'u6').role,
        'archiveHead');
    expect(migrated.perms.containsKey('divisionHead'), isFalse);
    for (final role in kDivisionHeadRoles.values) {
      expect(migrated.perms[role], oldHeadPermissions);
      expect(migrated.routing['report.cancelled'], contains('role:$role'));
    }
    expect(
      migrated.routing['report.cancelled'],
      isNot(contains('role:divisionHead')),
    );
  });

  test('تقييد المناصب الإدارية وإتاحة تعدد الموظفين والمراقبين', () async {
    final st = AppStore();
    await st.init();

    AppUser account(String id, String role,
            {String division = 'field', String managerId = ''}) =>
        AppUser(
          id: id,
          name: id,
          username: id,
          passHash: '',
          role: role,
          division: division,
          managerId: managerId,
        );

    expect(
      st.addUser(
          account('extra-finance', 'financeDirector', division: ''), '123456'),
      'يوجد مدير مالية نشط بالفعل',
    );
    expect(
      st.addUser(account('extra-dept', 'deptHead', division: ''), '123456'),
      'يوجد رئيس دائرة إنفاق إستهلاكي نشط بالفعل',
    );
    expect(
      st.addUser(
          account('extra-section', 'sectionHead', division: ''), '123456'),
      'يوجد رئيس قسم واردات نشط بالفعل',
    );
    expect(
      st.addUser(account('extra-field-head', 'fieldHead'), '123456'),
      'يوجد رئيس للشعبة الميدانية نشط بالفعل',
    );
    expect(
      st.addUser(
          account('extra-monitor-1', 'monitor', managerId: 'u4'), '123456'),
      isNull,
    );
    expect(
      st.addUser(
          account('extra-monitor-2', 'monitor', managerId: 'u4'), '123456'),
      isNull,
    );
    expect(
      st.addUser(account('no-manager', 'user'), '123456'),
      'اختر المسؤول المباشر من دور «رئيس الشعبة الميدانية» في الشعبة نفسها',
    );
    expect(
      st.addUser(account('extra-employee', 'user', managerId: 'u4'), '123456'),
      isNull,
    );
    expect(kRoles['user'], 'موظف');
    expect(kRoles['sectionHead'], 'رئيس قسم الواردات');
    expect(kRoles['infoSectionHead'], 'رئيس قسم المعلوماتية');
    expect(kRoles['deptHead'], 'رئيس دائرة الإنفاق الإستهلاكي');
    expect(kRoles['fieldHead'], 'رئيس الشعبة الميدانية');
    expect(kRoles['officeHead'], 'رئيس الشعبة المكتبية');
    expect(kRoles['archiveHead'], 'رئيس شعبة الأرشيف');
    expect(st.perms['infoSectionHead'], contains('reports.view'));
    expect(st.perms['infoSectionHead'], isNot(contains('reports.create')));
    expect(st.perms['infoSectionHead'], isNot(contains('users.manage')));
    expect(kDivisionNames, {
      'field': 'الميدانية',
      'office': 'المكتبية',
      'archive': 'الأرشيف',
    });
  });

  test('تعديل المستخدم يحافظ على التسلسل ويغيّر كلمة المرور عند طلبها',
      () async {
    final st = AppStore();
    await st.init();
    final employee = st.users.firstWhere((user) => user.id == 'u7');
    final updated = AppUser(
      id: employee.id,
      name: 'موظف ميداني معدل',
      username: employee.username,
      passHash: employee.passHash,
      role: employee.role,
      division: employee.division,
      managerId: employee.managerId,
      phone: '0991234567',
    );

    expect(st.updateUser(updated), isNull);
    expect(employee.name, 'موظف ميداني معدل');
    expect(employee.phone, '0991234567');
    expect(st.audit.last.detail,
        contains('الاسم: مستخدم ميداني ← موظف ميداني معدل'));
    expect(st.updateUser(updated, newPassword: 'newpass1'), isNull);
    expect(st.audit.last.detail, 'كلمة المرور: تم تغييرها');
    expect(employee.passwordChangeRequired, isTrue);
    expect(st.login('field1', '123456'), isFalse);
    expect(st.login('field1', 'newpass1'), isTrue);

    final invalidManager = AppUser(
      id: employee.id,
      name: employee.name,
      username: employee.username,
      passHash: employee.passHash,
      role: employee.role,
      division: employee.division,
      managerId: 'u2',
      phone: employee.phone,
    );
    expect(
      st.updateUser(invalidManager),
      'اختر المسؤول المباشر من دور «رئيس الشعبة الميدانية» في الشعبة نفسها',
    );
  });

  test('مدير النظام يستطيع تغيير اسم المستخدم مع تعيين كلمة مرور جديدة',
      () async {
    final st = AppStore();
    await st.init();
    expect(st.login('admin', '123456'), isTrue);
    final admin = st.users.firstWhere((user) => user.role == 'sysadmin');
    final updated = AppUser(
      id: admin.id,
      name: admin.name,
      username: 'admin-renamed',
      passHash: admin.passHash,
      role: admin.role,
    );

    expect(
        st.updateUser(updated), 'أدخل كلمة مرور جديدة عند تغيير اسم المستخدم');
    expect(st.updateUser(updated, newPassword: 'newadmin1'), isNull);
    expect(st.login('admin', '123456'), isFalse);
    expect(st.login('admin-renamed', 'newadmin1'), isTrue);
  });

  test('لا يمكن تعطيل آخر مدير نظام نشط', () async {
    final st = AppStore();
    await st.init();
    final admin = st.users.firstWhere((user) => user.role == 'sysadmin');

    expect(
      st.setUserActive(admin, false),
      'لا يمكن تعطيل آخر حساب مدير نظام نشط',
    );
    expect(admin.active, isTrue);
  });

  test('حفظ الحسابات ينتظر الكتابة المحلية ويستعيدها بعد إعادة فتح المخزن',
      () async {
    final st = AppStore();
    await st.init();
    final monitor = AppUser(
      id: 'persistent-monitor',
      name: 'مراقب محفوظ',
      username: 'saved-monitor',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
      phone: '0997654321',
    );

    expect(st.addUser(monitor, 'saved123'), isNull);
    await st.flushPersistence();

    final restored = AppStore();
    await restored.init();
    expect(
      restored.users.any((user) => user.username == 'saved-monitor'),
      isTrue,
    );
    expect(
      restored.users
          .firstWhere((user) => user.username == 'saved-monitor')
          .phone,
      '0997654321',
    );
    expect(restored.persistenceError, isNull);
  });

  test('صورة المستخدم تُحفظ وتُستبدل وتُستعاد منفصلة عن بيانات الحساب',
      () async {
    final st = AppStore();
    await st.init();
    final user = st.users.firstWhere((user) => user.id == 'u7');
    final firstPhoto = Uint8List.fromList([1, 2, 3]);
    final secondPhoto = Uint8List.fromList([4, 5, 6]);

    expect(
      await st.setUserPhoto(
        user.id,
        name: 'first.png',
        mime: 'image/png',
        bytes: firstPhoto,
      ),
      isNull,
    );
    final firstPhotoId = user.photoId;
    expect(await st.attachmentBytes(firstPhotoId), firstPhoto);
    expect(
      await st.setUserPhoto(
        user.id,
        name: 'not-an-image.pdf',
        mime: 'application/pdf',
        bytes: secondPhoto,
      ),
      'اختر ملف صورة صالحًا',
    );

    expect(
      await st.setUserPhoto(
        user.id,
        name: 'second.jpg',
        mime: 'image/jpeg',
        bytes: secondPhoto,
      ),
      isNull,
    );
    expect(await st.attachmentBytes(firstPhotoId), isNull);
    await st.flushPersistence();

    final restored = AppStore();
    await restored.init();
    final restoredUser = restored.users.firstWhere((user) => user.id == 'u7');
    expect(restoredUser.photoId, user.photoId);
    expect(await restored.attachmentBytes(restoredUser.photoId), secondPhoto);
  });

  test('كلمة مرور الحساب الجديد مؤقتة ويجب تغييرها قبل إكمال الاستخدام',
      () async {
    final st = AppStore();
    await st.init();
    expect(st.login('admin', '123456'), isTrue);
    final account = AppUser(
      id: 'temporary-password-account',
      name: 'مستخدم كلمة مرور مؤقتة',
      username: 'temp-user',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );

    expect(st.addUser(account, 'temp123'), isNull);
    expect(account.passwordChangeRequired, isTrue);
    expect(
      await st.changeOwnPassword(
        currentPassword: 'wrong123',
        newPassword: 'secure123',
      ),
      'كلمة المرور الحالية غير صحيحة',
    );
    expect(st.login('temp-user', 'temp123'), isTrue);
    expect(account.passwordChangeRequired, isTrue);
    expect(
      await st.changeOwnPassword(
        currentPassword: 'temp123',
        newPassword: 'secure123',
      ),
      isNull,
    );
    expect(account.passwordChangeRequired, isFalse);
    expect(st.login('temp-user', 'temp123'), isFalse);
    expect(st.login('temp-user', 'secure123'), isTrue);

    final restored = AppStore();
    await restored.init();
    expect(
      restored.users
          .firstWhere((user) => user.id == account.id)
          .passwordChangeRequired,
      isFalse,
    );
  });

  test('دورة حياة الحساب تحفظ المنشئ وفترات التعطيل والإغلاق النهائي',
      () async {
    final st = AppStore();
    await st.init();
    expect(st.login('admin', '123456'), isTrue);
    final account = AppUser(
      id: 'lifecycle-account',
      name: 'حساب دورة الحياة',
      username: 'lifecycle',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );

    expect(st.addUser(account, 'lifecycle123'), isNull);
    expect(account.createdAt, isNotEmpty);
    expect(account.createdBy, 'مدير النظام');
    expect(st.setUserActive(account, false), isNull);
    expect(account.status, 'disabled');
    expect(account.statusPeriods, hasLength(1));
    expect(account.statusPeriods.single.startedBy, 'مدير النظام');
    expect(st.audit.last.detail, isEmpty);
    expect(st.setUserActive(account, true), isNull);
    expect(account.statusPeriods.single.endedAt, isNotEmpty);
    expect(account.statusPeriods.single.endedBy, 'مدير النظام');

    final employeeWithSubordinates =
        st.users.firstWhere((user) => user.id == 'u4');
    expect(
      st.setUserActive(employeeWithSubordinates, false),
      'لا يمكن تعطيل المستخدم قبل إسناد مسؤول مباشر بديل للموظفين التابعين',
    );
    expect(
      await st.closeUser('u4', 'اختبار', adminPassword: '123456'),
      isNotNull,
    );

    expect(
      await st.closeUser(
        account.id,
        'انتهاء الحاجة للحساب',
        adminPassword: 'wrong-password',
      ),
      'كلمة مرور مدير النظام غير صحيحة',
    );
    expect(account.status, 'active');
    expect(
      await st.closeUser(
        account.id,
        'انتهاء الحاجة للحساب',
        adminPassword: '123456',
      ),
      isNull,
    );
    expect(account.status, 'closed');
    expect(account.closedAt, isNotEmpty);
    expect(account.closedBy, 'مدير النظام');
    expect(account.closureReason, 'انتهاء الحاجة للحساب');
    expect(
      st.setUserActive(account, true),
      'الحساب مغلق نهائيًا ولا يمكن إعادة تفعيله',
    );
    expect(st.login('lifecycle', 'lifecycle123'), isFalse);
    await st.flushPersistence();

    final restored = AppStore();
    await restored.init();
    final restoredAccount =
        restored.users.firstWhere((user) => user.id == account.id);
    expect(restoredAccount.status, 'closed');
    expect(restoredAccount.createdBy, 'مدير النظام');
    expect(restoredAccount.statusPeriods, hasLength(1));
    expect(restoredAccount.statusPeriods.single.endedAt, isNotEmpty);
    expect(restoredAccount.closureReason, 'انتهاء الحاجة للحساب');
    expect(restoredAccount.closedBy, 'مدير النظام');
  });

  test('تعذر قراءة المخزن لا يستبدل البيانات التالفة ببيانات افتراضية',
      () async {
    const invalidData = '{"users": [';
    SharedPreferences.setMockInitialValues({'lcs_db_v1': invalidData});
    final st = AppStore();

    await expectLater(st.init(), throwsA(isA<StateError>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lcs_db_v1'), invalidData);
  });

  test('إضافة الحسابات تتطلب استكمال الهيكل الإداري بالترتيب', () async {
    final st = AppStore();
    await st.init();
    st.users.removeWhere((user) => user.role != 'sysadmin');

    AppUser account(String id, String role,
            {String division = '', String managerId = ''}) =>
        AppUser(
          id: id,
          name: id,
          username: id,
          passHash: '',
          role: role,
          division: division,
          managerId: managerId,
        );

    expect(st.nextRequiredLeadershipAccount?.role, 'financeDirector');
    expect(
      st.addUser(
          account('early-employee', 'user',
              division: 'field', managerId: 'missing-head'),
          '123456'),
      'يجب إنشاء حساب «مدير المالية» أولاً',
    );

    expect(
      st.addUser(account('finance', 'financeDirector'), '123456'),
      isNull,
    );
    expect(st.nextRequiredLeadershipAccount?.role, 'sectionHead');
    expect(
      st.addUser(
          account('section', 'sectionHead', managerId: 'finance'), '123456'),
      isNull,
    );
    expect(st.nextRequiredLeadershipAccount?.role, 'infoSectionHead');
    expect(
      st.addUser(
          account('info-section', 'infoSectionHead', managerId: 'finance'),
          '123456'),
      isNull,
    );
    expect(st.nextRequiredLeadershipAccount?.role, 'deptHead');
    expect(
      st.addUser(account('dept', 'deptHead', managerId: 'section'), '123456'),
      isNull,
    );

    for (final division in kDivisions.keys) {
      final role = headRoleForDivision(division)!;
      expect(st.nextRequiredLeadershipAccount?.division, division);
      expect(
        st.addUser(
          account('head-$division', role,
              division: division, managerId: 'dept'),
          '123456',
        ),
        isNull,
      );
    }
    expect(st.nextRequiredLeadershipAccount, isNull);
    expect(
      st.addUser(
          account('employee', 'user',
              division: 'field', managerId: 'head-field'),
          '123456'),
      isNull,
    );
  });

  test('الصلاحيات المحفوظة القديمة لا تُخفي الأقسام عن مدير النظام', () async {
    SharedPreferences.setMockInitialValues({
      'lcs_db_v1':
          '{"perms":{"sysadmin":["taxpayers.view"]},"settings":{},"users":[]}',
    });
    final st = AppStore();
    await st.init();
    // البيانات غير صالحة (بلا مستخدمين) فتُعاد التهيئة، لكن المهم ألا يبقى
    // مدير النظام محروماً من أي صلاحية.
    expect(st.perms['sysadmin'], isNotEmpty);
    expect(st.perms['sysadmin']!.toSet().containsAll(kPerms.keys), isTrue);
  });

  test('الوضع الداكن يُحفظ ويُستعاد بعد إعادة التشغيل', () async {
    final st = AppStore();
    await st.init();
    expect(st.darkMode, isFalse);
    st.setDarkMode(true);
    expect(st.darkMode, isTrue);

    final st2 = AppStore();
    await st2.init();
    expect(st2.darkMode, isTrue);
  });

  test('صور أضبارة المكلف تُحفظ وتُستعاد مع بيانات المكلف', () async {
    final st = AppStore();
    await st.init();
    final t = st.taxpayers.first;
    final a = await st.addTaxpayerAttachment(
      t,
      name: 'سجل-تجاري.jpg',
      mime: 'image/jpeg',
      bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
    );
    expect(a, isNotNull);
    expect(t.attachments.length, 1);
    expect(st.attachmentCount, greaterThanOrEqualTo(1));

    final restored = Attachment.fromJson(t.attachments.first.toJson());
    expect(restored.name, 'سجل-تجاري.jpg');
    expect(restored.isImage, isTrue);

    final st2 = AppStore();
    await st2.init();
    final t2 = st2.tp(t.id)!;
    expect(t2.attachments.length, 1);
    expect(t2.attachments.first.id, a!.id);
    expect(await st2.attachmentBytes(a.id), isNotNull);

    await st2.removeTaxpayerAttachment(t2, t2.attachments.first);
    expect(t2.attachments, isEmpty);
    expect(await st2.attachmentBytes(a.id), isNull);
  });
}
