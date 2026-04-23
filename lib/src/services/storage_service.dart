// lib/src/services/storage_service.dart

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_log_entry.dart';
import '../models/license_model.dart';
import '../models/tamper_record.dart';
import '../core/encryption_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Handles all persistent storage for AppShield.
///
/// Strategy — three storage layers for resilience:
///   1. [FlutterSecureStorage]  — encrypted OS keychain/keystore (primary)
///   2. [SharedPreferences]     — plain prefs (secondary / backup key)
///   3. Encrypted blob in SharedPreferences (tertiary, tamper-visible)
class StorageService {
  StorageService._();

  static final StorageService _instance = StorageService._();
  static StorageService get instance => _instance;

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  late SharedPreferences _prefs;
  late String _passphrase; // derived from device+app secret
  bool _initialized = false;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize({required String passphrase}) async {
    if (_initialized) return;
    _prefs       = await SharedPreferences.getInstance();
    _passphrase  = passphrase;
    _initialized = true;
    AppShieldLogger.i('StorageService initialized.');
  }

  void _assertInit() {
    if (!_initialized) throw const AppShieldNotInitializedException();
  }

  // ── License ───────────────────────────────────────────────────────────────

  /// Saves [license] to all three storage layers.
  Future<void> saveLicense(License license) async {
    _assertInit();
    final json      = license.toJsonString();
    final encrypted = EncryptionService.instance.encrypt(json, _passphrase);

    // Layer 1 – secure storage
    await _secure.write(key: AppShieldConstants.storageKeyLicense, value: encrypted);

    // Layer 2 – prefs backup (encrypted blob)
    await _prefs.setString(AppShieldConstants.storageKeyBackupLicense, encrypted);

    // Layer 3 – integrity HMAC stored separately
    final hmac = EncryptionService.instance.generateHmac(encrypted, _passphrase);
    await _secure.write(key: '${AppShieldConstants.storageKeyLicense}_hmac', value: hmac);

    AppShieldLogger.i('License saved to all storage layers.');
  }

  /// Reads the license from storage.  Returns null if not found or tampered.
  Future<License?> readLicense() async {
    _assertInit();

    String? encrypted;
    bool    fromFallback = false;

    // Try layer 1 first
    encrypted = await _secure.read(key: AppShieldConstants.storageKeyLicense);

    // Fall back to layer 2
    if (encrypted == null || encrypted.isEmpty) {
      encrypted    = _prefs.getString(AppShieldConstants.storageKeyBackupLicense);
      fromFallback = true;
    }

    if (encrypted == null || encrypted.isEmpty) return null;

    // Verify HMAC integrity
    final storedHmac = await _secure.read(
        key: '${AppShieldConstants.storageKeyLicense}_hmac');
    if (storedHmac != null) {
      final valid = EncryptionService.instance
          .verifyHmac(encrypted, storedHmac, _passphrase);
      if (!valid) {
        AppShieldLogger.w('License HMAC mismatch — possible tampering!');
        await _markTamperFlag();
        return null;
      }
    }

    if (fromFallback) {
      AppShieldLogger.w('License read from fallback layer.');
    }

    final decrypted =
        EncryptionService.instance.decrypt(encrypted, _passphrase);
    if (decrypted == null) {
      AppShieldLogger.w('License decryption failed.');
      return null;
    }

    try {
      return License.fromJsonString(decrypted);
    } catch (e) {
      AppShieldLogger.e('License deserialization failed', error: e);
      return null;
    }
  }

  /// Removes the license from all storage layers.
  Future<void> deleteLicense() async {
    _assertInit();
    await _secure.delete(key: AppShieldConstants.storageKeyLicense);
    await _secure.delete(key: '${AppShieldConstants.storageKeyLicense}_hmac');
    await _prefs.remove(AppShieldConstants.storageKeyBackupLicense);
    AppShieldLogger.i('License deleted from all storage layers.');
  }

  // ── Device ID ─────────────────────────────────────────────────────────────

  Future<void> saveDeviceId(String deviceId) async {
    _assertInit();
    await _secure.write(
        key: AppShieldConstants.storageKeyDeviceId, value: deviceId);
  }

  Future<String?> readDeviceId() async {
    _assertInit();
    return _secure.read(key: AppShieldConstants.storageKeyDeviceId);
  }

  // ── Trial ─────────────────────────────────────────────────────────────────

