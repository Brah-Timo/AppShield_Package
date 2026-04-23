// lib/src/models/device_model.dart

import 'dart:convert';

enum DevicePlatform { windows, macos, linux, android, ios, web, unknown }

class DeviceInfo {
  const DeviceInfo({
    required this.fingerprint,
    required this.platform,
    this.hostname,
    this.osVersion,
    this.cpuId,
    this.macAddress,
    this.diskSerial,
    this.hardwareUuid,
    this.installationId,
    this.appVersion,
    this.rawComponents = const {},
  });

  final String         fingerprint;
  final DevicePlatform platform;
  final String?        hostname;
  final String?        osVersion;
  final String?        cpuId;
  final String?        macAddress;
  final String?        diskSerial;
  final String?        hardwareUuid;
  final String?        installationId;
  final String?        appVersion;
  final Map<String, String> rawComponents;

  Map<String, dynamic> toJson() => {
        'fingerprint':     fingerprint,
        'platform':        platform.name,
        'hostname':        hostname,
        'os_version':      osVersion,
        'cpu_id':          cpuId,
        'mac_address':     macAddress,
        'disk_serial':     diskSerial,
        'hardware_uuid':   hardwareUuid,
        'installation_id': installationId,
        'app_version':     appVersion,
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        fingerprint:    json['fingerprint']     as String,
        platform:       DevicePlatform.values.byName(
                            json['platform'] as String? ?? 'unknown'),
        hostname:       json['hostname']        as String?,
        osVersion:      json['os_version']      as String?,
        cpuId:          json['cpu_id']          as String?,
        macAddress:     json['mac_address']     as String?,
        diskSerial:     json['disk_serial']     as String?,
        hardwareUuid:   json['hardware_uuid']   as String?,
        installationId: json['installation_id'] as String?,
        appVersion:     json['app_version']     as String?,
      );

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() =>
      'DeviceInfo(fingerprint: $fingerprint, platform: $platform)';
}
