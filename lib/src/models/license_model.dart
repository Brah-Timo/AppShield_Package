// lib/src/models/license_model.dart

import 'dart:convert';

enum LicenseType {
  perpetual,
  subscription,
  trial,
  educational,
  enterprise,
  oem,
}

enum LicenseStatus {
  notActivated,
  active,
  trial,
  gracePeriod,
  expired,
  revoked,
  suspended,
  tampered,
  deviceMismatch,
  offline,
}

class License {
  const License({
    required this.key,
    required this.type,
    required this.status,
    required this.deviceId,
    required this.appId,
    required this.plan,
    required this.activatedAt,
    required this.expiresAt,
    required this.features,
    required this.limits,
    required this.signature,
    this.lastValidatedAt,
    this.customerEmail,
    this.customerName,
    this.revokeReason,
    this.metadata = const {},
  });

  final String        key;
  final LicenseType   type;
  final LicenseStatus status;
  final String        deviceId;
  final String        appId;
  final String        plan;
  final DateTime      activatedAt;
  final DateTime      expiresAt;
  final Map<String, bool>        features;
  final Map<String, int>         limits;
  final String        signature;
  final DateTime?     lastValidatedAt;
  final String?       customerEmail;
  final String?       customerName;
  final String?       revokeReason;
  final Map<String, dynamic>     metadata;

  // ── Computed ──────────────────────────────────────────────────────────────

  bool get isValid =>
      (status == LicenseStatus.active ||
          status == LicenseStatus.gracePeriod) &&
      DateTime.now().isBefore(expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isExpiringSoon {
    final d = daysRemaining;
    return d >= 0 && d <= 7;
  }

  bool get isTrial =>
      type == LicenseType.trial || status == LicenseStatus.trial;

  bool get isPerpetual => type == LicenseType.perpetual;

  int get daysRemaining =>
      expiresAt.difference(DateTime.now()).inDays;

  int get hoursRemaining =>
      expiresAt.difference(DateTime.now()).inHours;

  bool hasFeature(String feature) => features[feature] ?? false;

  int getLimit(String key, {int defaultValue = 0}) =>
      limits[key] ?? defaultValue;

  // ── copyWith ──────────────────────────────────────────────────────────────

  License copyWith({
    String?        key,
    LicenseType?   type,
    LicenseStatus? status,
    String?        deviceId,
    String?        appId,
    String?        plan,
    DateTime?      activatedAt,
    DateTime?      expiresAt,
    Map<String, bool>?   features,
    Map<String, int>?    limits,
    String?        signature,
    DateTime?      lastValidatedAt,
    String?        customerEmail,
    String?        customerName,
    String?        revokeReason,
    Map<String, dynamic>? metadata,
  }) =>
      License(
        key:             key             ?? this.key,
        type:            type            ?? this.type,
        status:          status          ?? this.status,
        deviceId:        deviceId        ?? this.deviceId,
        appId:           appId           ?? this.appId,
        plan:            plan            ?? this.plan,
        activatedAt:     activatedAt     ?? this.activatedAt,
        expiresAt:       expiresAt       ?? this.expiresAt,
        features:        features        ?? this.features,
        limits:          limits          ?? this.limits,
        signature:       signature       ?? this.signature,
        lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
        customerEmail:   customerEmail   ?? this.customerEmail,
        customerName:    customerName    ?? this.customerName,
        revokeReason:    revokeReason    ?? this.revokeReason,
        metadata:        metadata        ?? this.metadata,
      );

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'key':               key,
        'type':              type.name,
        'status':            status.name,
        'device_id':         deviceId,
        'app_id':            appId,
        'plan':              plan,
        'activated_at':      activatedAt.toIso8601String(),
        'expires_at':        expiresAt.toIso8601String(),
        'features':          features,
        'limits':            limits,
        'signature':         signature,
        'last_validated_at': lastValidatedAt?.toIso8601String(),
        'customer_email':    customerEmail,
        'customer_name':     customerName,
        'revoke_reason':     revokeReason,
        'metadata':          metadata,
      };

  factory License.fromJson(Map<String, dynamic> json) => License(
        key:         json['key']    as String,
        type:        LicenseType.values.byName(json['type'] as String),
        status:      LicenseStatus.values.byName(json['status'] as String),
        deviceId:    json['device_id'] as String,
        appId:       json['app_id']    as String,
        plan:        json['plan']      as String,
        activatedAt: DateTime.parse(json['activated_at'] as String),
        expiresAt:   DateTime.parse(json['expires_at']   as String),
        features:    Map<String, bool>.from(json['features'] as Map),
        limits: (json['limits'] as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        signature:       json['signature'] as String,
        lastValidatedAt: json['last_validated_at'] != null
            ? DateTime.parse(json['last_validated_at'] as String)
            : null,
        customerEmail: json['customer_email'] as String?,
        customerName:  json['customer_name']  as String?,
        revokeReason:  json['revoke_reason']  as String?,
        metadata:      json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : {},
      );

  String toJsonString() => jsonEncode(toJson());

  factory License.fromJsonString(String raw) =>
      License.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  @override
  String toString() =>
      'License(key: ${key.length >= 4 ? key.substring(0, 4) : key}****, '
      'plan: $plan, status: $status, expires: $expiresAt)';
}
