// lib/src/services/notification_service.dart

import '../core/license_manager.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Types of AppShield notifications.
enum AppShieldNotificationType {
  expiryWarning,       // License expiring within X days
  trialEnding,         // Trial ending soon
  offlineWarning,      // Cannot reach server, grace period started
  gracePeriodEnding,   // Grace period about to end
  tamperDetected,      // Tampering was detected
  licenseRevoked,      // License revoked by server
  updateAvailable,     // New version available
  renewalSuccess,      // License renewed successfully
}

/// A single notification item.
class AppShieldNotification {
  const AppShieldNotification({
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.actionLabel,
    this.actionCallback,
    this.severity = NotificationSeverity.info,
  });

  final AppShieldNotificationType type;
  final String  title;
  final String  message;
  final DateTime timestamp;
  final String?  actionLabel;
  final void Function()? actionCallback;
  final NotificationSeverity severity;
}

enum NotificationSeverity { info, warning, error, success }

typedef NotificationCallback = void Function(AppShieldNotification notification);

/// Generates and dispatches in-app notifications based on license state.
///
/// Consumers register via [addListener] and receive [AppShieldNotification]
/// objects whenever a relevant event occurs.
class NotificationService {
  NotificationService._();

  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final List<NotificationCallback> _listeners = [];

  // ── Listener management ───────────────────────────────────────────────────

  void addListener(NotificationCallback cb)    => _listeners.add(cb);
  void removeListener(NotificationCallback cb) => _listeners.remove(cb);
  void clearListeners()                         => _listeners.clear();

  // ── Check & emit ─────────────────────────────────────────────────────────

  /// Checks current license state and emits relevant notifications.
  Future<void> checkAndNotify() async {
    final license = LicenseManager.instance.currentLicense;
    if (license == null) return;

    final now = DateTime.now().toUtc();

    // Expiry warning
    if (license.isExpiringSoon && !license.isPerpetual) {
      _emit(AppShieldNotification(
        type:        AppShieldNotificationType.expiryWarning,
        title:       'License Expiring Soon',
        message:     'Your license expires in ${license.daysRemaining} day(s). '
                     'Please renew to avoid interruption.',
        timestamp:   now,
        actionLabel: 'Renew Now',
        severity:    NotificationSeverity.warning,
      ));
    }

    // Grace period
    if (license.status.name == 'gracePeriod') {
      _emit(AppShieldNotification(
        type:        AppShieldNotificationType.gracePeriodEnding,
        title:       'Grace Period Active',
        message:     'Your license has expired. You have '
                     '${AppShieldConstants.defaultOfflineGraceDays} day(s) '
                     'to renew before access is blocked.',
        timestamp:   now,
        actionLabel: 'Renew Now',
        severity:    NotificationSeverity.error,
      ));
    }

    // Revoked
    if (license.status.name == 'revoked') {
      _emit(AppShieldNotification(
        type:        AppShieldNotificationType.licenseRevoked,
        title:       'License Revoked',
        message:     license.revokeReason ??
                     'Your license has been revoked. Please contact support.',
        timestamp:   now,
        actionLabel: 'Contact Support',
        severity:    NotificationSeverity.error,
      ));
    }
  }

  /// Emits a trial-ending notification.
  void notifyTrialEnding(int daysLeft) {
    _emit(AppShieldNotification(
      type:        AppShieldNotificationType.trialEnding,
      title:       'Trial Ending Soon',
      message:     'Your trial period ends in $daysLeft day(s). '
                   'Purchase a license to continue.',
      timestamp:   DateTime.now().toUtc(),
      actionLabel: 'Buy License',
      severity:    NotificationSeverity.warning,
    ));
  }

  /// Emits an offline / no-server notification.
  void notifyOffline() {
    _emit(AppShieldNotification(
      type:      AppShieldNotificationType.offlineWarning,
      title:     'Cannot Reach License Server',
      message:   'Operating in offline mode. Please connect to the internet '
                 'within ${AppShieldConstants.defaultOfflineGraceDays} days.',
      timestamp: DateTime.now().toUtc(),
      severity:  NotificationSeverity.warning,
    ));
  }

  /// Emits a tamper-detected notification.
  void notifyTamperDetected(String tamperType) {
    _emit(AppShieldNotification(
      type:      AppShieldNotificationType.tamperDetected,
      title:     'Security Alert',
      message:   'A security issue was detected ($tamperType). '
                 'Please contact support if this is unexpected.',
      timestamp: DateTime.now().toUtc(),
      severity:  NotificationSeverity.error,
    ));
  }

  /// Emits an update-available notification.
  void notifyUpdateAvailable(String version) {
    _emit(AppShieldNotification(
      type:        AppShieldNotificationType.updateAvailable,
      title:       'Update Available',
      message:     'Version $version is available. Update for the latest '
                   'features and security improvements.',
      timestamp:   DateTime.now().toUtc(),
      actionLabel: 'Update Now',
      severity:    NotificationSeverity.info,
    ));
  }

  /// Emits a renewal-success notification.
  void notifyRenewalSuccess() {
    _emit(AppShieldNotification(
      type:      AppShieldNotificationType.renewalSuccess,
      title:     'License Renewed',
      message:   'Your license has been renewed successfully. Thank you!',
      timestamp: DateTime.now().toUtc(),
      severity:  NotificationSeverity.success,
    ));
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  void _emit(AppShieldNotification notification) {
    AppShieldLogger.i('Notification: ${notification.title}');
    for (final cb in List.of(_listeners)) {
      try {
        cb(notification);
      } catch (e) {
        AppShieldLogger.w('Notification listener threw: $e');
      }
    }
  }
}
