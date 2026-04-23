// lib/app_shield_config.dart

import 'package:flutter/material.dart';
import 'src/core/grace_period_policy.dart';
import 'src/ui/themes/app_shield_theme.dart';
import 'src/utils/constants.dart';

/// Complete configuration for the AppShield package.
///
/// Pass an instance to [AppShield.initialize] at app start.
class AppShieldConfig {
  const AppShieldConfig({
    required this.appId,
    required this.apiBaseUrl,
    required this.apiKey,
    this.appSecret       = 'default_app_secret_change_me',
    this.publicKey       = '',
    // ── Offline ──────────────────────────────────────
    this.enableOfflineMode   = true,
    this.offlineGraceDays    = AppShieldConstants.defaultOfflineGraceDays,
    // ── Trial ────────────────────────────────────────
    this.enableTrial     = true,
    this.trialDays       = AppShieldConstants.defaultTrialDays,
    // ── Device binding ───────────────────────────────
    this.enableDeviceBinding = true,
    this.maxDevicesPerLicense = AppShieldConstants.defaultMaxDevices,
    // ── Clock ────────────────────────────────────────
    this.enableClockCheck    = true,
    // ── Validation ───────────────────────────────────
    this.validationIntervalHr = AppShieldConstants.defaultValidationIntervalHr,
    // ── Subscription ─────────────────────────────────
    this.enableAutoRenewal   = false,
    this.buyLicenseUrl       = '',
    this.supportUrl          = '',
    // ── Telemetry ────────────────────────────────────
    this.enableTelemetry     = false,
    // ── Tamper detection ─────────────────────────────
    this.enableTamperDetection    = true,
    this.enableRootJailbreakCheck = true,
    this.enableEmulatorCheck      = false,
    this.enableDebuggerCheck      = false,
    // ── UI ───────────────────────────────────────────
    this.theme,
    // ── Logging ──────────────────────────────────────
    this.enableLogging = true,
    // ── Batch 12 – Advanced options ──────────────────
    this.gracePeriodPolicy,
    this.enableAnalytics       = false,
    this.enableHealthMonitor   = false,
    this.enableWebhooks        = false,
    this.enableLicenseCache    = true,
    this.cacheTTLMinutes       = AppShieldConstants.defaultCacheTTLMinutes,
    this.tenantId,
    this.enableMultiTenant     = false,
    this.enableSeatPooling     = false,
    this.totalSeats            = 0,
    this.enableBulkActivation  = false,
    this.enableLicenseTransfer = false,
    this.customHeaders         = const {},
    this.requestTimeoutSeconds = AppShieldConstants.defaultApiTimeoutSec,
    this.enableRetryOnFailure  = true,
    this.retryCount            = AppShieldConstants.defaultRetryCount,
    this.onLicenseEvent,
  });

  // ── Required ──────────────────────────────────────────────────────────────

  /// Unique identifier for your application (e.g. 'com.company.myapp').
  final String appId;

  /// Base URL of your License Server (e.g. 'https://license.mycompany.com/api').
  final String apiBaseUrl;

  /// API key for authenticating with your License Server.
  final String apiKey;

  /// Secret used to derive the local storage encryption key.
  /// Change this to a strong random string per application.
  final String appSecret;

  /// RSA-2048 public key (PEM) for verifying server-signed license tokens.
  /// Leave empty to skip signature verification (not recommended in production).
  final String publicKey;

  // ── Offline ───────────────────────────────────────────────────────────────

  final bool enableOfflineMode;

  /// Number of days the app can run without contacting the server.
  final int offlineGraceDays;

  // ── Trial ─────────────────────────────────────────────────────────────────

  final bool enableTrial;
  final int  trialDays;

  // ── Device binding ────────────────────────────────────────────────────────

  final bool enableDeviceBinding;
  final int  maxDevicesPerLicense;

  // ── Clock ─────────────────────────────────────────────────────────────────

  final bool enableClockCheck;

  // ── Validation ────────────────────────────────────────────────────────────

  /// How often (in hours) to perform an online validation check.
  final int validationIntervalHr;

