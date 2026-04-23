// lib/src/core/license_analytics.dart
//
// Batch 12 – Advanced: Lightweight analytics aggregator.
// Tracks license usage metrics without sending data externally
// unless telemetry is explicitly enabled.

import 'dart:convert';
import '../services/storage_service.dart';
import '../models/license_model.dart';
import '../utils/logger.dart';

/// A single usage metric snapshot.
class LicenseMetric {
  const LicenseMetric({
    required this.event,
    required this.timestamp,
    this.plan,
    this.extra = const {},
  });

  final String               event;
  final DateTime             timestamp;
  final String?              plan;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
        'event':     event,
        'timestamp': timestamp.toIso8601String(),
        if (plan != null) 'plan': plan,
        if (extra.isNotEmpty) 'extra': extra,
      };

  factory LicenseMetric.fromJson(Map<String, dynamic> j) => LicenseMetric(
        event:     j['event']     as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        plan:      j['plan']      as String?,
        extra:     j['extra'] != null
            ? Map<String, dynamic>.from(j['extra'] as Map)
            : const {},
      );
}

/// Aggregated license usage report.
class LicenseUsageReport {
  const LicenseUsageReport({
    required this.appId,
    required this.generatedAt,
    required this.totalEvents,
    required this.activations,
    required this.validations,
    required this.deactivations,
    required this.tamperAttempts,
    required this.featureUsage,
    required this.sessionCount,
    this.currentPlan,
    this.licenseStatus,
  });

  final String                appId;
  final DateTime              generatedAt;
  final int                   totalEvents;
  final int                   activations;
  final int                   validations;
  final int                   deactivations;
  final int                   tamperAttempts;
  final Map<String, int>      featureUsage;
  final int                   sessionCount;
  final String?               currentPlan;
  final LicenseStatus?        licenseStatus;

  Map<String, dynamic> toJson() => {
        'app_id':        appId,
        'generated_at':  generatedAt.toIso8601String(),
        'total_events':  totalEvents,
        'activations':   activations,
        'validations':   validations,
        'deactivations': deactivations,
        'tamper_attempts': tamperAttempts,
        'feature_usage': featureUsage,
        'session_count': sessionCount,
        if (currentPlan  != null) 'current_plan':   currentPlan,
        if (licenseStatus != null) 'license_status': licenseStatus!.name,
      };

  @override
  String toString() =>
      'LicenseUsageReport(plan: $currentPlan, '
      'activations: $activations, sessions: $sessionCount)';
}

/// Collects and aggregates in-app license analytics.
///
/// All data is stored locally. Nothing is sent externally unless
/// your [SyncService] is configured to push telemetry.
///
/// ```dart
/// // Track feature usage
/// LicenseAnalytics.instance.trackFeatureAccess('advanced_reports');
///
/// // Get a full report
/// final report = await LicenseAnalytics.instance.generateReport('com.myapp');
/// ```
class LicenseAnalytics {
  LicenseAnalytics._();
  static final LicenseAnalytics instance = LicenseAnalytics._();

  static const String _storageKey   = 'as_analytics_metrics';
  static const int    _maxMetrics   = 500;

  // ── Track events ──────────────────────────────────────────────────────────

  /// Records a generic analytics event.
  Future<void> track(String event, {String? plan, Map<String, dynamic> extra = const {}}) async {
    final metric = LicenseMetric(
      event:     event,
      timestamp: DateTime.now().toUtc(),
      plan:      plan,
      extra:     extra,
    );
    await _append(metric);
    AppShieldLogger.d('Analytics: $event');
  }

  Future<void> trackActivation(String plan)   => track('activation',   plan: plan);
  Future<void> trackDeactivation()            => track('deactivation');
  Future<void> trackValidation(String plan)   => track('validation',   plan: plan);
  Future<void> trackTrialStart(int days)      => track('trial_start',  extra: {'days': days});
  Future<void> trackTrialExpiry()             => track('trial_expired');
  Future<void> trackExpiry()                  => track('expiry');
  Future<void> trackTamperAttempt(String type)=> track('tamper', extra: {'type': type});
  Future<void> trackSessionStart()            => track('session_start');

  /// Tracks that a licensed feature was accessed.
  Future<void> trackFeatureAccess(String featureKey) =>
      track('feature_access', extra: {'feature': featureKey});

  // ── Report ────────────────────────────────────────────────────────────────

  /// Generates an aggregated [LicenseUsageReport] from stored metrics.
  Future<LicenseUsageReport> generateReport(
    String appId, {
    License?      license,
    LicenseStatus? licenseStatus,
  }) async {
    final metrics = await _readAll();

    int activations   = 0;
    int validations   = 0;
    int deactivations = 0;
    int tamperAttempts = 0;
    int sessionCount  = 0;
    final featureUsage = <String, int>{};

    for (final m in metrics) {
      switch (m.event) {
        case 'activation':    activations++;    break;
        case 'validation':    validations++;    break;
        case 'deactivation':  deactivations++;  break;
        case 'tamper':        tamperAttempts++; break;
        case 'session_start': sessionCount++;   break;
        case 'feature_access':
          final f = m.extra['feature'] as String? ?? 'unknown';
          featureUsage[f] = (featureUsage[f] ?? 0) + 1;
          break;
      }
    }

    return LicenseUsageReport(
      appId:         appId,
      generatedAt:   DateTime.now().toUtc(),
      totalEvents:   metrics.length,
      activations:   activations,
      validations:   validations,
      deactivations: deactivations,
      tamperAttempts: tamperAttempts,
      featureUsage:  featureUsage,
      sessionCount:  sessionCount,
      currentPlan:   license?.plan,
      licenseStatus: licenseStatus,
    );
  }

  /// Returns raw metrics, newest first.
  Future<List<LicenseMetric>> getMetrics({int limit = 100}) async {
    final all = await _readAll();
    return all.reversed.take(limit).toList();
  }

  /// Clears all stored analytics data.
  Future<void> clearAll() async {
    await StorageService.instance.writeSecure(_storageKey, '[]');
    AppShieldLogger.d('Analytics cleared.');
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _append(LicenseMetric metric) async {
    final existing = await _readAll();
    existing.add(metric);
    // Keep only the last _maxMetrics entries
    final trimmed = existing.length > _maxMetrics
        ? existing.sublist(existing.length - _maxMetrics)
        : existing;
    final raw = jsonEncode(trimmed.map((m) => m.toJson()).toList());
    await StorageService.instance.writeSecure(_storageKey, raw);
  }

  Future<List<LicenseMetric>> _readAll() async {
    final raw = await StorageService.instance.readSecure(_storageKey);
    if (raw == null || raw.isEmpty || raw == 'null') return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => LicenseMetric.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppShieldLogger.w('Analytics: failed to parse stored metrics', error: e);
      return [];
    }
  }
}
