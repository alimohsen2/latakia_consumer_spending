import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/core/theme.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:latakia_consumer_spending/screens/admin_screens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('شاشة إنشاء الحساب تُرسم دون أخطاء', (tester) async {
    final st = AppStore();
    await st.init();
    st.login('admin', '123456');

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: st,
        child: MaterialApp(
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
            child: const Scaffold(body: CreateAccountScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
    expect(find.text('بيانات الحساب'), findsOneWidget);
    expect(find.text('الوصول والمسؤول'), findsOneWidget);
  });
}
