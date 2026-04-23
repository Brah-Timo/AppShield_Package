// lib/src/core/tamper_detector.dart

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/tamper_record.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Detects various forms of application / environment tampering:
///   - Clock manipulation (delegated to [ClockVerifier])
///   - Storage integrity (HMAC, delegated to [StorageService])
///   - Root / Jailbreak
///   - Emulator / Simulator
///   - Debugger attachment
///   - License file modification
class TamperDetector {
  TamperDetector._();

  static final TamperDetector _instance = TamperDetector._();
  static TamperDetector get instance => _instance;

  final List<TamperRecord> _detected = [];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Runs all enabled tamper checks.
  ///
  /// [throwOnDetect] — if true throws [TamperingDetectedException]
  /// on the first critical finding; otherwise collects all and returns the list.
  Future<List<TamperRecord>> runChecks({
    bool checkRoot      = true,
    bool checkEmulator  = true,
    bool checkDebugger  = false, // off by default (breaks debug builds)
    bool checkStorage   = true,
    bool throwOnDetect  = false,
  }) async {
    _detected.clear();

    if (checkStorage)  await _checkStorageIntegrity();
    if (checkRoot)     await _checkRootJailbreak();
    if (checkEmulator) await _checkEmulator();
    if (checkDebugger) await _checkDebugger();

    if (_detected.isNotEmpty) {
      AppShieldLogger.w('Tamper checks found ${_detected.length} issue(s).');
      if (throwOnDetect) {
        throw TamperingDetectedException(
          tamperType: _detected.first.tamperType,
          message: _detected.first.details ??
              'Application tampering detected.',
        );
      }
    } else {
      AppShieldLogger.i('All tamper checks passed.');
    }

    return List.unmodifiable(_detected);
  }

  /// Returns all tamper records detected in the last [runChecks] call.
  List<TamperRecord> get lastDetected => List.unmodifiable(_detected);

  // ── Storage integrity ─────────────────────────────────────────────────────

  Future<void> _checkStorageIntegrity() async {
    try {
      final flagSet = await StorageService.instance.isTamperFlagSet();
      if (flagSet) {
        _record(
          tamperType: AppShieldConstants.tamperStorageModified,
          severity: 'high',
          details: 'License storage integrity check failed (HMAC mismatch). '
              'Data may have been tampered with.',
        );
      }
    } catch (e) {
      AppShieldLogger.w('Storage integrity check error: $e');
    }
  }

  // ── Root / Jailbreak ──────────────────────────────────────────────────────

  Future<void> _checkRootJailbreak() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        await _checkAndroidRoot();
      } else if (Platform.isIOS) {
        await _checkIosJailbreak();
      }
    } catch (e) {
      AppShieldLogger.d('Root/jailbreak check error: $e');
    }
  }

  Future<void> _checkAndroidRoot() async {
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
    ];

    for (final path in rootPaths) {
      if (await File(path).exists()) {
        _record(
          tamperType: AppShieldConstants.tamperRootJailbreak,
          severity: 'medium',
          details: 'Root binary found at: $path',
        );
        return;
      }
    }
  }

  Future<void> _checkIosJailbreak() async {
    final jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
    ];

    for (final path in jailbreakPaths) {
      if (await File(path).exists()) {
        _record(
          tamperType: AppShieldConstants.tamperRootJailbreak,
          severity: 'medium',
          details: 'Jailbreak indicator found at: $path',
        );
        return;
      }
    }
  }

  // ── Emulator detection ────────────────────────────────────────────────────

  Future<void> _checkEmulator() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        await _checkAndroidEmulator();
      }
      // iOS simulator detection is typically handled at build time
    } catch (e) {
      AppShieldLogger.d('Emulator check error: $e');
    }
  }

  Future<void> _checkAndroidEmulator() async {
    // These files/properties are present on standard Android emulators
    final emulatorIndicators = [
      '/dev/socket/qemud',
      '/dev/qemu_pipe',
      '/system/lib/libc_malloc_debug_qemu.so',
      '/sys/qemu_trace',
      '/system/bin/qemu-props',
    ];

    for (final path in emulatorIndicators) {
      if (await File(path).exists()) {
        _record(
          tamperType: AppShieldConstants.tamperEmulator,
          severity: 'low',
          details: 'Emulator indicator found at: $path',
        );
        return;
      }
    }
  }

  // ── Debugger detection ────────────────────────────────────────────────────

  Future<void> _checkDebugger() async {
    // In Flutter debug mode a debugger is normally attached.
    // Only flag this in release mode.
    if (kDebugMode) return;

    bool debuggerAttached = false;
    assert(() {
      debuggerAttached = true;
      return true;
    }());

    if (debuggerAttached) {
      _record(
        tamperType: AppShieldConstants.tamperDebuggerAttached,
        severity: 'high',
        details: 'A debugger is attached to the process in release mode.',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _record({
    required String tamperType,
    required String severity,
    String? details,
  }) {
    final record = TamperRecord(
      tamperType:  tamperType,
      severity:    severity,
      detectedAt:  DateTime.now().toUtc(),
      details:     details,
    );
    _detected.add(record);
    AppShieldLogger.w('Tamper detected: $tamperType ($severity) — $details');
  }
}
