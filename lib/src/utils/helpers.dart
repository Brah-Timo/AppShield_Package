// lib/src/utils/helpers.dart

import 'dart:math';
import 'package:intl/intl.dart';
import 'constants.dart';

/// Utility helpers for AppShield.
class AppShieldHelpers {
  AppShieldHelpers._();

  // ── License key ───────────────────────────────────────────────────────────

  /// Returns true if [key] matches the XXXX-XXXX-XXXX-XXXX[-XXXX] format.
  static bool isValidLicenseKeyFormat(String key) {
    final pattern = RegExp(AppShieldConstants.licenseKeyPattern);
    return pattern.hasMatch(key.trim().toUpperCase());
  }

  /// Auto-formats a raw string as a license key (inserts dashes every 4 chars).
  static String formatLicenseKey(String raw) {
    final clean = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length && i < 20; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  /// Obfuscates a license key: XXXX-XXXX-XXXX-XXXX → ****-****-****-XXXX
  static String obfuscateLicenseKey(String key) {
    final parts = key.split('-');
    if (parts.length < 2) return '****';
    final visible = parts.last;
    final hidden =
        parts.sublist(0, parts.length - 1).map((_) => '****').join('-');
    return '$hidden-$visible';
  }

  // ── Date/time ─────────────────────────────────────────────────────────────

  static String formatDate(DateTime dt) =>
      DateFormat('MMM dd, yyyy').format(dt.toLocal());

  static String formatDateTime(DateTime dt) =>
      DateFormat('MMM dd, yyyy – HH:mm').format(dt.toLocal());

  static int daysUntil(DateTime date) =>
      date.difference(DateTime.now()).inDays;

  static bool isExpiringSoon(DateTime date, {int days = 7}) {
    final remaining = daysUntil(date);
    return remaining >= 0 && remaining <= days;
  }

  // ── String ────────────────────────────────────────────────────────────────

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  // ── Random ────────────────────────────────────────────────────────────────

  static String randomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }

  static String generateLicenseKey() {
    return List.generate(4, (_) => randomString(4))
        .join(AppShieldConstants.licenseKeyDelimiter);
  }

  // ── Debug mode ────────────────────────────────────────────────────────────

  static bool get isDebugMode {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }
}
