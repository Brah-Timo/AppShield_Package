// lib/src/core/license_health_monitor.dart
//
// Batch 12 – Advanced: Real-time license health monitoring.
// Continuously tracks license health metrics and alerts on anomalies.

import 'dart:async';
import '../models/license_model.dart';
import '../utils/logger.dart';

/// Severity level of a health alert.
enum HealthAlertSeverity { info, warning, critical }

/// A single health alert emitted by [LicenseHealthMonitor].
class HealthAlert {
  const HealthAlert({
    required this.code,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.details,
  });

  final String              code;
  final String              message;
  final HealthAlertSeverity severity;
  final DateTime            timestamp;
  final Map<String, dynamic>? details;

  @override
  String toString() =>
      'HealthAlert[${severity.name}] $code: $message';
}

/// Overall health status of the license subsystem.
enum LicenseHealthStatus { healthy, degraded, critical, unknown }

/// Snapshot of the current license health.
class LicenseHealthSnapshot {
  const LicenseHealthSnapshot({
    required this.status,
    required this.capturedAt,
    required this.alerts,
    this.license,
    this.daysRemaining,
    this.lastValidatedAt,
    this.isOnline,
  });

  final LicenseHealthStatus status;
  final DateTime            capturedAt;
  final List<HealthAlert>   alerts;
  final License?            license;
  final int?                daysRemaining;
  final DateTime?           lastValidatedAt;
  final bool?               isOnline;

  bool get hasAlerts  => alerts.isNotEmpty;
  bool get isCritical => status == LicenseHealthStatus.critical;

  @override
  String toString() =>
      'LicenseHealthSnapshot(${status.name}, alerts=${alerts.length}, '
      'daysLeft=${daysRemaining ?? "n/a"})';
}

/// Monitors license health and broadcasts [HealthAlert]s.
///
/// ```dart
/// final monitor = LicenseHealthMonitor.instance;
/// monitor.startMonitoring(checkIntervalSeconds: 30);
///
/// monitor.alertStream.listen((alert) {
///   if (alert.severity == HealthAlertSeverity.critical) {
///     showCriticalDialog(alert.message);
///   }
/// });
///
/// final snapshot = await monitor.captureSnapshot();
/// print(snapshot.status); // LicenseHealthStatus.healthy
/// ```
class LicenseHealthMonitor {
  LicenseHealthMonitor._();
  static final LicenseHealthMonitor instance = LicenseHealthMonitor._();

  Timer? _monitorTimer;
  bool   _isRunning = false;

  final _alertController =
      StreamController<HealthAlert>.broadcast();
  final _snapshotController =
      StreamController<LicenseHealthSnapshot>.broadcast();

  Stream<HealthAlert>          get alertStream    => _alertController.stream;
  Stream<LicenseHealthSnapshot> get snapshotStream => _snapshotController.stream;

  bool get isRunning => _isRunning;

  // ── Start / stop ──────────────────────────────────────────────────────────

  void startMonitoring({
    required License?  Function()       licenseProvider,
    required DateTime? Function()       lastValidationProvider,
    required bool      Function()       isOnlineProvider,
    int checkIntervalSeconds = 60,
  }) {
    if (_isRunning) return;
    _isRunning = true;
    AppShieldLogger.i(
      'LicenseHealthMonitor: started '
      '(interval=${checkIntervalSeconds}s)',
    );

    _monitorTimer = Timer.periodic(
      Duration(seconds: checkIntervalSeconds),
      (_) => _check(
        licenseProvider:        licenseProvider,
        lastValidationProvider: lastValidationProvider,
        isOnlineProvider:       isOnlineProvider,
      ),
    );
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
    _isRunning = false;
    AppShieldLogger.i('LicenseHealthMonitor: stopped.');
  }

  // ── Snapshot ──────────────────────────────────────────────────────────────

