// lib/app_shield.dart

import 'package:package_info_plus/package_info_plus.dart';

import 'app_shield_config.dart';
import 'src/core/api_client.dart';
import 'src/core/clock_verifier.dart';
import 'src/core/device_fingerprint.dart';
import 'src/core/encryption_service.dart';
import 'src/core/license_analytics.dart';
import 'src/core/license_cache.dart';
import 'src/core/license_health_monitor.dart';
import 'src/core/license_manager.dart';
import 'src/core/webhook_service.dart';
import 'src/core/tamper_detector.dart';
import 'src/models/activation_result.dart';
import 'src/models/activity_log_entry.dart';
import 'src/models/license_model.dart';
import 'src/models/validation_response.dart';
import 'src/services/notification_service.dart';
import 'src/services/storage_service.dart';
import 'src/services/sync_service.dart';
import 'src/services/trial_service.dart';
import 'src/services/validation_service.dart';
import 'src/utils/constants.dart';
import 'src/utils/exceptions.dart';
import 'src/utils/logger.dart';

export 'app_shield_config.dart';
export 'src/core/api_client.dart';
export 'src/core/clock_verifier.dart';
export 'src/core/device_fingerprint.dart';
export 'src/core/encryption_service.dart';
export 'src/core/grace_period_policy.dart';
export 'src/core/license_analytics.dart';
export 'src/core/license_cache.dart';
export 'src/core/license_health_monitor.dart';
export 'src/core/license_manager.dart';
export 'src/core/license_pool_manager.dart';
export 'src/core/multi_tenant_manager.dart';
export 'src/core/tamper_detector.dart';
export 'src/core/webhook_service.dart';
export 'src/guards/app_shield_guard.dart';
export 'src/guards/feature_guard.dart';
export 'src/guards/route_guard.dart';
export 'src/providers/app_shield_provider.dart';
export 'src/models/activation_result.dart';
export 'src/models/activity_log_entry.dart';
export 'src/models/device_model.dart';
export 'src/models/feature_model.dart';
export 'src/models/license_model.dart';
export 'src/models/tamper_record.dart';
export 'src/models/validation_response.dart';
export 'src/services/notification_service.dart';
export 'src/services/storage_service.dart';
export 'src/services/sync_service.dart';
export 'src/services/trial_service.dart';
export 'src/services/validation_service.dart';
export 'src/ui/screens/activation_screen.dart';
export 'src/ui/screens/expired_screen.dart';
export 'src/ui/screens/license_info_screen.dart';
export 'src/ui/screens/offline_mode_screen.dart';
export 'src/ui/screens/tamper_detected_screen.dart';
export 'src/ui/screens/trial_screen.dart';
export 'src/ui/themes/app_shield_theme.dart';
export 'src/ui/themes/app_shield_colors.dart';
export 'src/ui/widgets/analytics_dashboard_widget.dart';
export 'src/ui/widgets/device_info_widget.dart';
export 'src/ui/widgets/expiry_badge.dart';
export 'src/ui/widgets/feature_list_widget.dart';
export 'src/ui/widgets/license_health_widget.dart';
export 'src/ui/widgets/license_input.dart';
export 'src/ui/widgets/seat_usage_widget.dart';
export 'src/ui/widgets/status_card.dart';
export 'src/ui/widgets/renewal_banner_widget.dart';
export 'src/ui/widgets/keyboard_shortcuts_widget.dart';
export 'src/ui/widgets/offline_retry_widget.dart';
export 'src/ui/widgets/license_progress_widget.dart';
export 'src/ui/widgets/license_summary_widget.dart';
export 'src/ui/widgets/license_notification_widget.dart';
export 'src/utils/constants.dart';
export 'src/utils/exceptions.dart';
export 'src/utils/helpers.dart';
export 'src/utils/logger.dart';
export 'src/core/license_export_service.dart';
export 'src/core/renewal_reminder_service.dart';

/// Entry point for the AppShield package.
///
/// Usage:
/// ```dart
/// await AppShield.initialize(config: AppShieldConfig(...));
/// ```
class AppShield {
  AppShield._();

  static AppShield? _instance;

