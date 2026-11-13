import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latakia_consumer_spending/core/theme.dart';
import 'package:latakia_consumer_spending/data/models.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:latakia_consumer_spending/main.dart';
import 'package:latakia_consumer_spending/router.dart';
import 'package:latakia_consumer_spending/screens/admin_screens.dart';
import 'package:latakia_consumer_spending/screens/dashboard_screen.dart';
import 'package:latakia_consumer_spending/screens/login_screen.dart';
import 'package:latakia_consumer_spending/screens/taxpayers_screen.dart';
import 'package:latakia_consumer_spending/widgets/brand.dart';
import 'package:latakia_consumer_spending/widgets/common.dart';
import 'package:latakia_consumer_spending/widgets/shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppStore> makeStore() async {
    final s = AppStore();
    await s.init();
    s.login('admin', '123456');
    return s;
  }

  Widget wrap(AppStore st, Widget home) => ChangeNotifierProvider.value(
        value: st,
        child: Consumer<AppStore>(
          builder: (c, s, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            darkTheme: buildTheme(dark: true),
            themeMode: s.darkMode ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: home),
            ),
          ),
        ),
      );

  testWidgets('صفحة المكلف: زر رجوع وأضبارة أسفل البطاقة، بلا فيض على عرض ضيق',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester
        .pumpWidget(wrap(st, TaxpayerProfileScreen(id: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('رجوع'), findsOneWidget);
    expect(find.text('أضبارة المكلف'), findsOneWidget);
    expect(find.text('فتح الأضبارة'), findsOneWidget);
  });

  testWidgets('قائمة المكلفين: رأس وبطاقات إحصاء وبحث بلا فيض على عرض ضيق',
      (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const TaxpayersScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('المكلفون'), findsOneWidget);
    expect(find.text('البحث والتصفية'), findsOneWidget);
    expect(find.text('إجمالي المكلفين'), findsOneWidget);
    expect(find.text('قائمة المكلفين'), findsOneWidget);
  });

  testWidgets('تعديل اسم المستخدم لا يعيد إنشاء الموجّه أثناء إغلاق الحوار',
      (tester) async {
    final st = await makeStore();
    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/users');
    await tester.pumpAndSettle();
    final originalRole =
        st.users.firstWhere((user) => user.role == 'sysadmin').role;
    await tester.ensureVisible(find.byTooltip('تعديل المستخدم').first);
    await tester.tap(find.byTooltip('تعديل المستخدم').first);
    await tester.pumpAndSettle();

    expect(find.text('اختيار صورة شخصية'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.text('الدور')),
      findsNothing,
    );
    await tester.enterText(find.byType(TextFormField).at(1), '0991234567');
    await tester.enterText(find.byType(TextFormField).at(2), 'admin-renamed');
    await tester.enterText(find.byType(TextFormField).at(3), 'newadmin1');
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(st.users.firstWhere((user) => user.role == 'sysadmin').username,
        'admin-renamed');
    expect(st.users.firstWhere((user) => user.username == 'admin-renamed').role,
        originalRole);
    expect(
        st.users.firstWhere((user) => user.username == 'admin-renamed').phone,
        '0991234567');
    expect(st.login('admin-renamed', 'newadmin1'), isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('تعديل المستخدم لا يعرض المسؤول المباشر ويحافظ على تعيينه',
      (tester) async {
    final st = await makeStore();
    final user = st.users.firstWhere((user) => user.id == 'u7');
    final managerId = user.managerId;
    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/users');
    await tester.pumpAndSettle();
    final editButton = find.byTooltip('تعديل المستخدم').at(8);
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.text('المسؤول المباشر')),
      findsNothing,
    );
    await tester.enterText(find.byType(TextFormField).first, 'موظف تم تعديله');
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();

    expect(user.name, 'موظف تم تعديله');
    expect(user.managerId, managerId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('صفحة المستخدمين الفعّالين تعرض جلسة هذا الجهاز بوضوح',
      (tester) async {
    final st = await makeStore();
    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/active-users');
    await tester.pumpAndSettle();

    expect(find.text('المستخدمون الفعّالون حاليًا'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('مدير النظام'), findsWidgets);
    expect(find.text('المستخدمون المسجّلون على هذا الجهاز: 1'), findsOneWidget);
    expect(find.textContaining('ستظهر جلسات بقية الأجهزة عند ربط الخادم'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحساب الجديد لا يتجاوز تغيير كلمة المرور المؤقتة',
      (tester) async {
    final st = await makeStore();
    final account = AppUser(
      id: 'first-login-user',
      name: 'مستخدم جديد',
      username: 'first-login',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );
    expect(st.addUser(account, 'temp123'), isNull);
    st.logout();
    expect(st.login('first-login', 'temp123'), isTrue);

    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();
    expect(find.text('أنشئ كلمة مرور جديدة'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'كلمة المرور الحالية'), 'temp123');
    await tester.enterText(
        find.widgetWithText(
            TextField, 'كلمة المرور الجديدة (6 أحرف على الأقل)'),
        'secure123');
    await tester.enterText(
        find.widgetWithText(TextField, 'تأكيد كلمة المرور الجديدة'),
        'secure123');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pumpAndSettle();

    expect(account.passwordChangeRequired, isFalse);
    expect(find.text('أنشئ كلمة مرور جديدة'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('مسؤول الموظف والمراقب يتحدد تلقائياً حسب الشعبة',
      (tester) async {
    final st = await makeStore();
    st.users.firstWhere((user) => user.id == 'u4').name = 'ساهر خطاب';
    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/users');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('اختيار صورة شخصية'), findsOneWidget);
    expect(find.text('بلا شعبة'), findsNothing);
    expect(find.text('ساهر خطاب (رئيس الشعبة الميدانية)'), findsOneWidget);
    expect(find.text('المسؤول المباشر'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('دور رئيس قسم المعلوماتية متاح ويتبع مدير المالية',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    // تعطيل حساب رئيس قسم المعلوماتية الحالي لجعل الدور متاحاً للإنشاء
    st.users.firstWhere((u) => u.id == 'u11').active = false;
    await tester.pumpWidget(App(store: st));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/users');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('رئيس قسم المعلوماتية'), findsWidgets);
    // اختيار الدور يعيّن مدير المالية كمسؤول مباشر تلقائياً
    await tester.tap(find.text('رئيس قسم المعلوماتية').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('مدير المالية'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إدارة المستخدمين تصفّي بحسب الحالة وتعرض سجل الحساب',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final employee = st.users.firstWhere((user) => user.id == 'u7');
    employee.createdAt = '2025-03-04T14:27:00';
    employee.phone = '0997654321';
    st.users.firstWhere((user) => user.id == 'u4').name = 'اسم صاحب الدور';
    expect(st.setUserActive(employee, false), isNull);
    await tester.pumpWidget(wrap(st, const UsersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('إدارة المستخدمين'), findsAtLeast(1));
    expect(find.byType(UsersScreen), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معطل مؤقتًا').last);
    await tester.pumpAndSettle();
    expect(find.text('field1'), findsOneWidget);
    expect(find.text('مستخدم ميداني'), findsOneWidget);
    expect(find.byTooltip('رفع صورة المستخدم'), findsNothing);
    expect(find.text('0997654321'), findsOneWidget);
    expect(find.text('الميدانية'), findsOneWidget);
    expect(find.text('الشعبة الميدانية'), findsNothing);
    expect(find.textContaining('2025/03/04'), findsOneWidget);
    expect(find.textContaining('2:27  مساءً'), findsOneWidget);
    expect(find.textContaining('اسم صاحب الدور'), findsOneWidget);
    expect(find.text('مدير النظام'), findsNothing);
    expect(find.text('مستخدم مكتبي'), findsNothing);
    expect(find.textContaining('نتيجة'), findsOneWidget);

    await tester.tap(find.byTooltip('تفاصيل وسجل الحساب').first);
    await tester.pumpAndSettle();
    expect(find.text('بيانات الحساب'), findsOneWidget);
    expect(find.text('سجل التعطيل وإعادة التفعيل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('سجل العمليات يعرض سجل المستخدم المختار فقط', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    st.setSetting('auditTest', 'admin-entry');
    expect(st.login('field1', '123456'), isTrue);
    st.setSetting('auditTest', 'employee-entry');
    final employeeOperationCount =
        st.audit.where((entry) => entry.user == 'مستخدم ميداني').length;

    await tester.pumpWidget(wrap(st, const AuditScreen()));
    await tester.pumpAndSettle();
    expect(find.text('منفذ العملية'), findsOneWidget);
    expect(find.text('العنصر المتأثر'), findsOneWidget);
    expect(find.text('نوع العملية'), findsOneWidget);
    expect(find.text('تفاصيل إضافية'), findsOneWidget);
    expect(find.text('admin-entry'), findsOneWidget);
    expect(find.text('employee-entry'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    final employeeOption = find.text('مستخدم ميداني').last;
    await tester.ensureVisible(employeeOption);
    await tester.pumpAndSettle();
    await tester.tap(employeeOption);
    await tester.pumpAndSettle();

    expect(find.text('employee-entry'), findsOneWidget);
    expect(find.text('admin-entry'), findsNothing);
    expect(
      find.text('عدد العمليات المعروضة: $employeeOperationCount'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('جدول سجل العمليات يبقى مقروءاً على الشاشة الضيقة',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const AuditScreen()));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(GridTable),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('قائمة المكلفين: بطاقات منظمة على الشاشات الكبيرة',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const TaxpayersScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('الرقم الضريبي'), findsWidgets);
    expect(find.byTooltip('عرض التفاصيل'), findsWidgets);
    expect(find.byTooltip('فتح الأضبارة'), findsWidgets);
    expect(find.text('اسم المنشأة'), findsNothing);
  });

  testWidgets(
      'القائمة الجانبية: اختيار اسم القسم يفتح الصفحة ويبقي الاسم ظاهراً',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final router = buildRouter(st);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp.router(
          theme: buildTheme(),
          darkTheme: buildTheme(dark: true),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Sidebar>(find.byType(Sidebar)).floating, isTrue);
    expect(find.text('التنبيهات والمواعيد'), findsOneWidget);
    expect(find.text('المكلفون'), findsOneWidget);
    expect(find.text('اعتماد المحاضر'), findsNothing);
    final alertCount = st.alertsFor(st.me!).length;
    if (alertCount > 0) {
      expect(
        find.descendant(
          of: find.byType(Sidebar),
          matching: find.text(alertCount > 99 ? '99+' : '$alertCount'),
        ),
        findsOneWidget,
      );
    }

    final sidebarList = find.descendant(
      of: find.byType(Sidebar),
      matching: find.byType(ListView),
    );
    await tester.drag(sidebarList, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.text('المستخدمون والصلاحيات'), findsOneWidget);
    expect(find.text('السجلات والرقابة'), findsOneWidget);
    expect(find.text('تهيئة النظام'), findsOneWidget);
    await tester.drag(sidebarList, const Offset(0, 5000));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.byTooltip('إخفاء القائمة الجانبية'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.byTooltip('طي مجموعة المكلفون'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.byIcon(Icons.groups_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('المكلفون').first);
    await tester.pumpAndSettle();
    expect(find.text('التنبيهات والمواعيد'), findsNothing);
    final taxpayerMenuItem = find.text('المكلفون').last;
    expect(taxpayerMenuItem, findsOneWidget);
    await tester.tap(taxpayerMenuItem);
    await tester.pumpAndSettle();

    expect(find.text('قائمة المكلفين'), findsOneWidget);
    expect(
      find
          .descendant(
            of: find.byType(Sidebar),
            matching: find.text('المكلفون'),
          )
          .last,
      findsOneWidget,
    );
    expect(find.byTooltip('المكلفون'), findsNothing);

    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.byTooltip('طي المجموعة المفتوحة'),
      ),
      findsNothing,
    );
    final toggleAllButton = find
        .descendant(
          of: find.byType(Sidebar),
          matching: find.byType(IconButton),
        )
        .first;
    await tester.tap(toggleAllButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('المكلفون'),
      ),
      findsOneWidget,
    );
    expect(find.text('التنبيهات والمواعيد'), findsNothing);

    await tester.tap(toggleAllButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('المكلفون'),
      ),
      findsNWidgets(2),
    );

    await tester.drag(sidebarList, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final reportsGroup = find.text('المحاضر').first;
    await tester.tap(reportsGroup);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('المكلفون'),
      ),
      findsOneWidget,
    );
    expect(find.text('اعتماد المحاضر'), findsOneWidget);

    await tester.drag(sidebarList, const Offset(0, 5000));
    await tester.pumpAndSettle();
    await tester.tap(toggleAllButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('اعتماد المحاضر'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('القائمة الجانبية على الهاتف تفتح وتغلق بعد اختيار صفحة',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final router = buildRouter(st);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp.router(
          theme: buildTheme(),
          darkTheme: buildTheme(dark: true),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mobileScaffold = find
        .ancestor(
          of: find.byTooltip('فتح القائمة الجانبية'),
          matching: find.byType(Scaffold),
        )
        .first;

    await tester.tap(find.byTooltip('فتح القائمة الجانبية'));
    await tester.pumpAndSettle();
    expect(tester.state<ScaffoldState>(mobileScaffold).isDrawerOpen, isTrue);
    expect(
      find.descendant(
        of: find.byType(Sidebar),
        matching: find.text('المكلفون'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find
          .descendant(
            of: find.byType(Sidebar),
            matching: find.text('المكلفون'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(Sidebar),
            matching: find.text('المكلفون'),
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.text('قائمة المكلفين'), findsOneWidget);
    expect(tester.state<ScaffoldState>(mobileScaffold).isDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('لوحة التحكم تُرسم بالوضع الفاتح والداكن دون أخطاء',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('مديرية مالية اللاذقية'), findsOneWidget);
    expect(find.text('المبيعات والتحليل'), findsOneWidget);
    // قسم «آخر المحاضر» أُزيل من اللوحة.
    expect(find.text('آخر المحاضر'), findsNothing);
    expect(find.text('آخر المكلفين'), findsNothing);
    expect(find.text('محاضر هذا الشهر'), findsNothing);
    expect(find.text('بانتظار الاعتماد'), findsNothing);
    // أُزيلت الشعارات وصورة الهيئة من رأس اللوحة.
    expect(find.byType(BrandLogos), findsNothing);
    // أُزيلت العبارة التعريفية.
    expect(find.text('نظرة عامة على المبيعات وأداء المكلفين'), findsNothing);
    // قسم إحصاءات المكلفين الجديد.
    expect(find.text('إحصائيات المكلفين'), findsOneWidget);
    expect(find.text('إجمالي المكلفين'), findsOneWidget);
    expect(find.text('المكلفون الفعالون'), findsOneWidget);
    expect(find.text('المتوقفون مؤقتاً'), findsOneWidget);

    st.setDarkMode(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('بطاقات إحصائيات المكلفين تظهر بالتتابع مع عدّ تصاعدي',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const DashboardScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final firstCard = tester
        .widget<Opacity>(find.byKey(const ValueKey('taxpayer-stat-card-0')));
    final lastCard = tester
        .widget<Opacity>(find.byKey(const ValueKey('taxpayer-stat-card-3')));
    expect(firstCard.opacity, greaterThan(lastCard.opacity));
    expect(firstCard.opacity, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 1200));
    final completedLastCard = tester
        .widget<Opacity>(find.byKey(const ValueKey('taxpayer-stat-card-3')));
    expect(completedLastCard.opacity, 1);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('taxpayer-stat-card-0')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('لوحة التحكم على عرض ضيق: بطاقات المكلفين بلا فيض',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('إجمالي المكلفين'), findsOneWidget);
    expect(find.text('المتوقفون مؤقتاً'), findsOneWidget);

    // اكتمال أنيميشن العدّ لا يسبب أي خطأ.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('شاشة الدخول: شعار الهيئة وهوية مختصرة وأنيميشن بلا فيض',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(BrandLogos), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    final logo = tester.widget<Image>(find.byType(Image));
    expect(
      logo.image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/logos/dept_logo.png',
      ),
    );
    expect(find.text('مديرية مالية اللاذقية'), findsOneWidget);
    expect(find.text('دائرة الإنفاق الاستهلاكي'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    // النصوص الزائدة أُزيلت.
    expect(find.text('الجمهورية العربية السورية'), findsNothing);
    expect(find.text('أدخل بيانات حسابك للمتابعة'), findsNothing);
    expect(find.text('نظام أتمتة المحاضر والمكلفين'), findsNothing);

    // اكتمال أنيميشن الدخول لا يسبب أي خطأ.
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}
