import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/core/theme.dart';
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
