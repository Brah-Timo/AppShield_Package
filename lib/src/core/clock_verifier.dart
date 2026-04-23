// lib/src/core/clock_verifier.dart

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Detects system-clock tampering by comparing local time against:
///   1. A trusted NTP-style HTTP time endpoint on the License Server.
///   2. The last known trusted time stored in secure storage.
class ClockVerifier {
  ClockVerifier({required String apiBaseUrl})
      : _timeUrl = '$apiBaseUrl${AppShieldConstants.apiServerTime}';

  final String _timeUrl;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Verifies that the system clock has not been manipulated.
  ///
  /// Returns `true` if the clock appears trustworthy.
  /// Throws [ClockTamperingException] when tampering is detected.
  Future<bool> verifyClock() async {
    final localNow = DateTime.now().toUtc();

    // Try online check first
    final serverTime = await _fetchServerTime();
    if (serverTime != null) {
      return _compareWithServer(localNow, serverTime);
    }

    // Fall back to last-known-time check
    return _compareWithLastKnown(localNow);
  }

  /// Returns the server's current UTC time, or null if unreachable.
  Future<DateTime?> fetchServerTimeOrNull() => _fetchServerTime();

  // ── Online check ──────────────────────────────────────────────────────────

  Future<bool> _compareWithServer(
      DateTime localNow, DateTime serverTime) async {
    final diff = localNow.difference(serverTime).abs();

    AppShieldLogger.d(
        'Clock diff with server: ${diff.inSeconds}s '
        '(tolerance: ${AppShieldConstants.defaultClockToleranceMin * 60}s)');

    if (diff.inMinutes > AppShieldConstants.defaultClockToleranceMin) {
      AppShieldLogger.w(
          'Clock mismatch detected: local=$localNow server=$serverTime '
          'diff=${diff.inMinutes}min');
      await _recordLastKnown(serverTime); // trust server time
      throw ClockTamperingException(
        tamperType: AppShieldConstants.tamperClockMismatch,
        message:
            'System clock is off by ${diff.inMinutes} minutes. '
            'Please set your system clock to the correct time.',
      );
    }

    await _recordLastKnown(serverTime);
    return true;
  }

  // ── Offline / last-known-time check ───────────────────────────────────────

  Future<bool> _compareWithLastKnown(DateTime localNow) async {
    final lastKnown =
        await StorageService.instance.readLastKnownTime();

    if (lastKnown == null) {
      // First run with no server — store current time and allow
      await _recordLastKnown(localNow);
      return true;
    }

    if (localNow.isBefore(lastKnown)) {
      // Clock went backwards — classic rollback attack
      final rollback = lastKnown.difference(localNow);
      AppShieldLogger.w(
          'Clock rollback detected: '
          'now=$localNow lastKnown=$lastKnown rollback=${rollback.inMinutes}min');
      throw ClockTamperingException(
        tamperType: AppShieldConstants.tamperClockRollback,
        message: 'System clock has been rolled back by '
            '${rollback.inMinutes} minutes.',
      );
    }

    await _recordLastKnown(localNow);
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<DateTime?> _fetchServerTime() async {
    try {
      final response = await http
          .get(Uri.parse(_timeUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Support both: { "utc": "2026-04-21T10:30:00Z" }
        // and:          { "server_time": "2026-04-21T10:30:00Z" }
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final raw = decoded['utc'] as String? ??
              decoded['server_time'] as String? ??
              decoded['time'] as String?;
          if (raw != null) return DateTime.tryParse(raw)?.toUtc();
        } catch (_) {
          // Fallback: regex parse
          final match =
              RegExp(r'"(?:utc|server_time|time)"\s*:\s*"([^"]+)"')
                  .firstMatch(response.body);
          if (match != null) {
            return DateTime.tryParse(match.group(1)!)?.toUtc();
          }
        }
      }
    } catch (e) {
      AppShieldLogger.d('Server time fetch failed (offline?): $e');
    }
    return null;
  }

  Future<void> _recordLastKnown(DateTime dt) async {
    await StorageService.instance.saveLastKnownTime(dt);
  }
}
