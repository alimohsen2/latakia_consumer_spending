import 'package:dio/dio.dart';

import '../../data/field_sync.dart';
import '../models.dart';

/// عميل API لتسجيل موقع جولة المراقب الميداني.
class FieldApiClient {
  final Dio dio;

  FieldApiClient({
    required String baseUrl,
    required String token,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );

  /// يُرسل الموقع الحالي ويُعيد النتيجة للمزامنة.
  Future<SyncOutcome> sendLocation(FieldLocation location) async {
    try {
      final response = await dio.post('/api/field/locations', data: location.toJson());
      final data = response.data;
      final Map<String, dynamic> payload = data is Map<String, dynamic> ? data : <String, dynamic>{};
      return SyncOutcome.ok(
        (payload['message'] as String?) ?? 'تم نشر الموقع',
        reportId: (payload['reportId'] as String?) ?? (payload['draftId'] as String?),
        serial: (payload['serial'] as String?),
      );
    } on DioException {
      return SyncOutcome.fail('تعذر نشر الموقع حالياً');
    } catch (_) {
      return SyncOutcome.fail('تعذر نشر الموقع حالياً');
    }
  }
}