  Future<void> saveTrialStart(DateTime startDate) async {
    _assertInit();
    await _secure.write(
        key:   AppShieldConstants.storageKeyTrialStart,
        value: startDate.toIso8601String());
    await _prefs.setBool(AppShieldConstants.storageKeyTrialUsed, true);
  }

  Future<DateTime?> readTrialStart() async {
    _assertInit();
    final raw = await _secure.read(
        key: AppShieldConstants.storageKeyTrialStart);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> isTrialUsed() async {
    _assertInit();
    // Check both layers
    final inPrefs  = _prefs.getBool(AppShieldConstants.storageKeyTrialUsed) ?? false;
    final inSecure = await _secure.read(
        key: AppShieldConstants.storageKeyTrialStart);
    return inPrefs || inSecure != null;
  }

  // ── Validation timestamps ─────────────────────────────────────────────────

  Future<void> saveLastValidationTime(DateTime dt) async {
    _assertInit();
    await _secure.write(
        key:   AppShieldConstants.storageKeyLastValidation,
        value: dt.toIso8601String());
  }

  Future<DateTime?> readLastValidationTime() async {
    _assertInit();
    final raw = await _secure.read(
        key: AppShieldConstants.storageKeyLastValidation);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Clock / last known time ───────────────────────────────────────────────

  Future<void> saveLastKnownTime(DateTime dt) async {
    _assertInit();
    await _secure.write(
        key:   AppShieldConstants.storageKeyLastKnownTime,
        value: dt.toIso8601String());
  }

  Future<DateTime?> readLastKnownTime() async {
    _assertInit();
    final raw = await _secure.read(
        key: AppShieldConstants.storageKeyLastKnownTime);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // ── Grace period ──────────────────────────────────────────────────────────

  Future<void> saveGraceStart(DateTime dt) async {
    _assertInit();
    await _secure.write(
        key:   AppShieldConstants.storageKeyGraceStart,
        value: dt.toIso8601String());
  }

  Future<DateTime?> readGraceStart() async {
    _assertInit();
    final raw = await _secure.read(
        key: AppShieldConstants.storageKeyGraceStart);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> deleteGraceStart() async {
    _assertInit();
    await _secure.delete(key: AppShieldConstants.storageKeyGraceStart);
  }

  // ── Tamper flag ───────────────────────────────────────────────────────────

  Future<void> _markTamperFlag() async {
    await _prefs.setBool(AppShieldConstants.storageKeyTamperFlag, true);
  }

  Future<bool> isTamperFlagSet() async {
    _assertInit();
    return _prefs.getBool(AppShieldConstants.storageKeyTamperFlag) ?? false;
  }

  Future<void> clearTamperFlag() async {
    _assertInit();
    await _prefs.remove(AppShieldConstants.storageKeyTamperFlag);
  }

  // ── Activity log ──────────────────────────────────────────────────────────

  Future<void> appendActivityLog(ActivityLogEntry entry) async {
    _assertInit();
    final raw      = _prefs.getString(AppShieldConstants.storageKeyActivityLog);
    final existing = raw != null ? ActivityLogEntry.listFromJson(raw) : <ActivityLogEntry>[];
    existing.add(entry);

    // Keep last 200 entries
    final trimmed = existing.length > 200
        ? existing.sublist(existing.length - 200)
        : existing;

    await _prefs.setString(
        AppShieldConstants.storageKeyActivityLog,
        ActivityLogEntry.listToJson(trimmed));
  }

  Future<List<ActivityLogEntry>> readActivityLog() async {
    _assertInit();
    final raw = _prefs.getString(AppShieldConstants.storageKeyActivityLog);
    if (raw == null) return [];
    try {
      return ActivityLogEntry.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> clearActivityLog() async {
    _assertInit();
    await _prefs.remove(AppShieldConstants.storageKeyActivityLog);
  }

  // ── Generic key-value ─────────────────────────────────────────────────────

  Future<void> writeSecure(String key, String value) async {
    _assertInit();
    await _secure.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    _assertInit();
    return _secure.read(key: key);
  }

  Future<void> deleteSecure(String key) async {
    _assertInit();
    await _secure.delete(key: key);
  }

  // ── Full wipe ─────────────────────────────────────────────────────────────

  /// Wipes all AppShield data from all storage layers.
  Future<void> wipeAll() async {
    _assertInit();
    await _secure.deleteAll();
    final keys = _prefs.getKeys()
        .where((k) => k.startsWith('as_'))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
    AppShieldLogger.w('All AppShield storage wiped.');
  }
}
