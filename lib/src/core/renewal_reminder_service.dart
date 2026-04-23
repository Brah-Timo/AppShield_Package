// lib/src/core/renewal_reminder_service.dart
//
// Batch 14 – Renewal Reminder Service.
// Fires callbacks when a license is approaching expiry,
// giving the app a chance to prompt the user to renew.

import 'dart:async';

import '../models/license_model.dart';
import '../utils/logger.dart';

/// Severity of a renewal reminder.
enum RenewalReminderSeverity {
  /// Expiry is more than 14 days away — informational.
  notice,

  /// Expiry is within 7–14 days — user should plan to renew.
  warning,

  /// Expiry is within 3 days — urgent action required.
  urgent,

  /// License has already expired.
  expired,
}

/// A renewal reminder event.
class RenewalReminder {
  const RenewalReminder({
    required this.severity,
    required this.daysRemaining,
    required this.license,
    required this.timestamp,
  });

  final RenewalReminderSeverity severity;
  final int                     daysRemaining;
  final License                 license;
  final DateTime                timestamp;

  /// Human-friendly headline for this reminder.
  String get headline {
    switch (severity) {
      case RenewalReminderSeverity.notice:
        return 'License expires in $daysRemaining days';
      case RenewalReminderSeverity.warning:
        return '⚠ License expires soon — $daysRemaining days left';
      case RenewalReminderSeverity.urgent:
        return '🚨 License expires in $daysRemaining day${daysRemaining == 1 ? "" : "s"}!';
      case RenewalReminderSeverity.expired:
        return '❌ License has expired';
    }
  }

  @override
  String toString() =>
      'RenewalReminder(${severity.name}, $daysRemaining days, '
      'plan: ${license.plan})';
}

/// Monitors license expiry and emits [RenewalReminder] events.
///
/// ```dart
/// final svc = RenewalReminderService.instance;
/// svc.startMonitoring(
///   licenseProvider: () => AppShield.instance.currentLicense,
///   onReminder: (reminder) => showRenewalBanner(reminder),
/// );
/// ```
class RenewalReminderService {
  RenewalReminderService._();

  static final RenewalReminderService _instance =
      RenewalReminderService._();
  static RenewalReminderService get instance => _instance;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Days thresholds for each severity level.
  static const int _urgentDays  = 3;
  static const int _warningDays = 7;
  static const int _noticeDays  = 14;

  // ── State ─────────────────────────────────────────────────────────────────

  Timer?                      _timer;
  RenewalReminderSeverity?    _lastEmitted;
  bool                        get isRunning => _timer != null;

  // ── Stream ────────────────────────────────────────────────────────────────

  final _controller =
      StreamController<RenewalReminder>.broadcast();

  /// Stream of [RenewalReminder] events.
  Stream<RenewalReminder> get reminderStream => _controller.stream;

  // ── Start / stop ──────────────────────────────────────────────────────────

  /// Starts monitoring using [licenseProvider] to get the current license.
  ///
  /// [checkInterval] defaults to 6 hours.
  void startMonitoring({
    required License? Function()  licenseProvider,
    void Function(RenewalReminder)? onReminder,
    Duration checkInterval = const Duration(hours: 6),
  }) {
    stopMonitoring();
    AppShieldLogger.i(
        'RenewalReminderService: started (interval=${checkInterval.inHours}h).');

    // Check immediately, then on schedule.
    _check(licenseProvider, onReminder);
    _timer = Timer.periodic(checkInterval, (_) {
      _check(licenseProvider, onReminder);
    });
  }

  /// Stops monitoring.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _lastEmitted = null;
    AppShieldLogger.d('RenewalReminderService: stopped.');
  }

  // ── Core check ────────────────────────────────────────────────────────────

  void _check(
    License? Function()               licenseProvider,
    void Function(RenewalReminder)?   onReminder,
  ) {
    final license = licenseProvider();
    if (license == null || license.isPerpetual) return;

    final days     = license.daysRemaining;
    final severity = _severityFor(days);
    if (severity == null) return;          // No reminder needed yet

    // Avoid emitting the same severity repeatedly; escalate only.
    if (_lastEmitted == severity) return;
    _lastEmitted = severity;

    final reminder = RenewalReminder(
      severity:      severity,
      daysRemaining: days,
      license:       license,
      timestamp:     DateTime.now(),
    );

    AppShieldLogger.i(
        'RenewalReminderService: ${reminder.headline}');

    _controller.add(reminder);
    onReminder?.call(reminder);
  }

  RenewalReminderSeverity? _severityFor(int days) {
    if (days <= 0)            return RenewalReminderSeverity.expired;
    if (days <= _urgentDays)  return RenewalReminderSeverity.urgent;
    if (days <= _warningDays) return RenewalReminderSeverity.warning;
    if (days <= _noticeDays)  return RenewalReminderSeverity.notice;
    return null;
  }

  // ── Manual trigger ────────────────────────────────────────────────────────

  /// Manually evaluates the license and emits a reminder if appropriate.
  void checkNow(License? license) {
    if (license == null) return;
    _check(() => license, null);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    stopMonitoring();
    _controller.close();
  }
}
