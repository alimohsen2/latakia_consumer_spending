import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/core/theme.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:latakia_consumer_spending/screens/reports_screens.dart';
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

  testWidgets('نموذج المحضر: بلا فيض على عرض ضيق', (tester) async {
    tester.view.physicalSize = const Size(420, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    final ex = tester.takeException();
    expect(ex, isNull);
    expect(find.text('إنشاء محضر ضبط مخالفة'), findsOneWidget);
    expect(find.text('المخالفات المضبوطة'), findsOneWidget);
    expect(find.text('التبليغ والضابطة'), findsOneWidget);
    expect(find.text('ملخص المحضر'), findsOneWidget);
  });

  testWidgets('نموذج المحضر: بلا فيض على عرض واسع', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('إنشاء محضر ضبط مخالفة'), findsOneWidget);
    expect(find.text('ملخص المحضر'), findsOneWidget);
    expect(find.text('المالك المسجل'), findsOneWidget);
    expect(find.text('الرقم الضريبي'), findsOneWidget);
    expect(find.text('العنوان'), findsOneWidget);
  });

  testWidgets('نموذج المحضر: مراقب إضافي يدوياً بلا فيض على عرض ضيق',
      (tester) async {
    tester.view.physicalSize = const Size(420, 3800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة مراقب'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('monitor-manual-mode-2')));
    await tester.pumpAndSettle();

    expect(find.text('المراقب الثالث'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('نموذج المحضر: المراقبان الأولان من الحسابات فقط',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('المراقب الأول'), findsOneWidget);
    expect(find.text('المراقب الثاني'), findsOneWidget);
    expect(find.text('من النظام'), findsNothing);
    expect(find.text('من حسابات النظام'), findsNothing);
    expect(find.text('اختر مراقباً مسجّلاً'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is TextField &&
          (widget.decoration?.labelText ?? '').contains('يدوياً')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('نموذج المحضر: اختيار المراقب الأول من الحسابات',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final monitorNames = st.users
        .where((user) =>
            user.active && (user.role == 'monitor' || user.role == 'user'))
        .map((user) => user.name)
        .toList();
    expect(monitorNames, isNotEmpty);

    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    final firstPicker = find.byKey(const ValueKey('monitor-system-0'));
    await tester.tap(firstPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text(monitorNames.first).last);
    await tester.pumpAndSettle();

    expect(tester.widget<DropdownButton<String>>(firstPicker).value,
        monitorNames.first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('نموذج المحضر: مراقب إضافي يدوياً ورفض اسم موجود في الحسابات',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    final monitorName = st.users
        .where((user) =>
            user.active && (user.role == 'monitor' || user.role == 'user'))
        .map((user) => user.name)
        .first;
    await tester.pumpWidget(
        wrap(st, ReportFormScreen(taxpayerId: st.taxpayers.first.id)));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة مراقب'));
    await tester.pumpAndSettle();

    expect(find.text('المراقب الثالث'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('monitor-manual-mode-2')));
    await tester.pumpAndSettle();

    final manualField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'اسم المراقب الثالث (يدوياً)',
    );
    expect(manualField, findsOneWidget);

    await tester.enterText(manualField, monitorName);
    await tester.pump();
    expect(find.text('هذا الاسم موجود في الحسابات، اختره من القائمة'),
        findsOneWidget);

    await tester.enterText(manualField, 'مراقب من خارج الدائرة');
    await tester.pump();
    expect(find.text('هذا الاسم موجود في الحسابات، اختره من القائمة'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('نموذج المحضر: يعرض مسودة قائمة بمخالفات بلا فيض',
      (tester) async {
    tester.view.physicalSize = const Size(420, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeStore();
    await tester.pumpWidget(wrap(st, const ReportFormScreen(id: 'r3')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.text('عدم تقديم بيان المبيعات'), findsOneWidget);
    expect(find.text('1 مخالفة · 100,000 ل.س'), findsOneWidget);
    expect(find.text('ملخص المحضر'), findsOneWidget);
  });
}
