// lib/src/models/tamper_record.dart

import 'dart:convert';

class TamperRecord {
  const TamperRecord({
    required this.tamperType,
    required this.severity,
    required this.detectedAt,
    this.details,
    this.deviceFingerprint,
    this.licenseKey,
  });

  final String   tamperType;
  /// 'low' | 'medium' | 'high' | 'critical'
  final String   severity;
  final DateTime detectedAt;
  final String?  details;
  final String?  deviceFingerprint;
  final String?  licenseKey;

  Map<String, dynamic> toJson() => {
        'tamper_type':        tamperType,
        'severity':           severity,
        'detected_at':        detectedAt.toIso8601String(),
        'details':            details,
        'device_fingerprint': deviceFingerprint,
        'license_key':        licenseKey,
      };

  factory TamperRecord.fromJson(Map<String, dynamic> json) => TamperRecord(
        tamperType:        json['tamper_type']        as String,
        severity:          json['severity']           as String,
        detectedAt:        DateTime.parse(json['detected_at'] as String),
        details:           json['details']            as String?,
        deviceFingerprint: json['device_fingerprint'] as String?,
        licenseKey:        json['license_key']        as String?,
      );

  static List<TamperRecord> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => TamperRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<TamperRecord> records) =>
      jsonEncode(records.map((e) => e.toJson()).toList());

  @override
  String toString() =>
      'TamperRecord(type: $tamperType, severity: $severity, at: $detectedAt)';
}
