
# 🛡️ AppShield — Licensing & Activation System for Flutter

> **📖 [Full Usage Guide & API Reference →](USAGE.md)**

[![pub.dev](https://img.shields.io/badge/pub.dev-app__shield-blue?logo=dart)](https://pub.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.16%2B-blue?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS%20%7C%20Web-lightgrey)](https://flutter.dev)

A professional, enterprise-grade **licensing and activation package** for Flutter applications.  
Supports **Windows · macOS · Linux · Android · iOS · Web**.


<img width="800" height="500" alt="appshield_comparison" src="https://github.com/user-attachments/assets/9b167d09-7bba-4d6b-add4-d4ec3f3f63b8" />
<img width="800" height="500" alt="appshield_demo" src="https://github.com/user-attachments/assets/f0b35787-0f0b-443e-8b77-454c8e45de6e" />
<img width="800" height="500" alt="appshield_activation" src="https://github.com/user-attachments/assets/2c504a15-0d57-41cf-8964-fb8df48bbf57" />
---

## ✨ Features at a Glance

| Feature | Description |
|---------|-------------|
| 🔑 **License Keys** | `XXXX-XXXX-XXXX-XXXX` format with auto-format & validation |
| 🌐 **Online Validation** | JWT-signed server validation with retry + back-off |
| 📴 **Offline Mode** | Configurable grace period (default 7 days) |
| 🖥️ **Device Binding** | Per-platform hardware fingerprint |
| 🔒 **AES-256-GCM** | Triple-layer local storage encryption |
| ✍️ **RSA-2048** | Server signature verification on every license token |
| ⏱️ **Clock Tamper** | Server-time + last-known-time rollback detection |
| 🛡️ **Anti-Tamper** | Root/jailbreak, emulator, debugger, storage integrity |
| 🎁 **Trial Period** | Per-device trial with optional server registration |
| 🔀 **Feature Flags** | Per-feature licensing (`FeatureGuard` widget) |
| 🔄 **Subscriptions** | Perpetual · Subscription · Trial · Educational · OEM |
| 🔔 **Notifications** | In-app expiry / grace / revoke alerts via listener |
| 🎨 **Custom UI** | Light/dark themes, branding, RTL/LTR locale support |
| 📱 **Ready UI** | `ActivationScreen`, `ExpiredScreen`, `TrialScreen`, `LicenseInfoScreen` |

---

## 📦 Installation

```yaml
dependencies:
  app_shield: ^1.0.0
```

---

## 🚀 Quick Start

### 1. Initialize in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:app_shield/app_shield.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppShield.initialize(
    config: AppShieldConfig(
      appId:      'com.mycompany.erp',
      apiBaseUrl: 'https://license.mycompany.com/api',
      apiKey:     'pk_live_your_api_key_here',
      appSecret:  'strong-random-secret-for-local-encryption',
      publicKey:  '-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----',

      enableTrial:          true,
      trialDays:            15,
      enableOfflineMode:    true,
      offlineGraceDays:     7,
      enableDeviceBinding:  true,
      maxDevicesPerLicense: 1,
      enableClockCheck:     true,
      validationIntervalHr: 24,

      theme: AppShieldTheme.light(
        primaryColor: Colors.blue,
        brandName:    'My ERP System',
      ),
    ),
  );

  runApp(const MyApp());
}
```

### 2. Wrap your root widget with `AppShieldGuard`

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AppShieldGuard(
        child:            const HomePage(),
        onLicenseInvalid: () => const ActivationScreen(),
        onTrialExpired:   () => const ExpiredScreen(),
      ),
    );
  }
}
```

`AppShieldGuard` automatically:
- Checks license on startup
- Re-checks on every foreground resume
- Runs periodic background validation
- Listens to revocation / status push from server

### 3. Guard individual features with `FeatureGuard`

```dart
FeatureGuard(
  feature:  AppShieldConstants.featureAdvancedReports,
  child:    const AdvancedReportsPage(),
  fallback: const UpgradePromptWidget(), // optional
)
```

### 4. Protect routes with `RouteGuard`

