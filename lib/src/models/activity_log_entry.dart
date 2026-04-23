// lib/src/models/activity_log_entry.dart

import 'dart:convert';

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.action,
    required this.timestamp,
    this.details,
    this.deviceFingerprint,
    this.licenseKey,
  });

  final String   action;
  final DateTime timestamp;
  final String?  details;
  final String?  deviceFingerprint;
  final String?  licenseKey;

  Map<String, dynamic> toJson() => {
        'action':             action,
        'timestamp':          timestamp.toIso8601String(),
        'details':            details,
        'device_fingerprint': deviceFingerprint,
        'license_key':        licenseKey,
      };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      ActivityLogEntry(
        action:            json['action']             as String,
        timestamp:         DateTime.parse(json['timestamp'] as String),
        details:           json['details']            as String?,
        deviceFingerprint: json['device_fingerprint'] as String?,
        licenseKey:        json['license_key']        as String?,
      );

  static List<ActivityLogEntry> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<ActivityLogEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  @override
  String toString() =>
      'ActivityLogEntry(action: $action, at: $timestamp)';
}
