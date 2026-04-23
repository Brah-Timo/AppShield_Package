// lib/src/utils/constants.dart

/// Global constants for the AppShield package.
library app_shield.constants;

class AppShieldConstants {
  AppShieldConstants._();

  // ── Package meta ──────────────────────────────────────────────────────────
  static const String packageName    = 'app_shield';
  static const String packageVersion = '1.0.0';

  // ── Storage keys ─────────────────────────────────────────────────────────
  static const String storageKeyLicense        = 'as_license_data';
  static const String storageKeyDeviceId       = 'as_device_id';
  static const String storageKeyTrialStart     = 'as_trial_start';
  static const String storageKeyTrialUsed      = 'as_trial_used';
  static const String storageKeyLastValidation = 'as_last_validation';
  static const String storageKeyLastKnownTime  = 'as_last_known_time';
  static const String storageKeyInstallTime    = 'as_install_time';
  static const String storageKeyBackupLicense  = 'as_backup_license';
  static const String storageKeyTamperFlag     = 'as_tamper_flag';
  static const String storageKeyActivityLog    = 'as_activity_log';
  static const String storageKeyGraceStart     = 'as_grace_start';

  // ── API paths ─────────────────────────────────────────────────────────────
  static const String apiActivate    = '/license/activate';
  static const String apiValidate    = '/license/validate';
  static const String apiRestore     = '/license/restore';
  static const String apiDeactivate  = '/license/deactivate';
  static const String apiRenew       = '/license/renew';
  static const String apiInfo        = '/license/info';
  static const String apiFeatures    = '/license/features';
  static const String apiTrialStart  = '/trial/start';
  static const String apiTelemetry   = '/telemetry/send';
  static const String apiUpdateCheck = '/updates/check';
  static const String apiServerTime  = '/system/time';
  static const String apiOtpSend     = '/auth/otp/send';
  static const String apiOtpVerify   = '/auth/otp/verify';

  // ── Defaults ──────────────────────────────────────────────────────────────
  static const int    defaultOfflineGraceDays     = 7;
  static const int    defaultTrialDays            = 15;
  static const int    defaultMaxDevices           = 1;
  static const int    defaultValidationIntervalHr = 24;
  static const int    defaultClockToleranceMin    = 10;
  static const int    defaultApiTimeoutSec        = 30;
  static const int    defaultRetryCount           = 3;
  static const int    defaultRetryDelayMs         = 1500;
  static const int    expiryWarnDays              = 7;

  // ── Encryption ────────────────────────────────────────────────────────────
  static const int    aesKeyLength  = 32; // 256 bits
  static const int    aesIvLength   = 12; // 96 bits (GCM)
  static const int    pbkdf2Rounds  = 100000;
  static const int    pbkdf2Length  = 32;

