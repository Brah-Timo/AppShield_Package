// lib/src/models/activation_result.dart

import 'license_model.dart';

class ActivationResult {
  const ActivationResult._({
    required this.success,
    this.license,
    this.errorCode,
    this.errorMessage,
    this.existingDeviceId,
  });

  final bool     success;
  final License? license;
  final String?  errorCode;
  final String?  errorMessage;
  final String?  existingDeviceId;

  factory ActivationResult.success(License license) =>
      ActivationResult._(success: true, license: license);

  factory ActivationResult.failure({
    required String errorCode,
    required String errorMessage,
    String? existingDeviceId,
  }) =>
      ActivationResult._(
        success:          false,
        errorCode:        errorCode,
        errorMessage:     errorMessage,
        existingDeviceId: existingDeviceId,
      );

  @override
  String toString() => success
      ? 'ActivationResult(success, plan: ${license?.plan})'
      : 'ActivationResult(failure, code: $errorCode)';
}
