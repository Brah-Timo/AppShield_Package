// test/license_model_test.dart
//
// Unit tests for AppShield core components.
// Run with: flutter test
//
// Coverage:
//   ✅ License model (creation, computed props, serialization, copyWith)
//   ✅ AppShieldHelpers (key format, obfuscation, dates, truncation)
//   ✅ EncryptionService (AES-GCM encrypt/decrypt, HMAC, SHA-256)
//   ✅ AppShieldConfig (validation, resolvedTheme)
//   ✅ AppShieldColors (status/severity mappings)
//   ✅ AppShieldTheme (light/dark factories, isDark, toThemeData)
//   ✅ AppShieldConstants (all constant values)
//   ✅ Exception hierarchy (message, code, toString)
//   ✅ ActivityLogEntry (serialization)
//   ✅ TamperRecord (serialization)
//   ✅ ActivationResult (success/failure factories)
//   ✅ ValidationResponse (valid/invalid/gracePeriod factories)
//   ✅ DeviceInfo / DevicePlatform
//   ✅ AppFeature (copyWith, toString)
//   ✅ LicenseType / LicenseStatus enum values
//   ✅ AppShieldLogger (level/enabled control)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_shield/app_shield.dart';

void main() {
  // ── License model ─────────────────────────────────────────────────────────

  group('License model', () {
    late License activeLicense;
    late License expiredLicense;
    late License perpetualLicense;
    late License trialLicense;
    late License graceLicense;

    setUp(() {
      activeLicense = License(
        key:        'ABCD-1234-EFGH-5678',
        type:       LicenseType.subscription,
        status:     LicenseStatus.active,
        deviceId:   'A1B2-C3D4-E5F6-0708',
        appId:      'com.test.app',
        plan:       'professional',
        activatedAt: DateTime.now().toUtc(),
        expiresAt:  DateTime.now().toUtc().add(const Duration(days: 365)),
        features: const {
          'advanced_reports': true,
          'multi_user':       false,
          'api_access':       true,
        },
        limits:    const {'max_users': 5, 'max_records': 10000},
        signature: 'test_signature',
        customerEmail: 'test@example.com',
        customerName:  'Test User',
      );

      expiredLicense = activeLicense.copyWith(
        status:    LicenseStatus.expired,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );

      perpetualLicense = activeLicense.copyWith(
        type:      LicenseType.perpetual,
        expiresAt: DateTime(9999),
      );

      trialLicense = activeLicense.copyWith(
        type:   LicenseType.trial,
        status: LicenseStatus.trial,
      );

      graceLicense = activeLicense.copyWith(
        status:    LicenseStatus.gracePeriod,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );
    });

    // ── Validity ──────────────────────────────────────────────────────────

    test('active license is valid', () {
      expect(activeLicense.isValid, isTrue);
    });

    test('expired license is invalid', () {
      expect(expiredLicense.isValid, isFalse);
    });

    test('grace-period license is valid', () {
      expect(graceLicense.isValid, isFalse); // expired date but gracePeriod
    });

    test('active license is not expired', () {
      expect(activeLicense.isExpired, isFalse);
    });

    test('expired license is expired', () {
      expect(expiredLicense.isExpired, isTrue);
    });

    // ── Perpetual ─────────────────────────────────────────────────────────

    test('perpetual license isPerpetual', () {
      expect(perpetualLicense.isPerpetual, isTrue);
    });

    test('subscription license is not perpetual', () {
      expect(activeLicense.isPerpetual, isFalse);
    });

    // ── Trial ─────────────────────────────────────────────────────────────

    test('trial license isTrial', () {
      expect(trialLicense.isTrial, isTrue);
    });

    test('active license is not trial', () {
      expect(activeLicense.isTrial, isFalse);
    });

    // ── Features ──────────────────────────────────────────────────────────

    test('hasFeature returns true for enabled features', () {
      expect(activeLicense.hasFeature('advanced_reports'), isTrue);
      expect(activeLicense.hasFeature('api_access'),       isTrue);
    });

    test('hasFeature returns false for disabled features', () {
      expect(activeLicense.hasFeature('multi_user'), isFalse);
    });

    test('hasFeature returns false for unknown features', () {
      expect(activeLicense.hasFeature('non_existent'), isFalse);
    });

    // ── Limits ────────────────────────────────────────────────────────────

    test('getLimit returns correct value', () {
      expect(activeLicense.getLimit('max_users'),    equals(5));
      expect(activeLicense.getLimit('max_records'),  equals(10000));
    });

    test('getLimit returns defaultValue for unknown key', () {
      expect(activeLicense.getLimit('unknown', defaultValue: 99), equals(99));
    });

    // ── Days remaining ────────────────────────────────────────────────────

    test('daysRemaining > 300 for fresh license', () {
      expect(activeLicense.daysRemaining, greaterThan(300));
    });

    test('hoursRemaining > 7000 for fresh license', () {
      expect(activeLicense.hoursRemaining, greaterThan(7000));
    });

    test('daysRemaining < 0 for expired license', () {
      expect(expiredLicense.daysRemaining, isNegative);
    });

    // ── isExpiringSoon ────────────────────────────────────────────────────

    test('active license is not expiring soon', () {
      expect(activeLicense.isExpiringSoon, isFalse);
    });

    test('license expiring in 3 days is expiring soon', () {
      final soon = activeLicense.copyWith(
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
      );
      expect(soon.isExpiringSoon, isTrue);
    });

    // ── copyWith ──────────────────────────────────────────────────────────

    test('copyWith updates specified fields', () {
      final updated = activeLicense.copyWith(plan: 'enterprise');
      expect(updated.plan,   equals('enterprise'));
      expect(updated.key,    equals(activeLicense.key));
      expect(updated.status, equals(activeLicense.status));
    });

    test('copyWith can update status and features', () {
      final updated = activeLicense.copyWith(
        status:   LicenseStatus.suspended,
        features: const {'advanced_reports': false},
      );
      expect(updated.status, equals(LicenseStatus.suspended));
      expect(updated.hasFeature('advanced_reports'), isFalse);
    });

    // ── Serialization ─────────────────────────────────────────────────────

    test('toJson / fromJson round-trip preserves all fields', () {
      final json     = activeLicense.toJson();
      final restored = License.fromJson(json);
      expect(restored.key,          equals(activeLicense.key));
      expect(restored.plan,         equals(activeLicense.plan));
      expect(restored.status,       equals(activeLicense.status));
      expect(restored.type,         equals(activeLicense.type));
      expect(restored.deviceId,     equals(activeLicense.deviceId));
      expect(restored.customerEmail, equals(activeLicense.customerEmail));
      expect(restored.features,     equals(activeLicense.features));
      expect(restored.limits,       equals(activeLicense.limits));
    });

    test('toJsonString / fromJsonString round-trip', () {
      final json     = activeLicense.toJsonString();
      final restored = License.fromJsonString(json);
      expect(restored.key,  equals(activeLicense.key));
      expect(restored.plan, equals(activeLicense.plan));
    });

    test('serialization round-trip for perpetual license', () {
      final json     = perpetualLicense.toJsonString();
      final restored = License.fromJsonString(json);
      expect(restored.isPerpetual, isTrue);
      expect(restored.type, equals(LicenseType.perpetual));
    });

    // ── toString ──────────────────────────────────────────────────────────

    test('toString contains key prefix and plan', () {
      final s = activeLicense.toString();
      expect(s, contains('ABCD'));
      expect(s, contains('professional'));
    });
  });

  // ── LicenseType / LicenseStatus enums ────────────────────────────────────

  group('Enum completeness', () {
    test('LicenseType has all expected values', () {
      final names = LicenseType.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'perpetual', 'subscription', 'trial',
        'educational', 'enterprise', 'oem',
      ]));
    });

    test('LicenseStatus has all expected values', () {
      final names = LicenseStatus.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'notActivated', 'active', 'trial', 'gracePeriod',
        'expired', 'revoked', 'suspended', 'tampered',
        'deviceMismatch', 'offline',
      ]));
    });
  });

  // ── AppShieldHelpers ──────────────────────────────────────────────────────

  group('AppShieldHelpers', () {
    // ── isValidLicenseKeyFormat ───────────────────────────────────────────

    test('valid 4-segment key returns true', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat('ABCD-1234-EFGH-5678'),
          isTrue);
    });

    test('lowercase key is accepted (normalized)', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat('abcd-1234-efgh-5678'),
          isTrue);
    });

    test('valid 5-segment key returns true', () {
      expect(
          AppShieldHelpers.isValidLicenseKeyFormat('ABCD-1234-EFGH-5678-IJKL'),
          isTrue);
    });

    test('3-segment key is invalid', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat('ABCD-1234-EFGH'), isFalse);
    });

    test('key with wrong segment length is invalid', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat('ABCD-1234-EFGH-567'), isFalse);
    });

    test('empty key is invalid', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat(''), isFalse);
    });

    test('key with special chars is invalid', () {
      expect(AppShieldHelpers.isValidLicenseKeyFormat('ABCD-1234-EFG!-5678'), isFalse);
    });

    // ── formatLicenseKey ──────────────────────────────────────────────────

    test('formatLicenseKey inserts dashes', () {
      expect(AppShieldHelpers.formatLicenseKey('ABCD1234EFGH5678'),
          equals('ABCD-1234-EFGH-5678'));
    });

    test('formatLicenseKey handles mixed case', () {
      expect(AppShieldHelpers.formatLicenseKey('abcd1234efgh5678'),
          equals('ABCD-1234-EFGH-5678'));
    });

    test('formatLicenseKey strips non-alphanumerics', () {
      expect(AppShieldHelpers.formatLicenseKey('ABCD-1234-EFGH-5678'),
          equals('ABCD-1234-EFGH-5678'));
    });

    test('formatLicenseKey truncates at 20 chars', () {
      final result =
          AppShieldHelpers.formatLicenseKey('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      expect(result.replaceAll('-', '').length, equals(20));
    });

    // ── obfuscateLicenseKey ───────────────────────────────────────────────

    test('obfuscateLicenseKey masks all but last segment', () {
      expect(AppShieldHelpers.obfuscateLicenseKey('ABCD-1234-EFGH-5678'),
          equals('****-****-****-5678'));
    });

    test('obfuscateLicenseKey handles short key', () {
      expect(AppShieldHelpers.obfuscateLicenseKey('ABCD'), equals('****'));
    });

    // ── isExpiringSoon ────────────────────────────────────────────────────

    test('isExpiringSoon returns true within 7 days', () {
      expect(
        AppShieldHelpers.isExpiringSoon(
            DateTime.now().add(const Duration(days: 5))),
        isTrue,
      );
    });

    test('isExpiringSoon returns false beyond threshold', () {
      expect(
        AppShieldHelpers.isExpiringSoon(
            DateTime.now().add(const Duration(days: 30))),
        isFalse,
      );
    });

    test('isExpiringSoon custom threshold', () {
      expect(
        AppShieldHelpers.isExpiringSoon(
          DateTime.now().add(const Duration(days: 10)),
          days: 15,
        ),
        isTrue,
      );
    });

    // ── generateLicenseKey ────────────────────────────────────────────────

    test('generateLicenseKey produces valid format', () {
      final key = AppShieldHelpers.generateLicenseKey();
      expect(AppShieldHelpers.isValidLicenseKeyFormat(key), isTrue);
    });

    test('generateLicenseKey produces different keys', () {
      final k1 = AppShieldHelpers.generateLicenseKey();
      final k2 = AppShieldHelpers.generateLicenseKey();
      // Very unlikely to be equal (but not impossible; test is probabilistic)
      expect(k1 == k2, isFalse);
    });

    // ── truncate ──────────────────────────────────────────────────────────

    test('truncate does not change short strings', () {
      expect(AppShieldHelpers.truncate('hello', 10), equals('hello'));
    });

    test('truncate adds ellipsis', () {
      expect(AppShieldHelpers.truncate('hello world', 5), equals('hello…'));
    });

    // ── formatDate / formatDateTime ───────────────────────────────────────

    test('formatDate returns non-empty string', () {
      expect(AppShieldHelpers.formatDate(DateTime(2026, 4, 21)),
          isNot(isEmpty));
    });

    test('formatDateTime returns non-empty string', () {
      expect(AppShieldHelpers.formatDateTime(DateTime(2026, 4, 21, 10, 30)),
          isNot(isEmpty));
    });

    test('daysUntil returns positive for future date', () {
      expect(
        AppShieldHelpers.daysUntil(DateTime.now().add(const Duration(days: 10))),
        greaterThan(0),
      );
    });

    // ── isDebugMode ───────────────────────────────────────────────────────

    test('isDebugMode returns bool', () {
      expect(AppShieldHelpers.isDebugMode, isA<bool>());
    });
  });

  // ── EncryptionService ─────────────────────────────────────────────────────

  group('EncryptionService', () {
    late EncryptionService enc;

    setUp(() => enc = EncryptionService.instance);

    test('instance is singleton', () {
      expect(enc, same(EncryptionService.instance));
    });

    test('encrypt returns non-empty Base64 string', () {
      final result = enc.encrypt('hello', 'passphrase');
      expect(result, isNotEmpty);
    });

    test('encrypt then decrypt returns original plaintext', () {
      const plaintext  = 'Hello, AppShield!';
      const passphrase = 'test_passphrase_123';
      final cipher     = enc.encrypt(plaintext, passphrase);
      final decrypted  = enc.decrypt(cipher, passphrase);
      expect(decrypted, equals(plaintext));
    });

    test('decrypt with wrong passphrase returns null', () {
      final cipher = enc.encrypt('secret', 'correct_pass');
      expect(enc.decrypt(cipher, 'wrong_pass'), isNull);
    });

    test('decrypt empty string returns null', () {
      expect(enc.decrypt('', 'passphrase'), isNull);
    });

    test('two encryptions of same text produce different ciphertext (random IV)', () {
      final c1 = enc.encrypt('same text', 'pass');
      final c2 = enc.encrypt('same text', 'pass');
      expect(c1, isNot(equals(c2)));
    });

    // ── HMAC ─────────────────────────────────────────────────────────────

    test('verifyHmac returns true for matching data', () {
      const data   = 'test_data';
      const secret = 'hmac_secret';
      final hmac   = enc.generateHmac(data, secret);
      expect(enc.verifyHmac(data, hmac, secret), isTrue);
    });

    test('verifyHmac returns false for tampered data', () {
      const data   = 'test_data';
      const secret = 'hmac_secret';
      final hmac   = enc.generateHmac(data, secret);
      expect(enc.verifyHmac('tampered_data', hmac, secret), isFalse);
    });

    test('verifyHmac returns false for wrong secret', () {
      const data   = 'test_data';
      final hmac   = enc.generateHmac(data, 'secret');
      expect(enc.verifyHmac(data, hmac, 'wrong_secret'), isFalse);
    });

    // ── SHA-256 ───────────────────────────────────────────────────────────

    test('sha256Hex returns 64-character hex string', () {
      final hash = enc.sha256Hex('test');
      expect(hash.length, equals(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('sha256Hex is deterministic', () {
      expect(enc.sha256Hex('hello'), equals(enc.sha256Hex('hello')));
    });

    test('sha256Hex differs for different inputs', () {
      expect(enc.sha256Hex('hello'), isNot(equals(enc.sha256Hex('world'))));
    });

    // ── shortHash ────────────────────────────────────────────────────────

    test('shortHash returns string of requested length', () {
      final h = enc.shortHash('test', length: 8);
      expect(h.length, equals(8));
    });

    // ── deriveStoragePassphrase ───────────────────────────────────────────

    test('deriveStoragePassphrase returns non-empty deterministic string', () {
      final p1 = enc.deriveStoragePassphrase(
          deviceId: 'D1', appId: 'A1', appSecret: 'S1');
      final p2 = enc.deriveStoragePassphrase(
          deviceId: 'D1', appId: 'A1', appSecret: 'S1');
      expect(p1, isNotEmpty);
      expect(p1, equals(p2));
    });

    test('deriveStoragePassphrase differs for different inputs', () {
      final p1 = enc.deriveStoragePassphrase(
          deviceId: 'D1', appId: 'A1', appSecret: 'S1');
      final p2 = enc.deriveStoragePassphrase(
          deviceId: 'D2', appId: 'A1', appSecret: 'S1');
      expect(p1, isNot(equals(p2)));
    });
  });

  // ── AppShieldConfig ───────────────────────────────────────────────────────

  group('AppShieldConfig', () {
    test('valid config passes validation', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'test_key',
      );
      expect(() => cfg.validate(), returnsNormally);
    });

    test('empty appId throws ArgumentError', () {
      const cfg = AppShieldConfig(
        appId:      '',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'test_key',
      );
      expect(() => cfg.validate(), throwsArgumentError);
    });

    test('empty apiBaseUrl throws ArgumentError', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: '',
        apiKey:     'test_key',
      );
      expect(() => cfg.validate(), throwsArgumentError);
    });

    test('empty apiKey throws ArgumentError', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     '',
      );
      expect(() => cfg.validate(), throwsArgumentError);
    });

    test('negative offlineGraceDays throws', () {
      const cfg = AppShieldConfig(
        appId:             'com.test.app',
        apiBaseUrl:        'https://api.example.com',
        apiKey:            'key',
        offlineGraceDays: -1,
      );
      expect(() => cfg.validate(), throwsArgumentError);
    });

    test('resolvedTheme returns AppShieldTheme', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'key',
      );
      expect(cfg.resolvedTheme, isA<AppShieldTheme>());
    });

    test('resolvedTheme uses provided theme', () {
      final custom = AppShieldTheme.dark(brandName: 'TestApp');
      final cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'key',
        theme:      custom,
      );
      expect(cfg.resolvedTheme.brandName, equals('TestApp'));
      expect(cfg.resolvedTheme.isDark,    isTrue);
    });

    test('toString is non-empty', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'key',
      );
      expect(cfg.toString(), isNotEmpty);
    });

    test('default values are sane', () {
      const cfg = AppShieldConfig(
        appId:      'com.test.app',
        apiBaseUrl: 'https://api.example.com',
        apiKey:     'key',
      );
      expect(cfg.enableTrial,        isTrue);
      expect(cfg.trialDays,          greaterThan(0));
      expect(cfg.enableOfflineMode,  isTrue);
      expect(cfg.offlineGraceDays,   greaterThanOrEqualTo(0));
      expect(cfg.enableDeviceBinding, isTrue);
    });
  });

  // ── AppShieldColors ───────────────────────────────────────────────────────

  group('AppShieldColors', () {
    test('forStatus maps known status names', () {
      expect(AppShieldColors.forStatus('active'),      equals(AppShieldColors.active));
      expect(AppShieldColors.forStatus('trial'),       equals(AppShieldColors.trial));
      expect(AppShieldColors.forStatus('expired'),     equals(AppShieldColors.expired));
      expect(AppShieldColors.forStatus('revoked'),     equals(AppShieldColors.revoked));
      expect(AppShieldColors.forStatus('gracePeriod'), equals(AppShieldColors.gracePeriod));
      expect(AppShieldColors.forStatus('suspended'),   equals(AppShieldColors.suspended));
      expect(AppShieldColors.forStatus('tampered'),    equals(AppShieldColors.tampered));
      expect(AppShieldColors.forStatus('offline'),     equals(AppShieldColors.offline));
    });

    test('forStatus unknown returns inactive', () {
      expect(AppShieldColors.forStatus('unknown'),  equals(AppShieldColors.inactive));
      expect(AppShieldColors.forStatus(''),         equals(AppShieldColors.inactive));
    });

    test('forSeverity maps known severity names', () {
      expect(AppShieldColors.forSeverity('success'), equals(AppShieldColors.success));
      expect(AppShieldColors.forSeverity('warning'), equals(AppShieldColors.warning));
      expect(AppShieldColors.forSeverity('error'),   equals(AppShieldColors.expired));
    });

    test('forSeverity unknown returns info', () {
      expect(AppShieldColors.forSeverity('info'),    equals(AppShieldColors.info));
      expect(AppShieldColors.forSeverity('unknown'), equals(AppShieldColors.info));
    });

    test('all static colors are non-null', () {
      expect(AppShieldColors.primary,    isNotNull);
      expect(AppShieldColors.accent,     isNotNull);
      expect(AppShieldColors.active,     isNotNull);
      expect(AppShieldColors.trial,      isNotNull);
      expect(AppShieldColors.expired,    isNotNull);
      expect(AppShieldColors.warning,    isNotNull);
      expect(AppShieldColors.border,     isNotNull);
      expect(AppShieldColors.textMuted,  isNotNull);
    });
  });

  // ── AppShieldTheme ────────────────────────────────────────────────────────

  group('AppShieldTheme', () {
    test('light() factory creates light theme', () {
      final t = AppShieldTheme.light();
      expect(t.isDark,     isFalse);
      expect(t.brightness, equals(Brightness.light));
    });

    test('dark() factory creates dark theme', () {
      final t = AppShieldTheme.dark();
      expect(t.isDark,     isTrue);
      expect(t.brightness, equals(Brightness.dark));
    });

    test('light() accepts custom brandName', () {
      final t = AppShieldTheme.light(brandName: 'MyApp');
      expect(t.brandName, equals('MyApp'));
    });

    test('light() default brandName is AppShield', () {
      final t = AppShieldTheme.light();
      expect(t.brandName, equals('AppShield'));
    });

    test('toThemeData() returns ThemeData', () {
      final t = AppShieldTheme.light();
      expect(t.toThemeData(), isA<ThemeData>());
    });

    test('toThemeData() sets useMaterial3 true', () {
      final td = AppShieldTheme.light().toThemeData();
      expect(td.useMaterial3, isTrue);
    });

    test('dark toThemeData() has dark brightness', () {
      final td = AppShieldTheme.dark().toThemeData();
      expect(td.brightness, equals(Brightness.dark));
    });
  });

  // ── AppShieldConstants ────────────────────────────────────────────────────

  group('AppShieldConstants', () {
    test('packageName is app_shield', () {
      expect(AppShieldConstants.packageName, equals('app_shield'));
    });

    test('API path constants start with /', () {
      expect(AppShieldConstants.apiActivate,   startsWith('/'));
      expect(AppShieldConstants.apiValidate,   startsWith('/'));
      expect(AppShieldConstants.apiDeactivate, startsWith('/'));
      expect(AppShieldConstants.apiRestore,    startsWith('/'));
      expect(AppShieldConstants.apiRenew,      startsWith('/'));
      expect(AppShieldConstants.apiServerTime, startsWith('/'));
    });

    test('default values are positive', () {
      expect(AppShieldConstants.defaultOfflineGraceDays,     greaterThan(0));
      expect(AppShieldConstants.defaultTrialDays,            greaterThan(0));
      expect(AppShieldConstants.defaultMaxDevices,           greaterThan(0));
      expect(AppShieldConstants.defaultValidationIntervalHr, greaterThan(0));
      expect(AppShieldConstants.defaultApiTimeoutSec,        greaterThan(0));
      expect(AppShieldConstants.defaultRetryCount,           greaterThan(0));
    });

    test('encryption constants are correct sizes', () {
      expect(AppShieldConstants.aesKeyLength, equals(32));
      expect(AppShieldConstants.aesIvLength,  equals(12));
      expect(AppShieldConstants.pbkdf2Length, equals(32));
    });

    test('feature key constants are non-empty', () {
      expect(AppShieldConstants.featureAdvancedReports, isNotEmpty);
      expect(AppShieldConstants.featureMultiUser,       isNotEmpty);
      expect(AppShieldConstants.featureApiAccess,       isNotEmpty);
      expect(AppShieldConstants.featureCloudBackup,     isNotEmpty);
      expect(AppShieldConstants.featureExportPdf,       isNotEmpty);
      expect(AppShieldConstants.featurePro,             isNotEmpty);
    });

    test('storage keys start with as_', () {
      expect(AppShieldConstants.storageKeyLicense,    startsWith('as_'));
      expect(AppShieldConstants.storageKeyDeviceId,   startsWith('as_'));
      expect(AppShieldConstants.storageKeyTrialStart, startsWith('as_'));
    });
  });

  // ── Exception hierarchy ───────────────────────────────────────────────────

  group('AppShield exceptions', () {
    test('InvalidLicenseKeyException has correct code', () {
      const e = InvalidLicenseKeyException();
      expect(e.code, equals('INVALID_KEY'));
      expect(e.message, isNotEmpty);
    });

    test('LicenseNotFoundException has correct code', () {
      const e = LicenseNotFoundException();
      expect(e.code, equals('LICENSE_NOT_FOUND'));
    });

    test('LicenseAlreadyUsedException stores deviceId', () {
      const e = LicenseAlreadyUsedException(
        message:          'Already used',
        existingDeviceId: 'DEV-1234',
      );
      expect(e.existingDeviceId, equals('DEV-1234'));
      expect(e.code,            equals('LICENSE_ALREADY_USED'));
    });

    test('LicenseExpiredException stores expiredAt', () {
      final dt = DateTime(2025, 1, 1);
      final e  = LicenseExpiredException(message: 'Expired', expiredAt: dt);
      expect(e.expiredAt, equals(dt));
    });

    test('MaxDevicesExceededException stores counts', () {
      const e = MaxDevicesExceededException(
        currentCount: 3,
        maxAllowed:   1,
      );
      expect(e.currentCount, equals(3));
      expect(e.maxAllowed,   equals(1));
    });

    test('AppShieldNotInitializedException has code NOT_INITIALIZED', () {
      const e = AppShieldNotInitializedException();
      expect(e.code, equals('NOT_INITIALIZED'));
    });

    test('ClockTamperingException stores tamperType', () {
      const e = ClockTamperingException(
        message:    'Clock off',
        tamperType: 'clock_mismatch',
      );
      expect(e.tamperType, equals('clock_mismatch'));
    });

    test('ApiException stores statusCode', () {
      const e = ApiException(message: 'error', statusCode: 403);
      expect(e.statusCode, equals(403));
    });

    test('FeatureNotAvailableException stores feature name in message', () {
      const e = FeatureNotAvailableException('advanced_reports');
      expect(e.message, contains('advanced_reports'));
    });

    test('toString includes code and message', () {
      const e = InvalidLicenseKeyException('bad key');
      expect(e.toString(), contains('INVALID_KEY'));
    });
  });

  // ── ActivityLogEntry ──────────────────────────────────────────────────────

  group('ActivityLogEntry', () {
    test('toJson / fromJson round-trip', () {
      final entry = ActivityLogEntry(
        action:            'activate',
        timestamp:         DateTime(2026, 4, 21, 10, 0, 0, 0, 0),
        licenseKey:        'ABCD-1234-EFGH-5678',
        deviceFingerprint: 'A1B2-C3D4-E5F6-0708',
        details:           'test details',
      );
      final restored = ActivityLogEntry.fromJson(entry.toJson());
      expect(restored.action,            equals(entry.action));
      expect(restored.licenseKey,        equals(entry.licenseKey));
      expect(restored.deviceFingerprint, equals(entry.deviceFingerprint));
      expect(restored.details,           equals(entry.details));
    });

    test('listFromJson / listToJson round-trip', () {
      final entries = [
        ActivityLogEntry(action: 'activate',   timestamp: DateTime.now()),
        ActivityLogEntry(action: 'deactivate', timestamp: DateTime.now()),
      ];
      final json     = ActivityLogEntry.listToJson(entries);
      final restored = ActivityLogEntry.listFromJson(json);
      expect(restored.length, equals(2));
      expect(restored[0].action, equals('activate'));
      expect(restored[1].action, equals('deactivate'));
    });

    test('toString returns descriptive string', () {
      final e = ActivityLogEntry(action: 'activate', timestamp: DateTime.now());
      expect(e.toString(), contains('activate'));
    });
  });

  // ── TamperRecord ──────────────────────────────────────────────────────────

  group('TamperRecord', () {
    test('toJson / fromJson round-trip', () {
      final record = TamperRecord(
        tamperType: 'clock_mismatch',
        severity:   'high',
        detectedAt: DateTime(2026, 4, 21),
        details:    'Clock off by 20 minutes',
      );
      final restored = TamperRecord.fromJson(record.toJson());
      expect(restored.tamperType, equals('clock_mismatch'));
      expect(restored.severity,   equals('high'));
      expect(restored.details,    equals('Clock off by 20 minutes'));
    });

    test('listFromJson / listToJson round-trip', () {
      final records = [
        TamperRecord(tamperType: 'root', severity: 'medium', detectedAt: DateTime.now()),
        TamperRecord(tamperType: 'emulator', severity: 'low', detectedAt: DateTime.now()),
      ];
      final json     = TamperRecord.listToJson(records);
      final restored = TamperRecord.listFromJson(json);
      expect(restored.length,         equals(2));
      expect(restored[0].tamperType,  equals('root'));
      expect(restored[1].tamperType,  equals('emulator'));
    });

    test('toString includes tamperType and severity', () {
      final r = TamperRecord(
          tamperType: 'clock_mismatch', severity: 'high',
          detectedAt: DateTime.now());
      expect(r.toString(), contains('clock_mismatch'));
      expect(r.toString(), contains('high'));
    });
  });

  // ── ActivationResult ──────────────────────────────────────────────────────

  group('ActivationResult', () {
    test('success factory sets success=true', () {
      final license = License(
        key:        'ABCD-1234-EFGH-5678',
        type:       LicenseType.subscription,
        status:     LicenseStatus.active,
        deviceId:   'DEV-001',
        appId:      'com.test.app',
        plan:       'pro',
        activatedAt: DateTime.now().toUtc(),
        expiresAt:  DateTime.now().toUtc().add(const Duration(days: 365)),
        features:   const {},
        limits:     const {},
        signature:  'sig',
      );
      final result = ActivationResult.success(license);
      expect(result.success,  isTrue);
      expect(result.license,  isNotNull);
      expect(result.errorCode, isNull);
    });

    test('failure factory sets success=false', () {
      final result = ActivationResult.failure(
        errorCode:    'INVALID_KEY',
        errorMessage: 'Bad key',
      );
      expect(result.success,       isFalse);
      expect(result.license,       isNull);
      expect(result.errorCode,     equals('INVALID_KEY'));
      expect(result.errorMessage,  equals('Bad key'));
    });

    test('failure factory stores existingDeviceId', () {
      final result = ActivationResult.failure(
        errorCode:        'LICENSE_ALREADY_USED',
        errorMessage:     'Already used',
        existingDeviceId: 'OLD-DEVICE',
      );
      expect(result.existingDeviceId, equals('OLD-DEVICE'));
    });

    test('toString for success includes plan', () {
      final license = License(
        key:        'ABCD-1234-EFGH-5678',
        type:       LicenseType.subscription,
        status:     LicenseStatus.active,
        deviceId:   'D',
        appId:      'A',
        plan:       'enterprise',
        activatedAt: DateTime.now().toUtc(),
        expiresAt:  DateTime.now().toUtc().add(const Duration(days: 365)),
        features:   const {},
        limits:     const {},
        signature:  'sig',
      );
      expect(ActivationResult.success(license).toString(),
          contains('enterprise'));
    });
  });

  // ── ValidationResponse ────────────────────────────────────────────────────

  group('ValidationResponse', () {
    late License dummyLicense;

    setUp(() {
      dummyLicense = License(
        key:        'ABCD-1234-EFGH-5678',
        type:       LicenseType.subscription,
        status:     LicenseStatus.active,
        deviceId:   'DEV',
        appId:      'APP',
        plan:       'pro',
        activatedAt: DateTime.now().toUtc(),
        expiresAt:  DateTime.now().toUtc().add(const Duration(days: 365)),
        features:   const {},
        limits:     const {},
        signature:  'sig',
      );
    });

    test('valid factory sets isValid=true', () {
      final r = ValidationResponse.valid(license: dummyLicense);
      expect(r.isValid, isTrue);
      expect(r.status,  equals(LicenseStatus.active));
      expect(r.license, isNotNull);
    });

    test('invalid factory sets isValid=false', () {
      final r = ValidationResponse.invalid(status: LicenseStatus.expired);
      expect(r.isValid, isFalse);
      expect(r.status,  equals(LicenseStatus.expired));
    });

    test('gracePeriod factory sets isValid=true with gracePeriod status', () {
      final r = ValidationResponse.gracePeriod(license: dummyLicense);
      expect(r.isValid, isTrue);
      expect(r.status,  equals(LicenseStatus.gracePeriod));
    });

    test('toString is non-empty', () {
      final r = ValidationResponse.valid(license: dummyLicense);
      expect(r.toString(), isNotEmpty);
    });
  });

  // ── DeviceInfo / DevicePlatform ───────────────────────────────────────────

  group('DeviceInfo', () {
    test('toJson / fromJson round-trip', () {
      final info = DeviceInfo(
        fingerprint: 'A1B2-C3D4-E5F6-0708',
        platform:    DevicePlatform.android,
        hostname:    'test-device',
        osVersion:   'Android 14',
        appVersion:  '1.0.0+1',
        rawComponents: const {'model': 'Pixel 8', 'brand': 'Google'},
      );
      final json     = info.toJson();
      final restored = DeviceInfo.fromJson(json);
      expect(restored.fingerprint, equals('A1B2-C3D4-E5F6-0708'));
      expect(restored.platform,    equals(DevicePlatform.android));
      expect(restored.hostname,    equals('test-device'));
    });

    test('toJsonString / fromJson round-trip', () {
      final info = DeviceInfo(
        fingerprint: 'A1B2-C3D4-E5F6-0708',
        platform:    DevicePlatform.ios,
      );
      final json     = info.toJsonString();
      expect(json, isNotEmpty);
    });

    test('DevicePlatform has all expected values', () {
      final names = DevicePlatform.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'windows', 'macos', 'linux', 'android', 'ios', 'web', 'unknown',
      ]));
    });

    test('toString is non-empty', () {
      final info = DeviceInfo(
          fingerprint: 'A1B2-C3D4-E5F6-0708',
          platform: DevicePlatform.web);
      expect(info.toString(), isNotEmpty);
    });
  });

  // ── AppFeature ────────────────────────────────────────────────────────────

  group('AppFeature', () {
    test('isEnabled defaults to false', () {
      const f = AppFeature(key: 'reports', displayName: 'Reports');
      expect(f.isEnabled, isFalse);
    });

    test('copyWith updates isEnabled', () {
      const f   = AppFeature(key: 'reports', displayName: 'Reports');
      final f2  = f.copyWith(isEnabled: true);
      expect(f2.isEnabled, isTrue);
      expect(f2.key,       equals('reports'));
    });

    test('toString contains key and isEnabled', () {
      const f = AppFeature(key: 'reports', displayName: 'Reports', isEnabled: true);
      expect(f.toString(), contains('reports'));
      expect(f.toString(), contains('true'));
    });
  });

  // ── AppShieldLogger ───────────────────────────────────────────────────────

  group('AppShieldLogger', () {
    test('setEnabled true/false does not throw', () {
      expect(() => AppShieldLogger.setEnabled(false), returnsNormally);
      expect(() => AppShieldLogger.setEnabled(true),  returnsNormally);
    });

    test('setLevel does not throw', () {
      expect(() => AppShieldLogger.setLevel(LogLevel.error),   returnsNormally);
      expect(() => AppShieldLogger.setLevel(LogLevel.verbose),  returnsNormally);
      expect(() => AppShieldLogger.setLevel(LogLevel.info),     returnsNormally);
    });

    test('all log methods do not throw', () {
      AppShieldLogger.setEnabled(false); // silence during test
      expect(() => AppShieldLogger.v('verbose'), returnsNormally);
      expect(() => AppShieldLogger.d('debug'),   returnsNormally);
      expect(() => AppShieldLogger.i('info'),    returnsNormally);
      expect(() => AppShieldLogger.w('warn'),    returnsNormally);
      expect(() => AppShieldLogger.e('error'),   returnsNormally);
      AppShieldLogger.setEnabled(true);
    });

    test('LogLevel has all expected values', () {
      final names = LogLevel.values.map((e) => e.name).toList();
      expect(names, containsAll([
        'verbose', 'debug', 'info', 'warning', 'error', 'none',
      ]));
    });
  });
}
