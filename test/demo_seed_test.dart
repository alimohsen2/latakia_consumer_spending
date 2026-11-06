import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new installs start with linked demo records', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.init();

    expect(store.taxpayers, hasLength(10));
    expect(store.taxpayers.first.name, 'مخبز السنابل');
    expect(store.reports, hasLength(5));
    expect(store.followups, hasLength(2));
    expect(store.statements, isNotEmpty);
    expect(
      store.reports.every((report) =>
          store.taxpayers.any((taxpayer) => taxpayer.id == report.taxpayerId)),
      isTrue,
    );
    expect(
      store.followups.every((followup) =>
          store.reports.any((report) => report.id == followup.reportId)),
      isTrue,
    );
  });

  test('upgrades untouched empty demo data without replacing settings or users',
      () async {
    const categories = ['صاغة', 'مطاعم', 'شركات شامبو', 'أخرى'];
    SharedPreferences.setMockInitialValues({
      'lcs_db_v1': jsonEncode({
        'users': [
          {
            'id': 'existing',
            'name': 'مستخدم محفوظ',
            'username': 'saved',
            'passHash': 'hash',
            'role': 'user',
          }
        ],
        'taxpayers': [
          for (var i = 1; i <= 10; i++)
            {
              'id': 't$i',
              'name': 'منشأة تجريبية $i',
              'owner': 'مالك تجريبي $i',
              'category': categories[i % 3],
              'taxNo': '${1000000 + i}',
              'address': 'اللاذقية - [عنوان $i]',
              'profession': '',
              'status': i == 7 ? 'متوقف مؤقتاً' : 'فعال',
            }
        ],
        'reports': [],
        'followups': [],
        'statements': [],
        'audit': [],
        'books': [],
        'savedFilters': [],
        'alertLog': [],
        'perms': {},
        'routing': {},
        'settings': {'darkMode': true},
      }),
    });

    final store = AppStore();
    await store.init();

    expect(store.reports, isNotEmpty);
    expect(store.users.single.username, 'saved');
    expect(store.settings['darkMode'], isTrue);
  });
}
