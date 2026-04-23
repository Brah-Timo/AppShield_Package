// lib/src/models/validation_response.dart

import 'license_model.dart';

class ValidationResponse {
  const ValidationResponse._({
    required this.isValid,
    required this.status,
    this.license,
    this.token,
    this.message,
    this.serverTime,
  });

  final bool          isValid;
  final LicenseStatus status;
  final License?      license;
  final String?       token;
  final String?       message;
  final DateTime?     serverTime;

  factory ValidationResponse.valid({
    required License license,
    String? token,
    DateTime? serverTime,
  }) =>
      ValidationResponse._(
        isValid:    true,
        status:     LicenseStatus.active,
        license:    license,
        token:      token,
        serverTime: serverTime,
      );

  factory ValidationResponse.invalid({
    required LicenseStatus status,
    String? message,
  }) =>
      ValidationResponse._(
        isValid: false,
        status:  status,
        message: message,
      );

  factory ValidationResponse.gracePeriod({
    required License license,
    String? message,
  }) =>
      ValidationResponse._(
        isValid: true,
        status:  LicenseStatus.gracePeriod,
        license: license,
        message: message,
      );

  @override
  String toString() =>
      'ValidationResponse(isValid: $isValid, status: $status)';
}
