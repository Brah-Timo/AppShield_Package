// lib/src/core/license_manager.dart

import 'dart:async';

import '../models/activation_result.dart';
import '../models/activity_log_entry.dart';
import '../models/device_model.dart';
import '../models/license_model.dart';
import '../models/validation_response.dart';
import '../services/storage_service.dart';
import '../services/validation_service.dart';
import '../services/trial_service.dart';
import '../core/device_fingerprint.dart';
import '../core/clock_verifier.dart';
import '../core/tamper_detector.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Central engine that manages the entire license lifecycle.
///
/// Responsibilities:
///   • Loading / caching the current license
///   • Coordinating activation, deactivation, renewal, restore
///   • Periodic background validation
///   • Delegating to [ValidationService], [TrialService],
///     [ClockVerifier], [TamperDetector]
///   • Emitting status-change notifications via [licenseStream]
class LicenseManager {
  LicenseManager._();

  static final LicenseManager _instance = LicenseManager._();
  static LicenseManager get instance => _instance;

  // ── Dependencies (injected during initialization) ─────────────────────────
  late ValidationService _validationService;
  late TrialService      _trialService;
  late ClockVerifier     _clockVerifier;
  late int               _offlineGraceDays;
  late int               _validationIntervalHr;

  // ── State ─────────────────────────────────────────────────────────────────
  License?     _currentLicense;
  DeviceInfo?  _deviceInfo;
  Timer?       _periodicTimer;

  final _statusController =
      StreamController<LicenseStatus>.broadcast();

  /// Stream of [LicenseStatus] changes.
  Stream<LicenseStatus> get licenseStream => _statusController.stream;

  /// The currently cached license (may be null before first [initialize]).
  License? get currentLicense => _currentLicense;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({
    required ValidationService validationService,
    required TrialService      trialService,
    required ClockVerifier     clockVerifier,
    required int               offlineGraceDays,
    required int               validationIntervalHr,
  }) async {
    _validationService    = validationService;
    _trialService         = trialService;
    _clockVerifier        = clockVerifier;
    _offlineGraceDays     = offlineGraceDays;
    _validationIntervalHr = validationIntervalHr;

    // Resolve device fingerprint once at startup
    _deviceInfo = await DeviceFingerprintService.instance.getDeviceInfo();
    AppShieldLogger.i('Device fingerprint: ${_deviceInfo!.fingerprint}');

    // Load persisted license
    _currentLicense = await StorageService.instance.readLicense();
    AppShieldLogger.i('Persisted license: '
        '${_currentLicense?.status.name ?? "none"}');

    // Start periodic validation timer
    _startPeriodicValidation();
  }

  // ── Status check (used by AppShieldGuard) ─────────────────────────────────

  /// Full check: tamper → clock → device → expiry → online/offline.
  Future<LicenseStatus> checkLicense() async {
    try {
      // 1. Tamper checks
      final tampers = await TamperDetector.instance.runChecks();
      if (tampers.any((t) => t.severity == 'high' || t.severity == 'critical')) {
        await _logActivity(AppShieldConstants.actionTamperDetected,
            details: tampers.first.tamperType);
        _emit(LicenseStatus.tampered);
        return LicenseStatus.tampered;
      }

      // 2. No persisted license
      if (_currentLicense == null) {
        // Check trial
        final trialStatus = await _trialService.checkTrial();
        _emit(trialStatus);
        return trialStatus;
      }

      // 3. Device fingerprint check
      final fp = _deviceInfo!.fingerprint;
      if (_currentLicense!.deviceId != fp) {
        AppShieldLogger.w('Device mismatch: stored=${_currentLicense!.deviceId} '
            'current=$fp');
        _emit(LicenseStatus.deviceMismatch);
        return LicenseStatus.deviceMismatch;
      }

      // 4. Revoked / suspended
      if (_currentLicense!.status == LicenseStatus.revoked) {
        _emit(LicenseStatus.revoked);
        return LicenseStatus.revoked;
      }
      if (_currentLicense!.status == LicenseStatus.suspended) {
        _emit(LicenseStatus.suspended);
        return LicenseStatus.suspended;
      }

      // 5. Perpetual — no expiry check needed, just verify online if possible
      if (_currentLicense!.isPerpetual) {
        await _tryOnlineValidation();
        _emit(LicenseStatus.active);
        return LicenseStatus.active;
      }

      // 6. Expiry check
      if (_currentLicense!.isExpired) {
        // Check grace period
        final graceStatus = await _handleGracePeriod();
        _emit(graceStatus);
        return graceStatus;
      }

      // 7. Periodic online validation
      await _tryOnlineValidation();

      _emit(LicenseStatus.active);
      return LicenseStatus.active;
    } catch (e, st) {
      AppShieldLogger.e('checkLicense error', error: e, stackTrace: st);
      _emit(LicenseStatus.offline);
      return LicenseStatus.offline;
    }
  }

