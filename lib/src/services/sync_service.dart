// lib/src/services/sync_service.dart

import '../core/api_client.dart';
import '../core/license_manager.dart';
import '../models/tamper_record.dart';
import '../models/activity_log_entry.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Synchronises local state with the License Server:
///   - Pushes pending activity logs
///   - Reports tamper attempts
///   - Sends telemetry (opt-in)
///   - Checks for license updates
class SyncService {
  SyncService({
    required ApiClient apiClient,
    required String    appId,
    bool               enableTelemetry = false,
  })  : _api             = apiClient,
        _appId           = appId,
        _enableTelemetry = enableTelemetry;

  final ApiClient _api;
  final String    _appId;
  final bool      _enableTelemetry;

  // ── Telemetry ─────────────────────────────────────────────────────────────

  /// Sends an anonymous usage event to the License Server.
  /// Only fires if [enableTelemetry] is true in the config.
  Future<void> sendTelemetry({
    required String event,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!_enableTelemetry) return;

    try {
      final license    = LicenseManager.instance.currentLicense;
      final deviceInfo = await _getDeviceId();

      await _api.post(
        AppShieldConstants.apiTelemetry,
        {
          'app_id':     _appId,
          'event':      event,
          'device_id':  deviceInfo,
          'license_key': license?.key,
          'plan':        license?.plan,
          'extra':       extra,
          'timestamp':  DateTime.now().toUtc().toIso8601String(),
        },
      );
      AppShieldLogger.d('Telemetry sent: $event');
    } catch (e) {
      AppShieldLogger.d('Telemetry send failed (non-critical): $e');
    }
  }

  // ── Tamper reports ────────────────────────────────────────────────────────

  /// Reports a tamper attempt to the License Server.
  Future<void> reportTamperAttempt(TamperRecord record) async {
    try {
      final license = LicenseManager.instance.currentLicense;
      await _api.post(
        '/tamper/report',
        {
          'app_id':             _appId,
          'license_key':        license?.key,
          'device_fingerprint': record.deviceFingerprint,
          'tamper_type':        record.tamperType,
          'severity':           record.severity,
          'details':            record.details,
          'detected_at':        record.detectedAt.toIso8601String(),
        },
      );
      AppShieldLogger.i('Tamper report sent: ${record.tamperType}');
    } catch (e) {
      AppShieldLogger.w('Failed to report tamper attempt: $e');
    }
  }

  // ── Activity log sync ─────────────────────────────────────────────────────

  /// Pushes local activity log entries to the server and clears the local log.
  Future<void> syncActivityLog() async {
    try {
      final entries = await StorageService.instance.readActivityLog();
      if (entries.isEmpty) return;

      await _api.post(
        '/activity/batch',
        {
          'app_id':  _appId,
          'entries': entries.map((e) => e.toJson()).toList(),
        },
      );
      await StorageService.instance.clearActivityLog();
      AppShieldLogger.d('Activity log synced (${entries.length} entries).');
    } catch (e) {
      AppShieldLogger.d('Activity log sync failed (non-critical): $e');
    }
  }

  // ── Update check ──────────────────────────────────────────────────────────

  /// Returns a [UpdateInfo] if a newer version of the licensed app is available.
  Future<UpdateInfo?> checkForUpdates(String currentVersion) async {
    try {
      final body = await _api.get(
        AppShieldConstants.apiUpdateCheck,
        queryParams: {
          'app_id':          _appId,
          'current_version': currentVersion,
        },
      );
      final hasUpdate = body['has_update'] == true;
      if (!hasUpdate) return null;
      return UpdateInfo(
        latestVersion:  body['latest_version'] as String? ?? '',
        releaseNotes:   body['release_notes']  as String? ?? '',
        downloadUrl:    body['download_url']   as String? ?? '',
        isMandatory:    body['is_mandatory']   == true,
      );
    } catch (e) {
      AppShieldLogger.d('Update check failed: $e');
      return null;
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<String?> _getDeviceId() async {
    return StorageService.instance.readDeviceId();
  }
}

/// Metadata about an available app update.
class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isMandatory,
  });

  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool   isMandatory;
}
