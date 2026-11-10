import 'package:dio/dio.dart';

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

  /// يُرسل الموقع الحالي إلى الخادم.
  Future<FieldLocationSendResult> sendLocation(FieldLocation location) async {
    try {
      final response =
          await dio.post('/api/field/locations', data: location.toJson());
      final data = response.data;
      final Map<String, dynamic> payload =
          data is Map<String, dynamic> ? data : <String, dynamic>{};
      return FieldLocationSendResult.ok(
        (payload['message'] as String?) ?? 'تم نشر الموقع',
        reportId: (payload['reportId'] as String?) ?? (payload['draftId'] as String?),
        serial: (payload['serial'] as String?),
      );
    } on DioException {
      return FieldLocationSendResult.fail('تعذر نشر الموقع حالياً');
    } catch (_) {
      return FieldLocationSendResult.fail('تعذر نشر الموقع حالياً');
    }
  }
}