  // ── Subscription ─────────────────────────────────────────────────────────

  final bool   enableAutoRenewal;

  /// URL opened when the user taps "Buy License".
  final String buyLicenseUrl;

  /// URL opened when the user taps "Support".
  final String supportUrl;

  // ── Telemetry ─────────────────────────────────────────────────────────────

  final bool enableTelemetry;

  // ── Tamper detection ──────────────────────────────────────────────────────

  final bool enableTamperDetection;
  final bool enableRootJailbreakCheck;
  final bool enableEmulatorCheck;
  final bool enableDebuggerCheck;

  // ── UI ────────────────────────────────────────────────────────────────────

  /// Optional UI theme.  Defaults to [AppShieldTheme.light()].
  final AppShieldTheme? theme;

  // ── Logging ───────────────────────────────────────────────────────────────

  final bool enableLogging;

  // ── Batch 12 – Advanced options ───────────────────────────────────────────

  /// Custom grace-period policy (overrides [offlineGraceDays] if provided).
  final GracePeriodPolicy? gracePeriodPolicy;

  /// Enable in-app license analytics tracking.
  final bool enableAnalytics;

  /// Enable the real-time license health monitor.
  final bool enableHealthMonitor;

  /// Enable the webhook/event dispatcher.
  final bool enableWebhooks;

  /// Cache license in-memory to reduce disk reads.
  final bool enableLicenseCache;

  /// In-memory cache TTL in minutes.
  final int cacheTTLMinutes;

  /// Tenant identifier for multi-tenant / white-label deployments.
  final String? tenantId;

  /// Enable multi-tenant mode.
  final bool enableMultiTenant;

  /// Enable seat-pool / concurrent-seat licensing.
  final bool enableSeatPooling;

  /// Total seats in the pool (used when [enableSeatPooling] is true).
  final int totalSeats;

  /// Allow bulk activation of multiple license keys at once.
  final bool enableBulkActivation;

  /// Allow license transfer between devices via the server.
  final bool enableLicenseTransfer;

  /// Additional HTTP headers appended to every API request.
  final Map<String, String> customHeaders;

  /// Individual request timeout in seconds (overrides default).
  final int requestTimeoutSeconds;

  /// Retry failed API calls automatically.
  final bool enableRetryOnFailure;

  /// Number of retry attempts on failure.
  final int retryCount;

  /// Callback invoked for every [AppShieldEvent] dispatched by WebhookService.
  /// Runs even when [enableWebhooks] is false (direct callback path).
  final void Function(dynamic event)? onLicenseEvent;

  // ── Resolved theme ───────────────────────────────────────────────────────

  AppShieldTheme get resolvedTheme => theme ?? AppShieldTheme.light();

  /// Returns the effective grace-period policy, preferring [gracePeriodPolicy]
  /// when set, otherwise building a default policy from [offlineGraceDays].
  GracePeriodPolicy get resolvedGracePolicy =>
      gracePeriodPolicy ??
      GracePeriodPolicy(graceDays: offlineGraceDays);

  // ── Validation ───────────────────────────────────────────────────────────

  void validate() {
    if (appId.isEmpty)      throw ArgumentError('appId must not be empty.');
    if (apiBaseUrl.isEmpty) throw ArgumentError('apiBaseUrl must not be empty.');
    if (apiKey.isEmpty)     throw ArgumentError('apiKey must not be empty.');
    if (offlineGraceDays < 0)
      throw ArgumentError('offlineGraceDays must be >= 0.');
    if (trialDays < 1) throw ArgumentError('trialDays must be >= 1.');
    if (maxDevicesPerLicense < 1)
      throw ArgumentError('maxDevicesPerLicense must be >= 1.');
    if (validationIntervalHr < 1)
      throw ArgumentError('validationIntervalHr must be >= 1.');
  }

  @override
  String toString() =>
      'AppShieldConfig(appId: $appId, apiBaseUrl: $apiBaseUrl, '
      'trial: $enableTrial/${trialDays}d, offline: $enableOfflineMode/${offlineGraceDays}d)';
}
