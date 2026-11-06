import 'package:flutter_test/flutter_test.dart';
import 'package:latakia_consumer_spending/core/util.dart';

void main() {
  test('تطبيع النص العربي للبحث', () {
    expect(normAr('أَحمد'), normAr('احمد'));
    expect(normAr('مدرسة'), normAr('مدرسه'));
    expect(normAr('١٢٣'), '123');
  });
}
