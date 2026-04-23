// lib/src/services/trial_service.dart

import '../core/api_client.dart';
import '../core/device_fingerprint.dart';
import '../models/license_model.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Manages the trial period lifecycle:
///   - Checking if trial is available on this device
///   - Starting a trial (local + optional server registration)
///   - Returning trial status and days remaining
class TrialService {
  TrialService({
    required ApiClient  apiClient,
    required int        trialDays,
    required String     appId,
  })  : _api      = apiClient,
        _trialDays = trialDays,
        _appId     = appId;

  final ApiClient _api;
  final int       _trialDays;
  final String    _appId;

  int _daysRemaining = 0;

  int get daysRemaining => _daysRemaining;

  // ── Start trial ───────────────────────────────────────────────────────────

  /// Starts the trial period.
  ///
  /// Returns `true` on success.
  /// Throws [TrialAlreadyUsedException] if already used on this device.
  Future<bool> startTrial({String? email}) async {
    AppShieldLogger.i('Attempting to start trial…');

    // 1. Check if already used locally
    if (await StorageService.instance.isTrialUsed()) {
      AppShieldLogger.w('Trial already used on this device.');
      throw const TrialAlreadyUsedException();
    }

    final deviceInfo = await DeviceFingerprintService.instance.getDeviceInfo();
    final startDate  = DateTime.now().toUtc();

    // 2. Register with server (best-effort; trial works offline too)
    await _tryRegisterTrialOnServer(
      deviceFingerprint: deviceInfo.fingerprint,
      email:             email,
    );

    // 3. Save locally
    await StorageService.instance.saveTrialStart(startDate);
    AppShieldLogger.i('Trial started: $startDate, expires in $_trialDays days.');

    return true;
  }

  // ── Check trial ───────────────────────────────────────────────────────────

  /// Returns the current trial [LicenseStatus].
  Future<LicenseStatus> checkTrial() async {
    final trialStart = await StorageService.instance.readTrialStart();

    if (trialStart == null) {
      _daysRemaining = 0;
      return LicenseStatus.notActivated;
    }

    final expiry    = trialStart.add(Duration(days: _trialDays));
    final now       = DateTime.now().toUtc();
    _daysRemaining  = expiry.difference(now).inDays;

    if (now.isBefore(expiry)) {
      AppShieldLogger.d('Trial active: $_daysRemaining day(s) remaining.');
      return LicenseStatus.trial;
    } else {
      _daysRemaining = 0;
      AppShieldLogger.i('Trial expired.');
      return LicenseStatus.expired;
    }
  }

  /// Returns true if trial is currently active.
  Future<bool> isTrialActive() async =>
      (await checkTrial()) == LicenseStatus.trial;

  // ── Trial expiry date ─────────────────────────────────────────────────────

  Future<DateTime?> getTrialExpiryDate() async {
    final start = await StorageService.instance.readTrialStart();
    if (start == null) return null;
    return start.add(Duration(days: _trialDays));
  }

  // ── Server registration ───────────────────────────────────────────────────

  Future<void> _tryRegisterTrialOnServer({
    required String deviceFingerprint,
    String? email,
  }) async {
    try {
      await _api.post(
        AppShieldConstants.apiTrialStart,
        {
          'device_fingerprint': deviceFingerprint,
          'app_id':             _appId,
          if (email != null) 'email': email,
        },
        deviceId: deviceFingerprint,
      );
      AppShieldLogger.d('Trial registered on server.');
    } catch (e) {
      // Server registration is best-effort; trial still starts locally
      AppShieldLogger.d('Trial server registration skipped (offline?): $e');
    }
  }
}
