// lib/src/core/device_fingerprint.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/device_model.dart';
import '../utils/exceptions.dart';
import '../utils/logger.dart';

/// Generates a stable, platform-specific device fingerprint used
/// to bind licenses to a particular machine or device.
class DeviceFingerprintService {
  DeviceFingerprintService._();

  static final DeviceFingerprintService _instance =
      DeviceFingerprintService._();
  static DeviceFingerprintService get instance => _instance;

  final DeviceInfoPlugin _deviceInfo  = DeviceInfoPlugin();
  final NetworkInfo      _networkInfo = NetworkInfo();

  DeviceInfo? _cachedInfo;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns (and caches) the current [DeviceInfo].
  Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedInfo != null) return _cachedInfo!;
    try {
      _cachedInfo = await _build();
      return _cachedInfo!;
    } catch (e, st) {
      AppShieldLogger.e('Failed to get device info', error: e, stackTrace: st);
      throw const DeviceFingerprintException();
    }
  }

  /// Returns only the fingerprint string.
  Future<String> getFingerprint() async =>
      (await getDeviceInfo()).fingerprint;

  /// Clears the cached device info (useful for testing).
  void clearCache() => _cachedInfo = null;

  // ── Platform routing ──────────────────────────────────────────────────────

  Future<DeviceInfo> _build() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion  = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (kIsWeb)             return _buildWeb(appVersion);
    if (Platform.isWindows) return _buildWindows(appVersion);
    if (Platform.isMacOS)   return _buildMacOS(appVersion);
    if (Platform.isLinux)   return _buildLinux(appVersion);
    if (Platform.isAndroid) return _buildAndroid(appVersion);
    if (Platform.isIOS)     return _buildIOS(appVersion);
    throw const DeviceFingerprintException(
        'Unsupported platform for device fingerprinting.');
  }

  // ── Windows ───────────────────────────────────────────────────────────────

  Future<DeviceInfo> _buildWindows(String appVersion) async {
    final info = await _deviceInfo.windowsInfo;

    final components = <String, String>{
      'hostname':     info.computerName,
      'os_version':   '${info.majorVersion}.${info.minorVersion}.'
                      '${info.buildNumber}',
      'device_id':    info.deviceId,
      'product_name': info.productName,
    };

    final macAddress = await _tryGetMacAddress();
    if (macAddress != null) components['mac'] = macAddress;

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.windows,
      hostname:      info.computerName,
      osVersion:     info.productName,
      hardwareUuid:  info.deviceId,
      macAddress:    macAddress,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── macOS ─────────────────────────────────────────────────────────────────

  Future<DeviceInfo> _buildMacOS(String appVersion) async {
    final info = await _deviceInfo.macOsInfo;

    final components = <String, String>{
      'hostname':       info.hostName,
      'os_version':     info.osRelease,
      'model':          info.model,
      'kernel_version': info.kernelVersion,
      'hardware_uuid':  info.systemGUID ?? '',
    };

    final macAddress = await _tryGetMacAddress();
    if (macAddress != null) components['mac'] = macAddress;

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.macos,
      hostname:      info.hostName,
      osVersion:     info.osRelease,
      hardwareUuid:  info.systemGUID,
      macAddress:    macAddress,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── Linux ─────────────────────────────────────────────────────────────────
  // NOTE: LinuxDeviceInfo (device_info_plus >=11.x) does NOT expose a
  //       'hostname' property. The OS name is in info.name / info.prettyName.
  //       We obtain the actual hostname via dart:io Platform.localHostname,
  //       and fall back to info.machineId when available.

  Future<DeviceInfo> _buildLinux(String appVersion) async {
    final info = await _deviceInfo.linuxInfo;

    // dart:io gives us the real hostname on Linux.
    String hostname;
    try {
      hostname = Platform.localHostname;
    } catch (_) {
      hostname = info.name; // OS name as fallback
    }

    // device_info_plus 11.x exposes machineId directly on LinuxDeviceInfo.
    final machineId = info.machineId;

    final components = <String, String>{
      'hostname':   hostname,
      'os_id':      info.id,
      'os_version': info.version ?? '',
      'machine_id': machineId ?? '',
    };

    final macAddress = await _tryGetMacAddress();
    if (macAddress != null) components['mac'] = macAddress;

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.linux,
      hostname:      hostname,
      osVersion:     info.prettyName,
      hardwareUuid:  machineId,
      macAddress:    macAddress,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── Android ───────────────────────────────────────────────────────────────

  Future<DeviceInfo> _buildAndroid(String appVersion) async {
    final info = await _deviceInfo.androidInfo;

    final components = <String, String>{
      'android_id':  info.id,
      'model':       info.model,
      'brand':       info.brand,
      'device':      info.device,
      'fingerprint': info.fingerprint,
      'hardware':    info.hardware,
      'serial':      info.serialNumber,
      'sdk':         info.version.sdkInt.toString(),
    };

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.android,
      hostname:      info.host,
      osVersion:     'Android ${info.version.release}',
      diskSerial:    info.serialNumber,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── iOS ───────────────────────────────────────────────────────────────────

  Future<DeviceInfo> _buildIOS(String appVersion) async {
    final info = await _deviceInfo.iosInfo;

    final components = <String, String>{
      'identifier_for_vendor': info.identifierForVendor ?? '',
      'model':                 info.model,
      'name':                  info.name,
      'system_version':        info.systemVersion,
      'utsname_machine':       info.utsname.machine,
    };

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.ios,
      hostname:      info.name,
      osVersion:     'iOS ${info.systemVersion}',
      hardwareUuid:  info.identifierForVendor,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── Web ───────────────────────────────────────────────────────────────────

  Future<DeviceInfo> _buildWeb(String appVersion) async {
    final info = await _deviceInfo.webBrowserInfo;

    final components = <String, String>{
      'browser_name':        info.browserName.name,
      'user_agent':          info.userAgent ?? '',
      'language':            info.language  ?? '',
      'platform':            info.platform  ?? '',
      'hardware_concurrency': info.hardwareConcurrency?.toString() ?? '',
    };

    // Add a stable random seed stored in localStorage if available,
    // to give some device stability on web.
    components['web_seed'] = _webSeed();

    final fingerprint = _computeFingerprint(components);

    return DeviceInfo(
      fingerprint:   fingerprint,
      platform:      DevicePlatform.web,
      osVersion:     info.userAgent,
      appVersion:    appVersion,
      rawComponents: components,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Computes a XXXX-XXXX-XXXX-XXXX fingerprint from a map of components.
  String _computeFingerprint(Map<String, String> components) {
    final sortedKeys = components.keys.toList()..sort();
    final raw  = sortedKeys.map((k) => '$k=${components[k]}').join('|');
    final hash = sha256.convert(utf8.encode(raw)).toString();
    // Take first 16 hex chars and split into groups of 4
    final h = hash.substring(0, 16).toUpperCase();
    return '${h.substring(0, 4)}-${h.substring(4, 8)}-'
           '${h.substring(8, 12)}-${h.substring(12, 16)}';
  }

  Future<String?> _tryGetMacAddress() async {
    try {
      return await _networkInfo.getWifiBSSID();
    } catch (_) {
      return null;
    }
  }

  /// Returns a stable per-session web seed (best-effort for web platform).
  String _webSeed() {
    // On web we generate a session-stable random string.
    // For true persistence, integrate with localStorage via js interop.
    return Random.secure().nextInt(0xFFFFFF).toRadixString(16).toUpperCase();
  }

  /// Compares two fingerprints. Returns true if they match.
  bool compareFingerprints(String a, String b) =>
      a.trim().toUpperCase() == b.trim().toUpperCase();
}