  // ── License key format ────────────────────────────────────────────────────
  static const String licenseKeyPattern =
      r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}(-[A-Z0-9]{4})?$';
  static const int    licenseKeySegmentLength = 4;
  static const String licenseKeyDelimiter     = '-';

  // ── Feature keys ─────────────────────────────────────────────────────────
  static const String featureAdvancedReports = 'advanced_reports';
  static const String featureMultiUser       = 'multi_user';
  static const String featureApiAccess       = 'api_access';
  static const String featureCloudBackup     = 'cloud_backup';
  static const String featureExportPdf       = 'export_pdf';
  static const String featurePro             = 'pro';

  // ── Activity log actions ──────────────────────────────────────────────────
  static const String actionActivate       = 'activate';
  static const String actionDeactivate     = 'deactivate';
  static const String actionValidate       = 'validate';
  static const String actionValidateFailed = 'validate_failed';
  static const String actionTrialStart     = 'trial_start';
  static const String actionTrialExpired   = 'trial_expired';
  static const String actionRestore        = 'restore';
  static const String actionRenew          = 'renew';
  static const String actionTamperDetected = 'tamper_detected';
  static const String actionRevoked        = 'revoked';
  static const String actionExpired        = 'expired';

  // ── Tamper types ──────────────────────────────────────────────────────────
  static const String tamperClockMismatch    = 'clock_mismatch';
  static const String tamperClockRollback    = 'clock_rollback';
  static const String tamperStorageModified  = 'storage_modified';
  static const String tamperDeviceSpoofing   = 'device_spoofing';
  static const String tamperDebuggerAttached = 'debugger_attached';
  static const String tamperRootJailbreak    = 'root_jailbreak';
  static const String tamperEmulator         = 'emulator_detected';

  // ── HTTP headers ──────────────────────────────────────────────────────────
  static const String headerApiKey     = 'X-API-Key';
  static const String headerAppId      = 'X-App-Id';
  static const String headerAppVersion = 'X-App-Version';
  static const String headerDeviceId   = 'X-Device-Id';
  static const String headerTimestamp  = 'X-Timestamp';
  static const String headerTenantId   = 'X-Tenant-Id';
  static const String headerRequestId  = 'X-Request-Id';

  // ── Batch 12 – Advanced storage keys ─────────────────────────────────────
  static const String storageKeyAnalytics    = 'as_analytics_metrics';
  static const String storageKeyLicensePool  = 'as_license_pool';
  static const String storageKeyWebhookQueue = 'as_webhook_queue';
  static const String storageKeyHealthLog    = 'as_health_log';
  static const String storageKeyGraceExt     = 'as_grace_extensions';

  // ── Batch 12 – Advanced API paths ────────────────────────────────────────
  static const String apiPoolStatus    = '/pool/status';
  static const String apiPoolAssign    = '/pool/assign';
  static const String apiPoolRelease   = '/pool/release';
  static const String apiWebhookPush   = '/webhook/push';
  static const String apiHealthReport  = '/health/report';
  static const String apiGraceExtend   = '/license/extend-grace';
  static const String apiTenantInfo    = '/tenant/info';
  static const String apiBulkValidate  = '/license/bulk-validate';
  static const String apiLicenseTransfer = '/license/transfer';

  // ── Batch 12 – Advanced defaults ─────────────────────────────────────────
  static const int    defaultHealthCheckIntervalSec = 60;
  static const int    defaultCacheTTLMinutes        = 60;
  static const int    defaultMaxGraceExtensions     = 2;
  static const int    defaultMaxAnalyticsEntries    = 500;
  static const int    defaultSeatWarningThreshold   = 90; // %
  static const int    defaultWebhookQueueSize       = 100;

  // ── Batch 12 – Extended feature keys ─────────────────────────────────────
  static const String featureWhiteLabel      = 'white_label';
  static const String featureMultiTenant     = 'multi_tenant';
  static const String featureSeatPooling     = 'seat_pooling';
  static const String featureAdvancedAnalytics = 'advanced_analytics';
  static const String featureWebhooks        = 'webhooks';
  static const String featurePrioritySupport = 'priority_support';
  static const String featureCustomBranding  = 'custom_branding';
  static const String featureSso             = 'sso';
  static const String featureBulkActivation  = 'bulk_activation';
  static const String featureLicenseTransfer = 'license_transfer';

  // ── Batch 12 – Extended action log events ────────────────────────────────
  static const String actionGraceExtended     = 'grace_extended';
  static const String actionSeatClaimed       = 'seat_claimed';
  static const String actionSeatReleased      = 'seat_released';
  static const String actionTenantSwitch      = 'tenant_switch';
  static const String actionHealthCritical    = 'health_critical';
  static const String actionCacheInvalidated  = 'cache_invalidated';
  static const String actionBulkValidate      = 'bulk_validate';
  static const String actionLicenseTransfer   = 'license_transfer';
  static const String actionWebhookDispatched = 'webhook_dispatched';
  static const String actionAnalyticsExport   = 'analytics_export';
}