  /// The singleton [AppShield] instance.
  /// Throws [AppShieldNotInitializedException] if [initialize] has not been called.
  static AppShield get instance {
    if (_instance == null) throw const AppShieldNotInitializedException();
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  late AppShieldConfig _config;

  // ── Expose inner services (read-only) ─────────────────────────────────────

  AppShieldConfig get config => _config;

  LicenseManager       get licenseManager       => LicenseManager.instance;
  NotificationService  get notificationService   => NotificationService.instance;

  // ── Convenience getters (delegates to LicenseManager) ────────────────────

  License?      get currentLicense   => LicenseManager.instance.currentLicense;
  bool          get isLicenseValid   => LicenseManager.instance.isLicenseValid;
  int           get daysRemaining    => LicenseManager.instance.daysRemaining;
  int           get trialDaysRemaining => LicenseManager.instance.trialDaysRemaining;
  LicenseStatus get licenseStatus    =>
      LicenseManager.instance.currentLicense?.status ?? LicenseStatus.notActivated;

  bool hasFeature(String feature) => LicenseManager.instance.hasFeature(feature);
  int  getLimit(String key, {int defaultValue = 0}) =>
      LicenseManager.instance.getLimit(key, defaultValue: defaultValue);

  // ── Initialize ────────────────────────────────────────────────────────────

  /// Initializes AppShield.  Must be called before [runApp].
  ///
  /// ```dart
  /// await AppShield.initialize(config: AppShieldConfig(...));
  /// ```
  static Future<AppShield> initialize({
    required AppShieldConfig config,
  }) async {
    config.validate();

    // Configure logger
    AppShieldLogger.setEnabled(config.enableLogging);

    AppShieldLogger.i('Initializing AppShield v${AppShieldConstants.packageVersion}…');

    // ── 1. Package info ───────────────────────────────────────────────────
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion  = '${packageInfo.version}+${packageInfo.buildNumber}';

    // ── 2. Device fingerprint ─────────────────────────────────────────────
    final deviceInfo = await DeviceFingerprintService.instance.getDeviceInfo();
    AppShieldLogger.i('Device ID: ${deviceInfo.fingerprint}');

    // ── 3. Storage passphrase ─────────────────────────────────────────────
    final passphrase = EncryptionService.instance.deriveStoragePassphrase(
      deviceId:  deviceInfo.fingerprint,
      appId:     config.appId,
      appSecret: config.appSecret,
    );

    // ── 4. Storage service ────────────────────────────────────────────────
    await StorageService.instance.initialize(passphrase: passphrase);

    // Save device ID for later use
    await StorageService.instance.saveDeviceId(deviceInfo.fingerprint);

    // ── 5. API client ─────────────────────────────────────────────────────
    final apiClient = ApiClient(
      baseUrl:    config.apiBaseUrl,
      apiKey:     config.apiKey,
      appId:      config.appId,
      appVersion: appVersion,
    );

    // ── 6. Validation service ─────────────────────────────────────────────
    final validationService = ValidationService(
      apiClient:    apiClient,
      publicKeyPem: config.publicKey,
    );

    // ── 7. Trial service ──────────────────────────────────────────────────
    final trialService = TrialService(
      apiClient: apiClient,
      trialDays: config.trialDays,
      appId:     config.appId,
    );

    // ── 8. Clock verifier ─────────────────────────────────────────────────
    final clockVerifier = ClockVerifier(apiBaseUrl: config.apiBaseUrl);

    // ── 9. Sync service ───────────────────────────────────────────────────
    SyncService(
      apiClient:       apiClient,
      appId:           config.appId,
      enableTelemetry: config.enableTelemetry,
    );

    // ── 10. License manager ───────────────────────────────────────────────
    await LicenseManager.instance.initialize(
      validationService:    validationService,
      trialService:         trialService,
      clockVerifier:        clockVerifier,
      offlineGraceDays:     config.offlineGraceDays,
      validationIntervalHr: config.validationIntervalHr,
    );

    // ── 11. Batch 12 – Advanced services ──────────────────────────────────

    // License cache
    if (config.enableLicenseCache) {
      final license = await StorageService.instance.readLicense();
      if (license != null) {
        LicenseCache.instance.put(license, ttlMinutes: config.cacheTTLMinutes);
      }
      AppShieldLogger.d('LicenseCache enabled (TTL=${config.cacheTTLMinutes}m).');
    }

    // Webhook service – register onLicenseEvent callback if provided
    if (config.onLicenseEvent != null) {
      WebhookService.instance.addHandler(config.onLicenseEvent!);
      AppShieldLogger.d('WebhookService: onLicenseEvent callback registered.');
    }

    // Analytics session start
    if (config.enableAnalytics) {
      await LicenseAnalytics.instance.trackSessionStart();
      AppShieldLogger.d('LicenseAnalytics: session started.');
    }

    // Health monitor
    if (config.enableHealthMonitor) {
      LicenseHealthMonitor.instance.startMonitoring(
        licenseProvider:        () => LicenseManager.instance.currentLicense,
        lastValidationProvider: () =>
            LicenseManager.instance.currentLicense?.lastValidatedAt,
        isOnlineProvider:       () => true,
        checkIntervalSeconds:
            AppShieldConstants.defaultHealthCheckIntervalSec,
      );
      AppShieldLogger.d('LicenseHealthMonitor started.');
    }

    _instance        = AppShield._();
    _instance!._config = config;

    AppShieldLogger.i('AppShield initialized successfully '
        '(v${AppShieldConstants.packageVersion}).');
    return _instance!;
  }

  // ── High-level API ────────────────────────────────────────────────────────

  /// Checks the current license status.
  Future<LicenseStatus> checkLicense() =>
      LicenseManager.instance.checkLicense();

  /// Activates a license key.
  Future<ActivationResult> activate(String licenseKey) =>
      LicenseManager.instance.activate(licenseKey);

  /// Deactivates the current license on this device.
  Future<bool> deactivate() => LicenseManager.instance.deactivate();

  /// Forces an immediate online validation.
  Future<ValidationResponse?> validateOnline() =>
      LicenseManager.instance.validateOnline();

  /// Restores a license to this device.
  Future<ActivationResult> restore({
    required String licenseKey,
    String? email,
    String? otpCode,
  }) =>
      LicenseManager.instance.restore(
        licenseKey: licenseKey,
        email:      email,
        otpCode:    otpCode,
      );

  /// Starts the trial period.
  Future<bool> startTrial({String? email}) =>
      LicenseManager.instance.startTrial(email: email);

  /// Returns all activity log entries.
  Future<List<ActivityLogEntry>> getActivityLog() =>
      StorageService.instance.readActivityLog();

  /// Resets AppShield (wipes all stored data). Use with caution.
  static Future<void> reset() async {
    await StorageService.instance.wipeAll();
    _instance = null;
    AppShieldLogger.w('AppShield reset — all data wiped.');
  }

  // ── Batch 12 – Advanced API ───────────────────────────────────────────────

  /// Registers a webhook event handler.
  /// Called for every [AppShieldEvent] dispatched by the package.
  void addWebhookHandler(AppShieldEventHandler handler) =>
      WebhookService.instance.addHandler(handler);

  /// Removes a previously registered webhook handler.
  void removeWebhookHandler(AppShieldEventHandler handler) =>
      WebhookService.instance.removeHandler(handler);

  /// Returns a stream of all [AppShieldEvent]s.
  Stream<AppShieldEvent> get eventStream =>
      WebhookService.instance.eventStream;

  /// The license-health alert stream.
  Stream<HealthAlert> get healthAlertStream =>
      LicenseHealthMonitor.instance.alertStream;

  /// The license-health snapshot stream.
  Stream<LicenseHealthSnapshot> get healthSnapshotStream =>
      LicenseHealthMonitor.instance.snapshotStream;

  /// Captures an immediate [LicenseHealthSnapshot].
  LicenseHealthSnapshot captureHealthSnapshot() =>
      LicenseHealthMonitor.instance.captureSnapshot(
        license:       currentLicense,
        lastValidatedAt: currentLicense?.lastValidatedAt,
      );

  /// Generates a [LicenseUsageReport] from stored analytics.
  Future<LicenseUsageReport> generateUsageReport() =>
      LicenseAnalytics.instance.generateReport(
        _config.appId,
        license:       currentLicense,
        licenseStatus: licenseStatus,
      );

  /// Returns recent analytics metrics (newest first).
  Future<List<LicenseMetric>> getAnalyticsMetrics({int limit = 50}) =>
      LicenseAnalytics.instance.getMetrics(limit: limit);

  /// Clears analytics data.
  Future<void> clearAnalytics() => LicenseAnalytics.instance.clearAll();

  /// The cached [License] from the in-memory cache (may be null if expired).
  License? get cachedLicense => LicenseCache.instance.current;

  /// Invalidates the in-memory license cache.
  void invalidateLicenseCache() => LicenseCache.instance.invalidate();

  /// Tracks that a feature was accessed (increments analytics counter).
  Future<void> trackFeatureAccess(String featureKey) =>
      LicenseAnalytics.instance.trackFeatureAccess(featureKey);

  // ── Stream ────────────────────────────────────────────────────────────────

  /// Stream of license status changes.
  Stream<LicenseStatus> get licenseStatusStream =>
      LicenseManager.instance.licenseStream;
}
