// lib/src/utils/exceptions.dart

/// Base exception for all AppShield errors.
abstract class AppShieldException implements Exception {
  const AppShieldException(this.message, {this.code, this.details});
  final String  message;
  final String? code;
  final dynamic details;

  @override
  String toString() => 'AppShieldException[$code]: $message';
}

// ── License exceptions ────────────────────────────────────────────────────

class InvalidLicenseKeyException extends AppShieldException {
  const InvalidLicenseKeyException(
      [String message = 'Invalid license key format.'])
      : super(message, code: 'INVALID_KEY');
}

class LicenseNotFoundException extends AppShieldException {
  const LicenseNotFoundException(
      [String message = 'License key not found.'])
      : super(message, code: 'LICENSE_NOT_FOUND');
}

class LicenseAlreadyUsedException extends AppShieldException {
  const LicenseAlreadyUsedException({
    String message = 'License is already activated on another device.',
    this.existingDeviceId,
  }) : super(message, code: 'LICENSE_ALREADY_USED');
  final String? existingDeviceId;
}

class LicenseExpiredException extends AppShieldException {
  const LicenseExpiredException({
    String message = 'License has expired.',
    this.expiredAt,
  }) : super(message, code: 'LICENSE_EXPIRED');
  final DateTime? expiredAt;
}

class LicenseRevokedException extends AppShieldException {
  const LicenseRevokedException({
    String message = 'License has been revoked.',
    this.reason,
  }) : super(message, code: 'LICENSE_REVOKED');
  final String? reason;
}

class LicenseSuspendedException extends AppShieldException {
  const LicenseSuspendedException(
      [String message = 'License is temporarily suspended.'])
      : super(message, code: 'LICENSE_SUSPENDED');
}

class LicenseNotActivatedException extends AppShieldException {
  const LicenseNotActivatedException(
      [String message = 'No active license found.'])
      : super(message, code: 'NOT_ACTIVATED');
}

class MaxDevicesExceededException extends AppShieldException {
  const MaxDevicesExceededException({
    String message = 'Maximum number of devices exceeded.',
    this.currentCount,
    this.maxAllowed,
  }) : super(message, code: 'MAX_DEVICES_EXCEEDED');
  final int? currentCount;
  final int? maxAllowed;
}

// ── Feature exceptions ────────────────────────────────────────────────────

class FeatureNotAvailableException extends AppShieldException {
  const FeatureNotAvailableException(String feature)
      : super(
            'Feature "$feature" is not available for your current plan.',
            code: 'FEATURE_NOT_AVAILABLE',
            details: feature);
  String get feature => details as String;
}

// ── Device exceptions ─────────────────────────────────────────────────────

class DeviceMismatchException extends AppShieldException {
  const DeviceMismatchException(
      [String message = 'Device fingerprint mismatch.'])
      : super(message, code: 'DEVICE_MISMATCH');
}

class DeviceFingerprintException extends AppShieldException {
  const DeviceFingerprintException(
      [String message = 'Failed to generate device fingerprint.'])
      : super(message, code: 'FINGERPRINT_ERROR');
}

// ── Trial exceptions ──────────────────────────────────────────────────────

class TrialAlreadyUsedException extends AppShieldException {
  const TrialAlreadyUsedException(
      [String message = 'Trial period has already been used on this device.'])
      : super(message, code: 'TRIAL_USED');
}

class TrialExpiredException extends AppShieldException {
  const TrialExpiredException(
      [String message = 'Trial period has expired.'])
      : super(message, code: 'TRIAL_EXPIRED');
}

// ── Security exceptions ───────────────────────────────────────────────────

class ClockTamperingException extends AppShieldException {
  const ClockTamperingException({
    String message = 'System clock manipulation detected.',
    this.tamperType,
  }) : super(message, code: 'CLOCK_TAMPER');
  final String? tamperType;
}

class TamperingDetectedException extends AppShieldException {
  const TamperingDetectedException({
    required String tamperType,
    String message = 'Application tampering detected.',
  }) : super(message, code: 'TAMPER_DETECTED', details: tamperType);
  String get tamperType => details as String;
}

class SignatureVerificationException extends AppShieldException {
  const SignatureVerificationException(
      [String message = 'License signature verification failed.'])
      : super(message, code: 'SIGNATURE_INVALID');
}

class EncryptionException extends AppShieldException {
  const EncryptionException(
      [String message = 'Encryption or decryption failed.'])
      : super(message, code: 'ENCRYPTION_ERROR');
}

// ── Network exceptions ────────────────────────────────────────────────────

class OfflineLimitExceededException extends AppShieldException {
  const OfflineLimitExceededException({
    String message =
        'Offline grace period exceeded. Please connect to the internet.',
    this.graceDays,
  }) : super(message, code: 'OFFLINE_LIMIT');
  final int? graceDays;
}

class ApiException extends AppShieldException {
  const ApiException({
    required String message,
    this.statusCode,
    dynamic details,
  }) : super(message, code: 'API_ERROR', details: details);
  final int? statusCode;
}

class ApiTimeoutException extends AppShieldException {
  const ApiTimeoutException(
      [String message = 'Request timed out. Please try again.'])
      : super(message, code: 'API_TIMEOUT');
}

// ── Configuration exceptions ──────────────────────────────────────────────

class AppShieldNotInitializedException extends AppShieldException {
  const AppShieldNotInitializedException()
      : super(
            'AppShield has not been initialized. '
            'Call AppShield.initialize() first.',
            code: 'NOT_INITIALIZED');
}

class InvalidConfigurationException extends AppShieldException {
  const InvalidConfigurationException(String message)
      : super(message, code: 'INVALID_CONFIG');
}
