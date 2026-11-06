import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores a valid login until the user logs out', () async {
    SharedPreferences.setMockInitialValues({});
    final firstStore = AppStore();
    await firstStore.init();

    expect(firstStore.login('admin', '123456'), isTrue);
    await firstStore.flushPersistence();

    final restoredStore = AppStore();
    await restoredStore.init();
    expect(restoredStore.loggedIn, isTrue);
    expect(restoredStore.me?.username, 'admin');

    restoredStore.logout();
    await restoredStore.flushPersistence();
    final signedOutStore = AppStore();
    await signedOutStore.init();
    expect(signedOutStore.loggedIn, isFalse);
  });
}
