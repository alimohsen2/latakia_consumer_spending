import 'package:geolocator/geolocator.dart';

import '../models.dart';

/// خدمة تتبع الموقع أثناء الجولة الميدانية.
class FieldLocationService {
  /// التحقق من تفعيل خدمة تحديد المواقع.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// طلب صلاحية تحديد المواقع (الموبايل).
  Future<FieldLocation?> currentLocation({
    required String inspectorId,
    String inspectorName = '',
    String division = 'field',
    String taxpayerId = '',
    String taxpayerName = '',
    String taxNo = '',
    String address = '',
  }) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('خدمة تحديد المواقع غير مفعلة');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw Exception('صلاحية تحديد المواقع غير ممنوحة');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    );
    return FieldLocation(
      inspectorId: inspectorId,
      inspectorName: inspectorName,
      division: division,
      taxpayerId: taxpayerId,
      taxpayerName: taxpayerName,
      taxNo: taxNo,
      address: address,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      locationLabel: position.isMocked ? 'موقع تجريبي' : 'الموقع الحالي',
      timestamp: position.timestamp,
    );
  }
}