```dart
// GoRouter
GoRoute(
  path: '/reports',
  redirect: (ctx, state) =>
      RouteGuard.checkFeature('advanced_reports', '/upgrade'),
  builder: (ctx, state) => const ReportsPage(),
)

// Navigator
Navigator.push(
  context,
  RouteGuard.protectedRoute(
    feature: 'advanced_reports',
    builder: (_) => const ReportsPage(),
  ),
);
```

### 5. Programmatic API

```dart
final shield = AppShield.instance;

// Check status
final status = await shield.checkLicense();

// Activate a key
final result = await shield.activate('ABCD-1234-EFGH-5678');
if (result.success) { /* navigate to app */ }

// Validate online
final resp = await shield.validateOnline();

// Restore license to new device
await shield.restore(licenseKey: 'ABCD-...', email: 'user@example.com');

// Start trial
await shield.startTrial();

// Check feature
if (shield.hasFeature(AppShieldConstants.featureCloudBackup)) { /* ... */ }

// Days remaining
print(shield.daysRemaining);

// Deactivate
await shield.deactivate();
```

---

## 🧩 Package Structure

```
app_shield/
├── lib/
│   ├── app_shield.dart              # Main entry point + exports
│   ├── app_shield_config.dart       # AppShieldConfig class
│   └── src/
│       ├── core/
│       │   ├── license_manager.dart     # Lifecycle engine
│       │   ├── device_fingerprint.dart  # Per-platform fingerprinting
│       │   ├── encryption_service.dart  # AES-256-GCM + RSA + HMAC
│       │   ├── api_client.dart          # HTTP client with retry
│       │   ├── clock_verifier.dart      # Anti-clock-tamper
│       │   └── tamper_detector.dart     # Root/debug/emulator checks
│       ├── models/
│       │   ├── license_model.dart
│       │   ├── device_model.dart
│       │   ├── feature_model.dart
│       │   ├── activation_result.dart
│       │   ├── validation_response.dart
│       │   ├── activity_log_entry.dart
│       │   └── tamper_record.dart
│       ├── services/
│       │   ├── validation_service.dart  # Online activate/validate/restore
│       │   ├── storage_service.dart     # Triple-layer encrypted storage
│       │   ├── trial_service.dart       # Trial lifecycle
│       │   ├── sync_service.dart        # Telemetry + tamper reports
│       │   └── notification_service.dart
│       ├── guards/
│       │   ├── app_shield_guard.dart    # Root widget gate
│       │   ├── feature_guard.dart       # Per-feature widget gate
│       │   └── route_guard.dart         # Navigator/GoRouter helpers
│       ├── ui/
│       │   ├── screens/
│       │   │   ├── activation_screen.dart
│       │   │   ├── trial_screen.dart
│       │   │   ├── expired_screen.dart
│       │   │   ├── license_info_screen.dart
│       │   │   ├── offline_mode_screen.dart
│       │   │   └── tamper_detected_screen.dart
│       │   ├── widgets/
│       │   │   ├── license_input.dart
│       │   │   ├── status_card.dart
│       │   │   ├── expiry_badge.dart
│       │   │   ├── device_info_widget.dart
│       │   │   └── feature_list_widget.dart
│       │   └── themes/
│       │       ├── app_shield_theme.dart
│       │       └── app_shield_colors.dart
│       └── utils/
│           ├── constants.dart
│           ├── helpers.dart
│           ├── logger.dart
│           └── exceptions.dart
├── example/                         # Complete demo app
├── test/                            # Unit tests
├── pubspec.yaml
├── README.md
└── CHANGELOG.md
```

---

## 🔐 Security Architecture

```
╔══════════════════════════════════════════════════════════════╗
║  Layer            Technology          Purpose                ║
╠══════════════════════════════════════════════════════════════╣
║  Local Storage    AES-256-GCM         Encrypt license data   ║
║  Key Derivation   PBKDF2-HMAC-SHA256  Derive AES key         ║
║  Integrity        HMAC-SHA-256        Detect tampering        ║
║  Transport        TLS 1.3             Secure API calls        ║
║  Server Sig.      RSA-2048            Verify license token    ║
║  Sessions         JWT                 Validate auth tokens    ║
║  Clock            Server NTP sync     Anti-clock-rollback     ║
║  Storage Layers   Keychain + Prefs    Redundant persistence   ║
╚══════════════════════════════════════════════════════════════╝
```

