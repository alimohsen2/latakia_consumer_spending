import 'dart:math';
import '../core/util.dart';
import 'models.dart';

/// سلاسل المبيعات القادمة من واجهة الـ API (الأقدم أولاً).
class SalesSeries {
  final List<double> monthly; // آخر 12 شهراً
  final List<double> prevYear; // نفس الأشهر من السنة الماضية
  final List<double> daily; // آخر 30 يوماً
  final List<double> yearly; // آخر 5 سنوات
  SalesSeries(this.monthly, this.prevYear, this.daily, this.yearly);
}

/// الواجهة التي يجب أن يحققها الاتصال الحقيقي بالـ API.
abstract class SalesApi {
  Future<SalesSeries> fetchSales(String taxNo);
  Future<Map<String, String>?> lookupTaxpayer(String taxNo);
}

/// تنفيذ تجريبي بأرقام ثابتة مشتقة من الرقم الضريبي. استبدله بتنفيذ HttpSalesApi يستدعي الخلفية.
class MockSalesApi implements SalesApi {
  int _seed(String s) => int.parse(sha256Hex(s).substring(0, 7), radix: 16);

  @override
  Future<SalesSeries> fetchSales(String taxNo) async {
    final sd = _seed(taxNo);
    final r = Random(sd);
    final base = 50 + r.nextInt(100).toDouble();
    final declines = sd % 4 == 0;
    final growth = (r.nextDouble() - .3) * 2;
    final monthly = List<double>.generate(12, (i) {
      var v = base + growth * i + r.nextDouble() * 8;
      if (declines && i >= 9) v = v * (1 - 0.18 * (i - 8));
      return v;
    });
    final prev = List<double>.generate(12, (i) => base * .95 + growth * i * .8 + r.nextDouble() * 8);
    final daily = List<double>.generate(30, (i) => (monthly[11] / 30) * (.7 + r.nextDouble() * .6));
    final yearly = List<double>.generate(5, (i) => base * 12 * (.6 + i * .12) * ((declines && i == 4) ? .8 : 1));
    return SalesSeries(monthly, prev, daily, yearly);
  }

  @override
  Future<Map<String, String>?> lookupTaxpayer(String taxNo) async {
    if (taxNo.trim().length < 4) return null;
    final sd = _seed(taxNo);
    return {
      'name': 'منشأة [رقم $taxNo]',
      'owner': '[المالك المسجل]',
      'address': '[العنوان]',
      'category': kCategories[sd % 3],
      'profession': '',
    };
  }
}
