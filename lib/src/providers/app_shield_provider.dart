// lib/src/providers/app_shield_provider.dart
//
// Batch 12 – Advanced: ChangeNotifier-based provider for reactive UI.
// Integrates seamlessly with the Provider package.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../app_shield.dart';
import '../core/license_analytics.dart';
import '../core/license_health_monitor.dart';
import '../core/webhook_service.dart';
import '../models/license_model.dart';

/// ChangeNotifier that exposes AppShield state to the widget tree.
///
/// Setup:
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => AppShieldProvider()..initialize(),
///   child: MyApp(),
/// )
/// ```
///
/// Usage:
/// ```dart
/// final shield = context.watch<AppShieldProvider>();
/// if (shield.isLicenseValid) { ... }
/// ```
class AppShieldProvider extends ChangeNotifier {
  AppShieldProvider({
    this.enableHealthMonitor = true,
    this.enableAnalytics     = true,
    this.healthCheckInterval = const Duration(seconds: 60),
  });

  final bool     enableHealthMonitor;
  final bool     enableAnalytics;
  final Duration healthCheckInterval;

  // ── State ─────────────────────────────────────────────────────────────────

  LicenseStatus        _status         = LicenseStatus.notActivated;
  License?             _license;
  bool                 _isLoading      = false;
  bool                 _isActivating   = false;
  bool                 _isValidating   = false;
  String?              _lastError;
  LicenseHealthSnapshot? _healthSnapshot;
  LicenseUsageReport?  _usageReport;

  StreamSubscription<LicenseStatus>? _statusSub;
  StreamSubscription<AppShieldEvent>? _eventSub;
  bool _initialized = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  LicenseStatus          get status          => _status;
  License?               get license         => _license;
  bool                   get isLoading       => _isLoading;
  bool                   get isActivating    => _isActivating;
  bool                   get isValidating    => _isValidating;
  String?                get lastError       => _lastError;
  LicenseHealthSnapshot? get healthSnapshot  => _healthSnapshot;
  LicenseUsageReport?    get usageReport     => _usageReport;
  bool                   get isInitialized   => _initialized;

  bool get isLicenseValid =>
      _status == LicenseStatus.active ||
      _status == LicenseStatus.gracePeriod ||
      _status == LicenseStatus.trial;

  bool get isActive       => _status == LicenseStatus.active;
  bool get isTrial        => _status == LicenseStatus.trial;
  bool get isGracePeriod  => _status == LicenseStatus.gracePeriod;
  bool get isExpired      => _status == LicenseStatus.expired;
  bool get isRevoked      => _status == LicenseStatus.revoked;
  bool get isTampered     => _status == LicenseStatus.tampered;
  bool get isOffline      => _status == LicenseStatus.offline;
  bool get isNotActivated => _status == LicenseStatus.notActivated;

  int  get daysRemaining     => AppShield.instance.daysRemaining;
  int  get trialDaysRemaining => AppShield.instance.trialDaysRemaining;
  String? get currentPlan    => _license?.plan;
  String? get customerName   => _license?.customerName;
  String? get customerEmail  => _license?.customerEmail;

  bool hasFeature(String feature) => AppShield.instance.hasFeature(feature);
  int  getLimit(String key, {int defaultValue = 0}) =>
      AppShield.instance.getLimit(key, defaultValue: defaultValue);