**Triple-layer storage** prevents simple file deletion:
1. **FlutterSecureStorage** (OS Keychain / Android Keystore) — primary
2. **SharedPreferences** (encrypted blob) — fallback
3. **HMAC tag** in secure storage — tamper detection

---

## 📱 Platform Support & Device Fingerprint Sources

| Platform | Fingerprint Sources |
|----------|---------------------|
| **Windows** | Device ID (WMI), Computer Name, OS Version |
| **macOS** | Hardware UUID (IOKit), hostname, OS version |
| **Linux** | `/etc/machine-id`, hostname, CPU info |
| **Android** | `ANDROID_ID`, Build.MANUFACTURER, Build.MODEL |
| **iOS** | `identifierForVendor`, device model |
| **Web** | User-Agent, browser info, canvas entropy |

---

## 🎫 License Types

| Type | Description | Example Use Case |
|------|-------------|------------------|
| `perpetual` | One-time purchase, no expiry | Desktop software |
| `subscription` | Monthly / yearly recurring | SaaS apps |
| `trial` | Free evaluation period | Lead generation |
| `educational` | Discounted student license | Schools, universities |
| `enterprise` | Custom large-scale license | Large organizations |
| `oem` | Bundled / reseller license | White-label products |

---

## ⚙️ Configuration Reference

```dart
AppShieldConfig(
  // ── Required ────────────────────────────────────────────────
  appId:      'com.myapp',            // Unique app identifier
  apiBaseUrl: 'https://license...',   // License server URL
  apiKey:     'pk_live_...',          // API authentication key

  // ── Security ────────────────────────────────────────────────
  appSecret:  'strong-random-secret', // Local AES encryption key
  publicKey:  '-----BEGIN PUBLIC KEY-----...', // RSA-2048 verification

  // ── Offline ─────────────────────────────────────────────────
  enableOfflineMode:    true,
  offlineGraceDays:     7,            // Days allowed without server

  // ── Trial ────────────────────────────────────────────────────
  enableTrial:          true,
  trialDays:            15,           // Free trial length

  // ── Device ───────────────────────────────────────────────────
  enableDeviceBinding:  true,
  maxDevicesPerLicense: 1,            // Devices per license key

  // ── Validation ───────────────────────────────────────────────
  enableClockCheck:     true,         // Detect clock manipulation
  validationIntervalHr: 24,           // Hours between server checks

  // ── Tamper Detection ─────────────────────────────────────────
  enableTamperDetection:    true,
  enableRootJailbreakCheck: true,
  enableEmulatorCheck:      false,    // Enable in production
  enableDebuggerCheck:      false,    // Enable in release builds

  // ── Subscription ─────────────────────────────────────────────
  enableAutoRenewal:    false,
  buyLicenseUrl:        'https://example.com/buy',
  supportUrl:           'https://example.com/support',

  // ── UI ───────────────────────────────────────────────────────
  theme: AppShieldTheme.light(
    primaryColor: Colors.blue,
    brandName:    'My App',
    logoAsset:    'assets/logo.png',
    locale:       'en',               // 'en', 'fr', 'ar'
  ),

  // ── Telemetry ─────────────────────────────────────────────────
  enableTelemetry: false,             // Opt-in usage analytics

  // ── Logging ──────────────────────────────────────────────────
  enableLogging: true,
)
```

---

## 🌐 License Server API

