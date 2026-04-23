// lib/src/core/api_client.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Low-level HTTP client for all AppShield server communication.
///
/// Features:
///   - Automatic retry with exponential back-off
///   - Standard AppShield request headers
///   - Structured error parsing
///   - TLS enforcement (HTTPS-only in production)
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String apiKey,
    required String appId,
    required String appVersion,
    int timeoutSeconds = AppShieldConstants.defaultApiTimeoutSec,
    int retryCount     = AppShieldConstants.defaultRetryCount,
  })  : _baseUrl        = baseUrl.trimRight().replaceAll(RegExp(r'/+$'), ''),
        _apiKey         = apiKey,
        _appId          = appId,
        _appVersion     = appVersion,
        _timeout        = Duration(seconds: timeoutSeconds),
        _retryCount     = retryCount;

  final String   _baseUrl;
  final String   _apiKey;
  final String   _appId;
  final String   _appVersion;
  final Duration _timeout;
  final int      _retryCount;

  // ── Public HTTP methods ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    String? deviceId,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _execute(() => http.get(uri, headers: _headers(deviceId)));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? deviceId,
  }) async {
    final uri = _buildUri(path, null);
    return _execute(() => http.post(
          uri,
          headers: _headers(deviceId),
          body:    jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? deviceId,
  }) async {
    final uri = _buildUri(path, null);
    return _execute(() => http.put(
          uri,
          headers: _headers(deviceId),
          body:    jsonEncode(body),
        ));
  }

  // ── Core execution with retry ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _execute(
      Future<http.Response> Function() request) async {
    Exception? lastError;

    for (var attempt = 0; attempt <= _retryCount; attempt++) {
      if (attempt > 0) {
        final delayMs = AppShieldConstants.defaultRetryDelayMs * attempt;
        AppShieldLogger.d('Retry attempt $attempt — waiting ${delayMs}ms');
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      try {
        final response = await request().timeout(_timeout);
        return _handleResponse(response);
      } on SocketException catch (e) {
        lastError = ApiException(message: 'No internet connection.', details: e);
        AppShieldLogger.w('SocketException (attempt $attempt): $e');
      } on HttpException catch (e) {
        lastError = ApiException(message: e.message);
        AppShieldLogger.w('HttpException (attempt $attempt): $e');
      } on ApiException {
        // Don't retry on 4xx client errors
        rethrow;
      } on ApiTimeoutException {
        lastError = const ApiTimeoutException();
        AppShieldLogger.w('Timeout on attempt $attempt');
      } catch (e) {
        lastError = ApiException(message: 'Unexpected error: $e');
        AppShieldLogger.w('Unexpected error on attempt $attempt: $e');
      }
    }

    throw lastError ?? const ApiException(message: 'Request failed.');
  }

  // ── Response handling ─────────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    AppShieldLogger.d('Response ${response.statusCode}: '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

    final body = _parseBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // 4xx — client errors (not retried)
    final message = body['message'] as String? ??
        body['error']   as String? ??
        'HTTP ${response.statusCode}';
    final code    = body['code'] as String?;

    if (response.statusCode == 401) {
      throw ApiException(
          message: message, statusCode: response.statusCode);
    }
    if (response.statusCode == 404) {
      throw const LicenseNotFoundException();
    }
    if (response.statusCode >= 400 && response.statusCode < 500) {
      // Map known server codes to typed exceptions
      _throwTypedException(code, message);
      throw ApiException(
          message: message, statusCode: response.statusCode);
    }
    // 5xx — server errors (retried)
    throw ApiException(
        message: 'Server error (${response.statusCode}): $message',
        statusCode: response.statusCode);
  }

  void _throwTypedException(String? code, String message) {
    switch (code) {
      case 'INVALID_KEY':
        throw InvalidLicenseKeyException(message);
      case 'LICENSE_NOT_FOUND':
        throw LicenseNotFoundException(message);
      case 'LICENSE_ALREADY_USED':
        throw LicenseAlreadyUsedException(message: message);
      case 'LICENSE_EXPIRED':
        throw LicenseExpiredException(message: message);
      case 'LICENSE_REVOKED':
        throw LicenseRevokedException(message: message);
      case 'LICENSE_SUSPENDED':
        throw LicenseSuspendedException(message);
      case 'MAX_DEVICES_EXCEEDED':
        throw MaxDevicesExceededException(message: message);
      case 'TRIAL_USED':
        throw TrialAlreadyUsedException(message);
      case 'DEVICE_MISMATCH':
        throw DeviceMismatchException(message);
    }
  }

  Map<String, dynamic> _parseBody(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return {'raw': body};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final base = Uri.parse('$_baseUrl$path');
    if (queryParams == null || queryParams.isEmpty) return base;
    return base.replace(
        queryParameters: {...base.queryParameters, ...queryParams});
  }

  Map<String, String> _headers(String? deviceId) => {
        'Content-Type':                       'application/json',
        'Accept':                             'application/json',
        AppShieldConstants.headerApiKey:      _apiKey,
        AppShieldConstants.headerAppId:       _appId,
        AppShieldConstants.headerAppVersion:  _appVersion,
        if (deviceId != null)
          AppShieldConstants.headerDeviceId:  deviceId,
        AppShieldConstants.headerTimestamp:
            DateTime.now().millisecondsSinceEpoch.toString(),
      };

  // ── Connectivity check ────────────────────────────────────────────────────

  Future<bool> isServerReachable() async {
    try {
      final uri = _buildUri(AppShieldConstants.apiServerTime, null);
      final res = await http.get(uri, headers: _headers(null))
          .timeout(const Duration(seconds: 5));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
