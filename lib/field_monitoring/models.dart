/// موقع تتبع أثناء جولة المراقب الميداني.
class FieldLocation {
  final String inspectorId;
  final String inspectorName;
  final String division;
  final String taxpayerId;
  final String taxpayerName;
  final String taxNo;
  final String address;
  final double lat;
  final double lng;
  final double accuracy;
  final String locationLabel;
  final DateTime timestamp;

  const FieldLocation({
    required this.inspectorId,
    required this.inspectorName,
    required this.division,
    required this.taxpayerId,
    required this.taxpayerName,
    required this.taxNo,
    required this.address,
    required this.lat,
    required this.lng,
    required this.accuracy,
    this.locationLabel = '',
    required this.timestamp,
  });

  factory FieldLocation.fromJson(Map<String, dynamic> j) {
    double numOr(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    return FieldLocation(
      inspectorId: (j['inspectorId'] as String?) ?? '',
      inspectorName: (j['inspectorName'] as String?) ?? '',
      division: (j['division'] as String?) ?? '',
      taxpayerId: (j['taxpayerId'] as String?) ?? '',
      taxpayerName: (j['taxpayerName'] as String?) ?? '',
      taxNo: (j['taxNo'] as String?) ?? '',
      address: (j['address'] as String?) ?? '',
      lat: numOr('lat', 0),
      lng: numOr('lng', 0),
      accuracy: numOr('accuracy', 0),
      locationLabel: (j['location'] as String?) ?? (j['locationLabel'] as String?) ?? '',
      timestamp: DateTime.tryParse((j['timestamp'] as String?) ?? (j['time'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'inspectorId': inspectorId,
        'inspectorName': inspectorName,
        'division': division,
        'taxpayerId': taxpayerId,
        'taxpayerName': taxpayerName,
        'taxNo': taxNo,
        'address': address,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'location': locationLabel,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// نتيجة إرسال موقع التتبع إلى الخادم.
class FieldLocationSendResult {
  final bool ok;
  final String message;
  final String? reportId;
  final String? serial;

  FieldLocationSendResult.ok(this.message, {this.reportId, this.serial})
      : ok = true;

  FieldLocationSendResult.fail(this.message, {this.reportId, this.serial})
      : ok = false;
}
