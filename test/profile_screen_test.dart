import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/core/theme.dart';
import 'package:latakia_consumer_spending/data/models.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:latakia_consumer_spending/screens/profile_screen.dart';
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

  testWidgets('صلاحيات لكل حساب: الإضافة والحذف تؤثر على الحساب فقط', (tester) async {
    final st = await makeStore();
    final account = AppUser(
      id: 'perm-user-1',
      name: 'مراقب الصلاحيات',
      username: 'perm-test',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );
    expect(st.addUser(account, '123456'), isNull);

    // صلاحيات الدور الافتراضية
    expect(st.effectivePermsFor(account), containsAll(['reports.view', 'reports.create']));
    expect(st.hasPermOverride(account.id), isFalse);

    // إضافة صلاحية لحساب واحد فقط
    st.addUserPerm(account.id, 'reports.cancel');
    expect(st.effectivePermsFor(account), contains('reports.cancel'));
    expect(st.hasPermOverride(account.id), isTrue);
    // حساب آخر من نفس الدور لا يتأثر
    final other = AppUser(
      id: 'perm-user-2',
      name: 'مراقب آخر',
      username: 'perm-test-2',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );
    expect(st.addUser(other, '123456'), isNull);
    expect(st.effectivePermsFor(other), isNot(contains('reports.cancel')));

    // الحذف يؤثر على هذا الحساب فقط
    st.removeUserPerm(account.id, 'reports.view');
    expect(st.effectivePermsFor(account), isNot(contains('reports.view')));
    expect(st.effectivePermsFor(other), contains('reports.view'));

    // الاستعادة ترجع صلاحيات الدور
    st.resetUserPerms(account.id);
    expect(st.effectivePermsFor(account), contains('reports.view'));
    expect(st.hasPermOverride(account.id), isFalse);
  });

  testWidgets('ملف مستخدم: يعرض الصلاحيات عمودياً مع زر إضافة للمدير', (tester) async {
    tester.view.physicalSize = const Size(1440, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final account = AppUser(
      id: 'perm-widget-user',
      name: 'مراقب للاختبار',
      username: 'perm-widget',
      passHash: '',
      role: 'monitor',
      division: 'field',
      managerId: 'u4',
    );
    expect(st.addUser(account, '123456'), isNull);

    await tester.pumpWidget(wrap(st, const ProfileScreen(userId: 'perm-widget-user')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('الصلاحيات'), findsOneWidget);
    expect(find.text('إضافة صلاحية'), findsOneWidget);
    expect(find.byWidgetPredicate(
        (w) => w is Icon && w.icon == CupertinoIcons.minus_circle),
        findsWidgets);
  });

  testWidgets('ملف المستخدم: يرسم دون أخطاء على عرضين', (tester) async {
    for (final width in const [420.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final st = await makeStore();
      await tester.pumpWidget(wrap(st, const ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('ملفي الشخصي'), findsAtLeast(1));
      expect(find.text('إجمالي الغرامات'), findsAtLeast(1));
      expect(find.text('الصلاحيات'), findsOneWidget);
    }
  });
}