  LicenseHealthSnapshot captureSnapshot({
    License?  license,
    DateTime? lastValidatedAt,
    bool?     isOnline,
  }) {
    final alerts = <HealthAlert>[];
    var status  = LicenseHealthStatus.healthy;

    if (license == null) {
      alerts.add(HealthAlert(
        code:      'NO_LICENSE',
        message:   'No license is currently active.',
        severity:  HealthAlertSeverity.warning,
        timestamp: DateTime.now().toUtc(),
      ));
      status = LicenseHealthStatus.degraded;
    } else {
      // Expiry check
      final days = license.daysRemaining;
      if (days < 0) {
        alerts.add(HealthAlert(
          code:      'LICENSE_EXPIRED',
          message:   'License has expired.',
          severity:  HealthAlertSeverity.critical,
          timestamp: DateTime.now().toUtc(),
          details:   {'days_overdue': days.abs()},
        ));
        status = LicenseHealthStatus.critical;
      } else if (days <= 7) {
        alerts.add(HealthAlert(
          code:      'EXPIRY_IMMINENT',
          message:   'License expires in $days day(s).',
          severity:  days <= 2
              ? HealthAlertSeverity.critical
              : HealthAlertSeverity.warning,
          timestamp: DateTime.now().toUtc(),
          details:   {'days_remaining': days},
        ));
        if (status == LicenseHealthStatus.healthy) {
          status = LicenseHealthStatus.degraded;
        }
      }

      // Revoked / suspended
      if (license.status == LicenseStatus.revoked) {
        alerts.add(HealthAlert(
          code:      'LICENSE_REVOKED',
          message:   'License has been revoked.',
          severity:  HealthAlertSeverity.critical,
          timestamp: DateTime.now().toUtc(),
        ));
        status = LicenseHealthStatus.critical;
      }
      if (license.status == LicenseStatus.suspended) {
        alerts.add(HealthAlert(
          code:      'LICENSE_SUSPENDED',
          message:   'License is currently suspended.',
          severity:  HealthAlertSeverity.critical,
          timestamp: DateTime.now().toUtc(),
        ));
        status = LicenseHealthStatus.critical;
      }
    }

    // Validation staleness
    if (lastValidatedAt != null) {
      final hoursSince =
          DateTime.now().toUtc().difference(lastValidatedAt).inHours;
      if (hoursSince > 48) {
        alerts.add(HealthAlert(
          code:      'VALIDATION_STALE',
          message:   'License has not been validated for ${hoursSince}h.',
          severity:  HealthAlertSeverity.warning,
          timestamp: DateTime.now().toUtc(),
          details:   {'hours_since_validation': hoursSince},
        ));
        if (status == LicenseHealthStatus.healthy) {
          status = LicenseHealthStatus.degraded;
        }
      }
    }

    // Offline
    if (isOnline == false) {
      alerts.add(HealthAlert(
        code:      'OFFLINE',
        message:   'Device is offline. License validation may be delayed.',
        severity:  HealthAlertSeverity.info,
        timestamp: DateTime.now().toUtc(),
      ));
    }

    final snapshot = LicenseHealthSnapshot(
      status:         status,
      capturedAt:     DateTime.now().toUtc(),
      alerts:         alerts,
      license:        license,
      daysRemaining:  license?.daysRemaining,
      lastValidatedAt: lastValidatedAt,
      isOnline:       isOnline,
    );

    _snapshotController.add(snapshot);
    for (final a in alerts) {
      _alertController.add(a);
    }
    AppShieldLogger.d('LicenseHealthMonitor: ${snapshot.status.name}, '
        '${alerts.length} alert(s).');
    return snapshot;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _check({
    required License?  Function()  licenseProvider,
    required DateTime? Function()  lastValidationProvider,
    required bool      Function()  isOnlineProvider,
  }) {
    captureSnapshot(
      license:        licenseProvider(),
      lastValidatedAt: lastValidationProvider(),
      isOnline:       isOnlineProvider(),
    );
  }

  void dispose() {
    stopMonitoring();
    _alertController.close();
    _snapshotController.close();
  }
}
