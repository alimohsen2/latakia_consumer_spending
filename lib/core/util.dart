import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

/// توحيد النص العربي للبحث: حذف التشكيل، توحيد الهمزات والتاء المربوطة والألف المقصورة، وتحويل الأرقام الهندية.
String normAr(String s) {
  var t = s.toLowerCase();
  t = t.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
  const m = {'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي'};
  m.forEach((k, v) {
    t = t.replaceAll(k, v);
  });
  const ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  return t.trim();
}

String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

String hmacHex(String key, String msg) =>
    Hmac(sha256, utf8.encode(key)).convert(utf8.encode(msg)).toString();

String fmtDate(DateTime d) => DateFormat('yyyy/MM/dd').format(d);
String fmtDT(DateTime d) => DateFormat('yyyy/MM/dd HH:mm').format(d);
String fmtTime12(DateTime d) =>
    '${(d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'صباحاً' : 'مساءً'}';
String ymOf(DateTime d) => DateFormat('yyyy-MM').format(d);

int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}${_seq++}';

String money(num v) => NumberFormat('#,##0').format(v);
