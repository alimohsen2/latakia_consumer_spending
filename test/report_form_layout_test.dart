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
