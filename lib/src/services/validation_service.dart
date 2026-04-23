// lib/src/services/validation_service.dart

import '../core/api_client.dart';
import '../core/encryption_service.dart';
import '../models/activation_result.dart';
import '../models/device_model.dart';
import '../models/license_model.dart';
import '../models/validation_response.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Handles online license activation, validation, deactivation,
/// renewal, and restore by communicating with the License Server.
class ValidationService {
  ValidationService({
    required ApiClient  apiClient,
    required String     publicKeyPem,
  })  : _api          = apiClient,
        _publicKeyPem = publicKeyPem;

  final ApiClient _api;
  final String    _publicKeyPem;

  // ── Activate ──────────────────────────────────────────────────────────────

  Future<ActivationResult> activate({
    required String     licenseKey,
    required DeviceInfo deviceInfo,
  }) async {
    AppShieldLogger.i('Calling activate API…');
    try {
      final body = await _api.post(
        AppShieldConstants.apiActivate,
        {
          'license_key': licenseKey,
          'device':      deviceInfo.toJson(),
          'timestamp':   DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        deviceId: deviceInfo.fingerprint,
      );

      final license = _parseLicenseFromResponse(body, deviceInfo.fingerprint);
      return ActivationResult.success(license);
    } on LicenseAlreadyUsedException catch (e) {
      return ActivationResult.failure(
        errorCode:        e.code ?? 'LICENSE_ALREADY_USED',
        errorMessage:     e.message,
        existingDeviceId: e.existingDeviceId,
      );
    } on AppShieldException catch (e) {
      return ActivationResult.failure(
        errorCode:    e.code ?? 'ERROR',
        errorMessage: e.message,
      );
    } catch (e) {
      AppShieldLogger.e('Activate unexpected error', error: e);
      return ActivationResult.failure(
        errorCode:    'UNKNOWN_ERROR',
        errorMessage: 'Activation failed. Please check your connection.',
      );
    }
  }

  // ── Validate online ───────────────────────────────────────────────────────

  Future<ValidationResponse> validateOnline({
    required String     licenseKey,
    required DeviceInfo deviceInfo,
  }) async {
    AppShieldLogger.i('Calling validate API…');
    try {
      final body = await _api.post(
        AppShieldConstants.apiValidate,
        {
          'license_key': licenseKey,
          'device_id':   deviceInfo.fingerprint,
          'timestamp':   DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        deviceId: deviceInfo.fingerprint,
      );

      final license    = _parseLicenseFromResponse(body, deviceInfo.fingerprint);
      final token      = body['token']      as String?;
      final serverTime = _parseServerTime(body);

      return ValidationResponse.valid(
        license:    license,
        token:      token,
        serverTime: serverTime,
      );
    } on LicenseExpiredException {
      return ValidationResponse.invalid(
          status: LicenseStatus.expired,
          message: 'License has expired.');
    } on LicenseRevokedException {
      return ValidationResponse.invalid(
          status: LicenseStatus.revoked,
          message: 'License has been revoked.');
    } on LicenseSuspendedException {
      return ValidationResponse.invalid(
          status: LicenseStatus.suspended,
          message: 'License is suspended.');
    } on ApiException catch (e) {
      AppShieldLogger.w('Online validation API error: ${e.message}');
      rethrow;
    } catch (e) {
      AppShieldLogger.w('Online validation failed (network?)', error: e);
      throw ApiException(message: 'Validation failed: $e');
    }
  }

  // ── Deactivate ────────────────────────────────────────────────────────────

  Future<void> deactivate({
    required String     licenseKey,
    required DeviceInfo deviceInfo,
  }) async {
    AppShieldLogger.i('Calling deactivate API…');
    await _api.post(
      AppShieldConstants.apiDeactivate,
      {
        'license_key': licenseKey,
        'device_id':   deviceInfo.fingerprint,
      },
      deviceId: deviceInfo.fingerprint,
    );
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  Future<ActivationResult> restore({
    required String     licenseKey,
    required DeviceInfo deviceInfo,
    String? email,
    String? otpCode,
  }) async {
    AppShieldLogger.i('Calling restore API…');
    try {
      final body = await _api.post(
        AppShieldConstants.apiRestore,
        {
          'license_key': licenseKey,
          'device':      deviceInfo.toJson(),
          if (email   != null) 'email':    email,
          if (otpCode != null) 'otp_code': otpCode,
        },
        deviceId: deviceInfo.fingerprint,
      );

      final license = _parseLicenseFromResponse(body, deviceInfo.fingerprint);
      return ActivationResult.success(license);
    } on AppShieldException catch (e) {
      return ActivationResult.failure(
        errorCode:    e.code ?? 'RESTORE_ERROR',
        errorMessage: e.message,
      );
    } catch (e) {
      return ActivationResult.failure(
        errorCode:    'RESTORE_ERROR',
        errorMessage: 'Restore failed. Please try again.',
      );
    }
  }

  // ── OTP (for restore flow) ────────────────────────────────────────────────

  Future<bool> sendOtp(String email) async {
    try {
      await _api.post(AppShieldConstants.apiOtpSend, {'email': email});
      return true;
    } catch (e) {
      AppShieldLogger.w('OTP send failed', error: e);
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    try {
      final body = await _api.post(
        AppShieldConstants.apiOtpVerify,
        {'email': email, 'code': code},
      );
      return body['verified'] == true;
    } catch (e) {
      AppShieldLogger.w('OTP verify failed', error: e);
      return false;
    }
  }

  // ── Renew ─────────────────────────────────────────────────────────────────

  Future<ActivationResult> renew({
    required String     licenseKey,
    required DeviceInfo deviceInfo,
  }) async {
    AppShieldLogger.i('Calling renew API…');
    try {
      final body = await _api.post(
        AppShieldConstants.apiRenew,
        {
          'license_key': licenseKey,
          'device_id':   deviceInfo.fingerprint,
        },
        deviceId: deviceInfo.fingerprint,
      );
      final license = _parseLicenseFromResponse(body, deviceInfo.fingerprint);
      return ActivationResult.success(license);
    } on AppShieldException catch (e) {
      return ActivationResult.failure(
        errorCode:    e.code ?? 'RENEW_ERROR',
        errorMessage: e.message,
      );
    } catch (e) {
      return ActivationResult.failure(
        errorCode:    'RENEW_ERROR',
        errorMessage: 'Renewal failed. Please try again.',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  License _parseLicenseFromResponse(
      Map<String, dynamic> body, String deviceId) {
    final data = (body['data'] as Map<String, dynamic>?) ?? body;
    final licenseJson =
        (data['license'] as Map<String, dynamic>?) ?? data;

    // Verify RSA signature if present
    final signature = licenseJson['signature'] as String?;
    if (signature != null && _publicKeyPem.isNotEmpty) {
      final payload = _signaturePayload(licenseJson);
      final valid   = EncryptionService.instance.verifyRsaSignature(
        payload:      payload,
        signature:    signature,
        publicKeyPem: _publicKeyPem,
      );
      if (!valid) {
        AppShieldLogger.w('RSA signature invalid — rejecting license.');
        throw const SignatureVerificationException();
      }
    }

    return License(
      key:          licenseJson['key']          as String? ?? '',
      type:         _parseLicenseType(licenseJson['type'] as String?),
      status:       LicenseStatus.active,
      deviceId:     licenseJson['device_id']    as String? ?? deviceId,
      appId:        licenseJson['app_id']       as String? ?? '',
      plan:         licenseJson['plan']         as String? ?? 'standard',
      activatedAt:  _parseDate(licenseJson['activated_at']) ?? DateTime.now().toUtc(),
      expiresAt:    _parseDate(licenseJson['expires_at'])   ??
                    DateTime.now().toUtc().add(const Duration(days: 365)),
      features:     _parseFeatures(licenseJson['features']),
      limits:       _parseLimits(licenseJson['limits']),
      signature:    signature ?? '',
      customerEmail: licenseJson['customer_email'] as String?,
      customerName:  licenseJson['customer_name']  as String?,
    );
  }

  String _signaturePayload(Map<String, dynamic> json) {
    // Build a canonical payload string for signature verification
    return '${json["key"]}:${json["device_id"]}:${json["expires_at"]}';
  }

  LicenseType _parseLicenseType(String? raw) {
    if (raw == null) return LicenseType.subscription;
    try {
      return LicenseType.values.byName(raw);
    } catch (_) {
      return LicenseType.subscription;
    }
  }

  Map<String, bool> _parseFeatures(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k as String, v == true));
    }
    if (raw is List) {
      return {for (final f in raw) f as String: true};
    }
    return {};
  }

  Map<String, int> _parseLimits(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k as String, (v as num).toInt()));
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  DateTime? _parseServerTime(Map<String, dynamic> body) {
    final ts = body['server_time'] ?? body['timestamp'];
    if (ts == null) return null;
    if (ts is String)  return DateTime.tryParse(ts)?.toUtc();
    if (ts is int)     return DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    return null;
  }
}
