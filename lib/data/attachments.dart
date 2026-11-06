import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// تخزين مرفقات المحاضر (صور، PDF، مستندات) في مساحة محلية منفصلة عن قاعدة
/// البيانات المصغّرة، حتى لا يتضخم ملف JSON الأساسي.
///
/// في الإنتاج: تُرفع الملفات إلى الخلفية (`POST /reports/{id}/attachments`)
/// وتُخزَّن على القرص/الخادم، ويبقى هنا الوصف فقط.
class AttachmentStore {
  static const _prefix = 'lcs_att_v1_';

  /// أقصى حجم للملف الواحد: 1.5 ميغابايت. الحد الفعلي لمساحة المتصفح أقل،
  /// لذلك نرفض الملفات الكبيرة مبكراً برسالة واضحة.
  static const int maxBytes = 1500000;

  SharedPreferences? _p;
  final Map<String, Uint8List> _cache = {};

  Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();
  }

  Future<void> put(String id, Uint8List bytes) async {
    await init();
    _cache[id] = bytes;
    await _p!.setString('$_prefix$id', base64Encode(bytes));
  }

  Future<Uint8List?> get(String id) async {
    final c = _cache[id];
    if (c != null) return c;
    await init();
    final s = _p!.getString('$_prefix$id');
    if (s == null) return null;
    try {
      final b = base64Decode(s);
      _cache[id] = b;
      return b;
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    await init();
    _cache.remove(id);
    await _p!.remove('$_prefix$id');
  }

  /// إجمالي المساحة المستخدمة تقديرياً بالبايت.
  Future<int> usedBytes() async {
    await init();
    var n = 0;
    for (final k in _p!.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final s = _p!.getString(k);
      if (s != null) n += (s.length * 3) ~/ 4;
    }
    return n;
  }

  /// حذف كل المرفقات (يُستخدم عند إعادة البيانات التجريبية).
  Future<void> clearAll() async {
    await init();
    _cache.clear();
    final keys = _p!.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _p!.remove(k);
    }
  }
}
