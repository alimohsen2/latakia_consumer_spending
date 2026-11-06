import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// مسودة محضر ينشئها المفتش الميداني دون اتصال، ثم تُزامَن مع النظام.
class FieldDraft {
  String id;
  String taxpayerId, taxpayerName, taxNo, address, profession;
  String serial, orderNo, orderDate;
  String servedName, servedCapacity, servedNationalNo;
  String inspectors, fieldHead;
  String location, lat, lng, notes;
  String inspectorName, division;
  List<Violation> items;
  List<Attachment> attachments;

  /// مسودة | جاهز للمزامنة | مزامَن | فشل
  String status;
  String lastError, serverReportId, createdAt, updatedAt, syncedAt;
  int attempts;

  FieldDraft({
    required this.id,
    this.taxpayerId = '',
    this.taxpayerName = '',
    this.taxNo = '',
    this.address = '',
    this.profession = '',
    this.serial = '',
    this.orderNo = '',
    this.orderDate = '',
    this.servedName = '',
    this.servedCapacity = '',
    this.servedNationalNo = '',
    this.inspectors = '',
    this.fieldHead = '',
    this.location = '',
    this.lat = '',
    this.lng = '',
    this.notes = '',
    this.inspectorName = '',
    this.division = 'field',
    List<Violation>? items,
    List<Attachment>? attachments,
    this.status = 'مسودة',
    this.lastError = '',
    this.serverReportId = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.syncedAt = '',
    this.attempts = 0,
  })  : items = items ?? [],
        attachments = attachments ?? [];

  bool get synced => status == 'مزامَن';
  bool get ready => status == 'جاهز للمزامنة';
  bool get failed => status == 'فشل';
  bool get draftOnly => status == 'مسودة';

  Map<String, dynamic> toJson() => {
        'id': id,
        'taxpayerId': taxpayerId,
        'taxpayerName': taxpayerName,
        'taxNo': taxNo,
        'address': address,
        'profession': profession,
        'serial': serial,
        'orderNo': orderNo,
        'orderDate': orderDate,
        'servedName': servedName,
        'servedCapacity': servedCapacity,
        'servedNationalNo': servedNationalNo,
        'inspectors': inspectors,
        'fieldHead': fieldHead,
        'location': location,
        'lat': lat,
        'lng': lng,
        'notes': notes,
        'inspectorName': inspectorName,
        'division': division,
        'items': items.map((e) => e.toJson()).toList(),
        'attachments': attachments.map((e) => e.toJson()).toList(),
        'status': status,
        'lastError': lastError,
        'serverReportId': serverReportId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'syncedAt': syncedAt,
        'attempts': attempts,
      };

  factory FieldDraft.fromJson(Map<String, dynamic> j) {
    String s(String k) => (j[k] as String?) ?? '';
    return FieldDraft(
      id: j['id'] as String,
      taxpayerId: s('taxpayerId'),
      taxpayerName: s('taxpayerName'),
      taxNo: s('taxNo'),
      address: s('address'),
      profession: s('profession'),
      serial: s('serial'),
      orderNo: s('orderNo'),
      orderDate: s('orderDate'),
      servedName: s('servedName'),
      servedCapacity: s('servedCapacity'),
      servedNationalNo: s('servedNationalNo'),
      inspectors: s('inspectors'),
      fieldHead: s('fieldHead'),
      location: s('location'),
      lat: s('lat'),
      lng: s('lng'),
      notes: s('notes'),
      inspectorName: s('inspectorName'),
      division: s('division').isEmpty ? 'field' : s('division'),
      items: ((j['items'] as List?) ?? []).map((e) => Violation.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      attachments: ((j['attachments'] as List?) ?? []).map((e) => Attachment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      status: s('status').isEmpty ? 'مسودة' : s('status'),
      lastError: s('lastError'),
      serverReportId: s('serverReportId'),
      createdAt: s('createdAt'),
      updatedAt: s('updatedAt'),
      syncedAt: s('syncedAt'),
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class SyncOutcome {
  final bool ok;
  final String message;
  final String? reportId;
  final String? serial;
  const SyncOutcome({required this.ok, required this.message, this.reportId, this.serial});
  const SyncOutcome.ok(this.message, {this.reportId, this.serial}) : ok = true;
  const SyncOutcome.fail(this.message)  : ok = false,
        reportId = null,
        serial = null;
}

/// ملف جاهز للإرسال مع المسودة (يُقرأ من AttachmentStore).
class FieldSyncFile {
  final String name, mime;
  final List<int> bytes;
  const FieldSyncFile({required this.name, required this.mime, required this.bytes});
}

abstract class FieldSyncTransport {
  Future<SyncOutcome> push(FieldDraft draft, {required List<FieldSyncFile> files});
}

/// مزامنة فعلية مع خلفية REST. تُستخدم عند ضبط «عنوان مزامنة الميدان» في
/// الإعدادات. البروتوكول موثّق في docs/FIELD_APP.md.
class HttpFieldSyncTransport implements FieldSyncTransport {
  final String baseUrl;
  final String token;
  final http.Client _client;

  HttpFieldSyncTransport(this.baseUrl, {this.token = '', http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<SyncOutcome> push(FieldDraft draft, {required List<FieldSyncFile> files}) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/field/sync');
    final payload = {
      ...draft.toJson(),
      'files': [
        for (final f in files)
          {'name': f.name, 'mime': f.mime, 'bytesBase64': base64Encode(f.bytes)},
      ],
    };
    try {
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        Map<String, dynamic> body = {};
        try {
          body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        } catch (_) {}
        final rid = body['reportId']?.toString() ?? body['id']?.toString();
        final serial = body['serial']?.toString();
        return SyncOutcome.ok(
          'تم استلام المحضر على الخادم${serial == null || serial.isEmpty ? '' : ' برقم $serial'}',
          reportId: rid,
          serial: serial,
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const SyncOutcome.fail('انتهت صلاحية الجلسة أو لا تملك صلاحية المزامنة');
      }
      return SyncOutcome.fail('رفض الخادم المزامنة (${res.statusCode})');
    } catch (e) {
      return SyncOutcome.fail('تعذر الاتصال بالخادم: $e');
    }
  }
}