  // ── Initialize ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _setLoading(true);
    try {
      _license = AppShield.instance.currentLicense;
      _status  = AppShield.instance.licenseStatus;

      // Subscribe to status stream
      _statusSub = AppShield.instance.licenseStatusStream.listen((s) {
        _status  = s;
        _license = AppShield.instance.currentLicense;
        notifyListeners();
      });

      // Subscribe to webhook events
      _eventSub = WebhookService.instance.eventStream.listen((event) {
        _onWebhookEvent(event);
      });

      // Run initial check
      _status = await AppShield.instance.checkLicense();
      _license = AppShield.instance.currentLicense;

      // Start health monitor
      if (enableHealthMonitor) {
        _startHealthMonitor();
      }

      // Track session start
      if (enableAnalytics) {
        await LicenseAnalytics.instance.trackSessionStart();
        await _refreshUsageReport();
      }

      _initialized = true;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Activates a license key.
  Future<ActivationResult> activate(String key) async {
    _isActivating = true;
    _lastError    = null;
    notifyListeners();
    try {
      final result = await AppShield.instance.activate(key);
      if (result.success) {
        _license = result.license;
        _status  = LicenseStatus.active;
        if (enableAnalytics) {
          await LicenseAnalytics.instance.trackActivation(_license?.plan ?? '');
          await _refreshUsageReport();
        }
        await WebhookService.instance.dispatchActivated(_license!);
      } else {
        _lastError = result.errorMessage;
      }
      return result;
    } catch (e) {
      _lastError = e.toString();
      return ActivationResult.failure(
        errorCode:    'PROVIDER_ERROR',
        errorMessage: e.toString(),
      );
    } finally {
      _isActivating = false;
      notifyListeners();
    }
  }

  /// Deactivates the current license.
  Future<bool> deactivate() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final ok = await AppShield.instance.deactivate();
      if (ok) {
        _license = null;
        _status  = LicenseStatus.notActivated;
        if (enableAnalytics) await LicenseAnalytics.instance.trackDeactivation();
        await WebhookService.instance.dispatchDeactivated();
      }
      return ok;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Forces an immediate online validation.
  Future<ValidationResponse?> validateOnline() async {
    _isValidating = true;
    _lastError    = null;
    notifyListeners();
    try {
      final response = await AppShield.instance.validateOnline();
      _license = AppShield.instance.currentLicense;
      _status  = AppShield.instance.licenseStatus;
      if (enableAnalytics) {
        await LicenseAnalytics.instance.trackValidation(_license?.plan ?? '');
        await _refreshUsageReport();
      }
      if (response != null && _license != null) {
        await WebhookService.instance.dispatchValidationSuccess(_license!);
      }
      return response;
    } catch (e) {
      _lastError = e.toString();
      if (enableAnalytics) {
        await WebhookService.instance.dispatchValidationFailed(e.toString());
      }
      return null;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  /// Starts the trial period.
  Future<bool> startTrial({String? email}) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final ok = await AppShield.instance.startTrial(email: email);
      if (ok) {
        _status = LicenseStatus.trial;
        if (enableAnalytics) {
          await LicenseAnalytics.instance
              .trackTrialStart(AppShield.instance.config.trialDays);
          await WebhookService.instance.dispatchTrialStarted(
            AppShield.instance.config.trialDays,
          );
        }
      }
      return ok;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restores a license.
  Future<ActivationResult> restore({
    required String licenseKey,
    String? email,
    String? otpCode,
  }) async {
    _isActivating = true;
    _lastError    = null;
    notifyListeners();
    try {
      final result = await AppShield.instance.restore(
        licenseKey: licenseKey,
        email:      email,
        otpCode:    otpCode,
      );
      if (result.success) {
        _license = result.license;
        _status  = LicenseStatus.active;
      } else {
        _lastError = result.errorMessage;
      }
      return result;
    } catch (e) {
      _lastError = e.toString();
      return ActivationResult.failure(
        errorCode:    'RESTORE_ERROR',
        errorMessage: e.toString(),
      );
    } finally {
      _isActivating = false;
      notifyListeners();
    }
  }

  /// Tracks feature access in analytics.
  Future<void> trackFeatureAccess(String featureKey) async {
    if (!enableAnalytics) return;
    await LicenseAnalytics.instance.trackFeatureAccess(featureKey);
  }

  /// Manually refreshes the usage report.
  Future<void> refreshUsageReport() async {
    if (!enableAnalytics) return;
    await _refreshUsageReport();
  }

  /// Clears the last error.
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ── Health monitor ────────────────────────────────────────────────────────

  void _startHealthMonitor() {
    LicenseHealthMonitor.instance.startMonitoring(
      licenseProvider:         () => _license,
      lastValidationProvider:  () => _license?.lastValidatedAt,
      isOnlineProvider:        () => true,
      checkIntervalSeconds:    healthCheckInterval.inSeconds,
    );

    LicenseHealthMonitor.instance.snapshotStream.listen((snapshot) {
      _healthSnapshot = snapshot;
      notifyListeners();
    });
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onWebhookEvent(AppShieldEvent event) {
    switch (event.type) {
      case AppShieldEventType.licenseRevoked:
        _status = LicenseStatus.revoked;
        notifyListeners();
        break;
      case AppShieldEventType.licenseExpired:
        _status = LicenseStatus.expired;
        notifyListeners();
        break;
      default:
        break;
    }
  }

  Future<void> _refreshUsageReport() async {
    if (!AppShield.isInitialized) return;
    _usageReport = await LicenseAnalytics.instance.generateReport(
      AppShield.instance.config.appId,
      license:       _license,
      licenseStatus: _status,
    );
    notifyListeners();
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _eventSub?.cancel();
    LicenseHealthMonitor.instance.stopMonitoring();
    super.dispose();
  }
}
