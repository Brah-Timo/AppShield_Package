// lib/src/guards/app_shield_guard.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../../app_shield.dart';
import '../models/license_model.dart';
import '../ui/screens/activation_screen.dart';
import '../ui/screens/expired_screen.dart';
import '../utils/logger.dart';

/// Wraps the root of your application and gates access based on license status.
///
/// Usage:
/// ```dart
/// AppShieldGuard(
///   child: const HomePage(),
///   onLicenseInvalid: () => const ActivationScreen(),
///   onTrialExpired:   () => const ExpiredScreen(),
/// )
/// ```
class AppShieldGuard extends StatefulWidget {
  const AppShieldGuard({
    super.key,
    required this.child,
    this.onLicenseInvalid,
    this.onTrialExpired,
    this.onLoading,
    this.periodicCheckIntervalHr = 24,
  });

  /// The main app widget shown when the license is valid.
  final Widget child;

  /// Widget builder shown when no valid license exists.
  /// Defaults to [ActivationScreen].
  final Widget Function()? onLicenseInvalid;

  /// Widget builder shown when the license / trial has expired.
  /// Defaults to [ExpiredScreen].
  final Widget Function()? onTrialExpired;

  /// Widget builder shown during the initial license check.
  final Widget Function()? onLoading;

  /// How often (hours) to repeat the background license check.
  final int periodicCheckIntervalHr;

  @override
  State<AppShieldGuard> createState() => _AppShieldGuardState();
}

class _AppShieldGuardState extends State<AppShieldGuard>
    with WidgetsBindingObserver {
  LicenseStatus _status = LicenseStatus.notActivated;
  bool          _loading = true;
  Timer?        _periodicTimer;

  // Stream subscription to react to revokes / expiry pushed from server
  StreamSubscription<LicenseStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndSubscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-validate every time the app comes to the foreground
    if (state == AppLifecycleState.resumed) {
      _runCheck();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  void _checkAndSubscribe() {
    // Subscribe to real-time status changes
    _statusSub = AppShield.instance.licenseStatusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });

    // First check
    _runCheck();

    // Periodic background check
    _periodicTimer = Timer.periodic(
      Duration(hours: widget.periodicCheckIntervalHr),
      (_) => _runCheck(),
    );
  }

  Future<void> _runCheck() async {
    try {
      final status = await AppShield.instance.checkLicense();
      AppShieldLogger.d('AppShieldGuard status: ${status.name}');
      if (mounted) setState(() { _status = status; _loading = false; });
    } catch (e) {
      AppShieldLogger.e('AppShieldGuard check error', error: e);
      if (mounted) setState(() { _status = LicenseStatus.notActivated; _loading = false; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.onLoading?.call() ?? _defaultLoading();
    }

    switch (_status) {
      case LicenseStatus.active:
      case LicenseStatus.gracePeriod:
      case LicenseStatus.trial:
        return widget.child;

      case LicenseStatus.expired:
        return widget.onTrialExpired?.call() ??
            ExpiredScreen(onActivate: _runCheck);

      case LicenseStatus.notActivated:
      case LicenseStatus.deviceMismatch:
      case LicenseStatus.tampered:
      case LicenseStatus.offline:
        return widget.onLicenseInvalid?.call() ??
            ActivationScreen(onActivated: _runCheck);

      case LicenseStatus.revoked:
      case LicenseStatus.suspended:
        return widget.onTrialExpired?.call() ??
            ExpiredScreen(
              onActivate: _runCheck,
              message: _status == LicenseStatus.revoked
                  ? 'Your license has been revoked. Please contact support.'
                  : 'Your license is temporarily suspended.',
            );
    }
  }

  Widget _defaultLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