  // ── Activation ────────────────────────────────────────────────────────────

  Future<ActivationResult> activate(String licenseKey) async {
    final key = licenseKey.trim().toUpperCase();
    AppShieldLogger.i('Activating license: ${key.substring(0, 4)}****');

    // Basic format validation
    final pattern = RegExp(AppShieldConstants.licenseKeyPattern);
    if (!pattern.hasMatch(key)) {
      return ActivationResult.failure(
        errorCode:    'INVALID_KEY',
        errorMessage: 'Invalid license key format.',
      );
    }

    try {
      final deviceId = _deviceInfo!.fingerprint;
      final result   = await _validationService.activate(
        licenseKey: key,
        deviceInfo: _deviceInfo!,
      );

      if (result.success && result.license != null) {
        _currentLicense = result.license;
        await StorageService.instance.saveLicense(_currentLicense!);
        await StorageService.instance.deleteGraceStart();
        await _logActivity(AppShieldConstants.actionActivate,
            licenseKey: key, deviceFingerprint: deviceId);
        _emit(LicenseStatus.active);
        AppShieldLogger.i('License activated successfully. Plan: ${_currentLicense!.plan}');
      }

      return result;
    } on ApiException catch (e) {
      AppShieldLogger.e('Activation API error', error: e);
      return ActivationResult.failure(
        errorCode:    e.code ?? 'API_ERROR',
        errorMessage: e.message,
      );
    } catch (e) {
      AppShieldLogger.e('Activation failed', error: e);
      return ActivationResult.failure(
        errorCode:    'UNKNOWN_ERROR',
        errorMessage: 'Activation failed. Please try again.',
      );
    }
  }

  // ── Deactivation ──────────────────────────────────────────────────────────

  Future<bool> deactivate() async {
    if (_currentLicense == null) return false;
    AppShieldLogger.i('Deactivating license…');
    try {
      await _validationService.deactivate(
        licenseKey: _currentLicense!.key,
        deviceInfo: _deviceInfo!,
      );
    } catch (e) {
      AppShieldLogger.w('Server deactivation failed (continuing locally)', error: e);
    }

    await _logActivity(AppShieldConstants.actionDeactivate,
        licenseKey: _currentLicense?.key,
        deviceFingerprint: _deviceInfo?.fingerprint);
    await StorageService.instance.deleteLicense();
    _currentLicense = null;
    _emit(LicenseStatus.notActivated);
    return true;
  }

  // ── Online validation ─────────────────────────────────────────────────────

