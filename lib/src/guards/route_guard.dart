// lib/src/guards/route_guard.dart

import 'package:flutter/material.dart';
import '../../app_shield.dart';
import '../models/license_model.dart';

/// A [RouteObserver]-compatible guard that checks license/feature validity
/// before allowing navigation to a protected route.
///
/// Usage with GoRouter:
/// ```dart
/// GoRoute(
///   path: '/reports',
///   redirect: (ctx, state) => RouteGuard.checkFeature('advanced_reports', '/upgrade'),
/// )
/// ```
///
/// Usage with Navigator:
/// ```dart
/// Navigator.push(context,
///   RouteGuard.protectedRoute(
///     feature: 'advanced_reports',
///     builder: (ctx) => const ReportsPage(),
///   ),
/// );
/// ```
class RouteGuard {
  RouteGuard._();

  // ── GoRouter redirect helper ───────────────────────────────────────────────

  /// Returns a redirect path if [feature] is not available; otherwise null.
  static String? checkFeature(String feature, String redirectPath) {
    if (!AppShield.instance.hasFeature(feature)) {
      return redirectPath;
    }
    return null;
  }

  /// Returns a redirect path if the license is not valid; otherwise null.
  static String? checkLicense(String redirectPath) {
    if (!AppShield.instance.isLicenseValid) {
      return redirectPath;
    }
    return null;
  }

  // ── Navigator route helper ─────────────────────────────────────────────────

  /// Wraps a route in a feature/license guard.
  ///
  /// If the guard fails, [fallbackBuilder] is used instead of [builder].
  static MaterialPageRoute<T> protectedRoute<T>({
    required Widget Function(BuildContext) builder,
    required String feature,
    Widget Function(BuildContext)? fallbackBuilder,
  }) {
    return MaterialPageRoute<T>(
      builder: (context) {
        final allowed = AppShield.instance.hasFeature(feature);
        if (allowed) return builder(context);
        return fallbackBuilder?.call(context) ??
            _UpgradePage(feature: feature);
      },
    );
  }

  // ── Programmatic check ────────────────────────────────────────────────────

  static bool canAccess(String feature) =>
      AppShield.instance.hasFeature(feature);

  static bool get isLicenseActive =>
      AppShield.instance.licenseStatus == LicenseStatus.active ||
      AppShield.instance.licenseStatus == LicenseStatus.gracePeriod ||
      AppShield.instance.licenseStatus == LicenseStatus.trial;
}

// ── Fallback page ─────────────────────────────────────────────────────────

class _UpgradePage extends StatelessWidget {
  const _UpgradePage({required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Required')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Feature Not Available',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '"$feature" requires a higher license plan.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon:  const Icon(Icons.upgrade),
                label: const Text('Upgrade Plan'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child:     const Text('Go Back'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