Your backend must implement these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/license/activate` | Activate a key on a device |
| `POST` | `/license/validate` | Validate license + device |
| `POST` | `/license/deactivate` | Remove device binding |
| `POST` | `/license/restore` | Restore key to new device |
| `POST` | `/license/renew` | Renew subscription |
| `GET`  | `/license/info` | Get license details |
| `GET`  | `/license/features` | Get available features |
| `POST` | `/trial/start` | Register trial start |
| `POST` | `/telemetry/send` | Receive usage events |
| `GET`  | `/updates/check` | Check for app updates |
| `GET`  | `/system/time` | Return server UTC time |
| `POST` | `/auth/otp/send` | Send OTP email |
| `POST` | `/auth/otp/verify` | Verify OTP code |

### Activate Request

```json
POST /license/activate
{
  "license_key": "ABCD-1234-EFGH-5678",
  "device": {
    "fingerprint": "A1B2-C3D4-E5F6-0708",
    "platform":    "windows",
    "hostname":    "USER-PC",
    "os_version":  "Windows 11"
  },
  "app_id":    "com.mycompany.erp",
  "timestamp": 1713696000000
}
```

### Activate Response

```json
{
  "status": "success",
  "data": {
    "license": {
      "key":          "ABCD-1234-EFGH-5678",
      "type":         "subscription",
      "plan":         "professional",
      "activated_at": "2026-04-21T10:30:00Z",
      "expires_at":   "2027-04-21T10:30:00Z",
      "device_id":    "A1B2-C3D4-E5F6-0708",
      "features": {
        "advanced_reports": true,
        "multi_user":       true,
        "api_access":       true,
        "cloud_backup":     false
      },
      "limits": {
        "max_users":   10,
        "max_records": 100000
      },
      "signature": "base64_rsa_signature_here"
    },
    "token": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

## 🔔 In-App Notifications

```dart
AppShield.instance.notificationService.addListener((notification) {
  switch (notification.type) {
    case AppShieldNotificationType.expiryWarning:
      // Show banner: "License expiring in X days"
      break;
    case AppShieldNotificationType.licenseRevoked:
      // Lock app immediately
      break;
    case AppShieldNotificationType.updateAvailable:
      // Show update dialog
      break;
    default:
      debugPrint(notification.message);
  }
});
```

---

## 🧪 Testing

```bash
flutter test
```

Tests cover:
- `License` model (serialization, validity, feature checks)
- `AppShieldHelpers` (key formatting, date helpers)
- `EncryptionService` (encrypt/decrypt, HMAC, SHA-256)

---

## 🚨 Common Error Codes

| Code | Exception | Cause |
|------|-----------|-------|
| `INVALID_KEY` | `InvalidLicenseKeyException` | Wrong key format or unknown key |
| `LICENSE_ALREADY_USED` | `LicenseAlreadyUsedException` | Key in use on another device |
| `LICENSE_EXPIRED` | `LicenseExpiredException` | Subscription ended |
| `LICENSE_REVOKED` | `LicenseRevokedException` | Revoked by admin |
| `MAX_DEVICES_EXCEEDED` | `MaxDevicesExceededException` | Too many activations |
| `TRIAL_USED` | `TrialAlreadyUsedException` | Trial already used on device |
| `CLOCK_TAMPER` | `ClockTamperingException` | System clock manipulation |
| `DEVICE_MISMATCH` | `DeviceMismatchException` | License bound to different device |
| `OFFLINE_LIMIT` | `OfflineLimitExceededException` | Grace period exhausted |
| `API_TIMEOUT` | `ApiTimeoutException` | Server unreachable |
| `SIGNATURE_INVALID` | `SignatureVerificationException` | RSA signature mismatch |

---

## 🔧 Tips for Production

1. **Change `appSecret`** — use a strong random string unique per app.
2. **Set `publicKey`** — provide your RSA-2048 public key PEM for full signature verification.
3. **Enable tamper checks** — set `enableEmulatorCheck: true` and `enableDebuggerCheck: true` in release builds.
4. **Use HTTPS** — the API client enforces TLS; never deploy with HTTP in production.
5. **Keep grace period short** — 7 days is a good default; less for high-security apps.
6. **Rotate `appSecret`** on major versions — triggers re-validation for all users.
7. **Monitor tamper reports** — check your server's tamper log for suspicious patterns.

---


## 💰 Licensing

| Tier | Price | Includes |
|------|-------|---------|
| **Open Source** | Free | Core + 5 presets |
| ## 💎 Pro Plan — $49 / year | $49 / year | 

✔ All 20+ presets  
✔ Advanced gradients system  
✔ Cloud sync  
✔ Priority updates  |

👉 [🚀 Get Pro Access](https://timsoftdz.lemonsqueezy.com/checkout)


**Built with ❤️ for the Flutter community**
## 🤝 TIMSoftDZ
[TIMSoftDZ](https://timsoftdz.blogspot.com/)