  Future<ValidationResponse?> validateOnline() async {
    if (_currentLicense == null) return null;
    AppShieldLogger.i('Running online validation…');
    try {
      final response = await _validationService.validateOnline(
        licenseKey: _currentLicense!.key,
        deviceInfo: _deviceInfo!,
      );

      if (response.isValid && response.license != null) {
        _currentLicense = response.license!
            .copyWith(lastValidatedAt: DateTime.now().toUtc());
        await StorageService.instance.saveLicense(_currentLicense!);
        await StorageService.instance
            .saveLastValidationTime(DateTime.now().toUtc());
        await StorageService.instance.deleteGraceStart();
        AppShieldLogger.i('Online validation successful.');
      } else {
        AppShieldLogger.w('Online validation returned: ${response.status}');
        _currentLicense =
            _currentLicense!.copyWith(status: response.status);
        await StorageService.instance.saveLicense(_currentLicense!);
        _emit(response.status);
      }

      return response;
    } catch (e) {
      AppShieldLogger.w('Online validation failed (offline?)', error: e);
      return null;
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  Future<ActivationResult> restore({
    required String licenseKey,
    String? email,
    String? otpCode,
  }) async {
    AppShieldLogger.i('Restoring license…');
    try {
      final result = await _validationService.restore(
        licenseKey: licenseKey.trim().toUpperCase(),
        deviceInfo: _deviceInfo!,
        email:      email,
        otpCode:    otpCode,
      );

      if (result.success && result.license != null) {
        _currentLicense = result.license;
        await StorageService.instance.saveLicense(_currentLicense!);
        await _logActivity(AppShieldConstants.actionRestore,
            licenseKey: licenseKey,
            deviceFingerprint: _deviceInfo?.fingerprint);
        _emit(LicenseStatus.active);
      }
      return result;
    } catch (e) {
      AppShieldLogger.e('Restore failed', error: e);
      return ActivationResult.failure(
        errorCode:    'RESTORE_ERROR',
        errorMessage: 'Restore failed. Please try again.',
      );
    }
  }

  // ── Renewal ───────────────────────────────────────────────────────────────

  Future<ActivationResult> renew({required String newLicenseKey}) async {
    AppShieldLogger.i('Renewing license…');
    return activate(newLicenseKey);
  }

  // ── Trial ─────────────────────────────────────────────────────────────────

  Future<bool> startTrial({String? email}) async =>
      _trialService.startTrial(email: email);

  Future<LicenseStatus> getTrialStatus() => _trialService.checkTrial();

  int get trialDaysRemaining => _trialService.daysRemaining;

  // ── Feature helpers ───────────────────────────────────────────────────────

  bool hasFeature(String feature) =>
      _currentLicense?.hasFeature(feature) ?? false;

  int getLimit(String key, {int defaultValue = 0}) =>
      _currentLicense?.getLimit(key, defaultValue: defaultValue) ?? defaultValue;

  bool get isLicenseValid =>
      _currentLicense?.isValid ?? false;

  int get daysRemaining =>
      _currentLicense?.daysRemaining ?? 0;

  // ── Grace period ──────────────────────────────────────────────────────────

  Future<LicenseStatus> _handleGracePeriod() async {
    var graceStart = await StorageService.instance.readGraceStart();
    if (graceStart == null) {
      graceStart = DateTime.now().toUtc();
      await StorageService.instance.saveGraceStart(graceStart);
    }

    final graceDaysUsed =
        DateTime.now().toUtc().difference(graceStart).inDays;
    AppShieldLogger.i('Grace period: $graceDaysUsed / $_offlineGraceDays days used.');

    if (graceDaysUsed <= _offlineGraceDays) {
      return LicenseStatus.gracePeriod;
    }

    await _logActivity(AppShieldConstants.actionExpired,
        licenseKey: _currentLicense?.key);
    return LicenseStatus.expired;
  }

  // ── Periodic validation ───────────────────────────────────────────────────

  void _startPeriodicValidation() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      Duration(hours: _validationIntervalHr),
      (_) async {
        AppShieldLogger.d('Periodic validation triggered.');
        await validateOnline();
      },
    );
  }

  Future<void> _tryOnlineValidation() async {
    final lastValidation =
        await StorageService.instance.readLastValidationTime();
    if (lastValidation == null) {
      await validateOnline();
      return;
    }
    final hoursSince =
        DateTime.now().toUtc().difference(lastValidation).inHours;
    if (hoursSince >= _validationIntervalHr) {
      await validateOnline();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _emit(LicenseStatus status) {
    if (!_statusController.isClosed) _statusController.add(status);
  }

  Future<void> _logActivity(
    String action, {
    String? licenseKey,
    String? deviceFingerprint,
    String? details,
  }) async {
    final entry = ActivityLogEntry(
      action:            action,
      timestamp:         DateTime.now().toUtc(),
      licenseKey:        licenseKey,
      deviceFingerprint: deviceFingerprint,
      details:           details,
    );
    await StorageService.instance.appendActivityLog(entry);
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    _periodicTimer?.cancel();
    _statusController.close();
  }
}
