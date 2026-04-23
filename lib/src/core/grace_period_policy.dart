// lib/src/core/grace_period_policy.dart
//
// Batch 12 – Advanced: Configurable grace-period policy.
// Allows fine-grained control over offline behaviour and grace windows.

import '../utils/logger.dart';
import '../models/license_model.dart';

/// Defines the strategy used when the license cannot be validated online.
enum OfflineFallbackStrategy {
  /// Always allow the app to run (indefinitely offline).
  alwaysAllow,

  /// Allow for [graceDays] days, then block.
  gracePeriod,

  /// Block immediately — requires a live connection for every launch.
  blockImmediately,

  /// Show a degraded / read-only mode.
  degradedMode,
}

/// Describes what the app should do when entering degraded mode.
enum DegradedModeAction {
  readOnly,
  limitedFeatures,
  watermark,
  custom,
}

/// Advanced grace-period policy for AppShield.
///
/// ```dart
/// final policy = GracePeriodPolicy(
///   strategy:              OfflineFallbackStrategy.gracePeriod,
///   graceDays:             14,
///   warnDaysBeforeExpiry:  3,
///   allowGraceExtensions:  true,
///   maxGraceExtensions:    2,
/// );
///
/// final decision = policy.evaluate(
///   graceDaysUsed: 5,
///   license:       myLicense,
/// );
/// ```
class GracePeriodPolicy {
  const GracePeriodPolicy({
    this.strategy              = OfflineFallbackStrategy.gracePeriod,
    this.graceDays             = 7,
    this.warnDaysBeforeExpiry  = 2,
    this.allowGraceExtensions  = false,
    this.maxGraceExtensions    = 1,
    this.degradedModeAction    = DegradedModeAction.limitedFeatures,
    this.restrictedFeaturesInGrace = const [],
  });

  final OfflineFallbackStrategy strategy;
  final int                      graceDays;
  final int                      warnDaysBeforeExpiry;
  final bool                     allowGraceExtensions;
  final int                      maxGraceExtensions;
  final DegradedModeAction       degradedModeAction;

  /// Feature keys that are disabled during the grace period.
  final List<String>             restrictedFeaturesInGrace;

  /// Evaluates the policy and returns the appropriate [LicenseStatus].
  ///
  /// [graceDaysUsed] – days since the grace period began.
  /// [extensionsGranted] – how many extensions have already been granted.
  LicenseStatus evaluate({
    required int     graceDaysUsed,
    required License license,
    int              extensionsGranted = 0,
  }) {
    AppShieldLogger.d(
      'GracePeriodPolicy.evaluate: strategy=${strategy.name}, '
      'used=$graceDaysUsed/${graceDays}d, ext=$extensionsGranted',
    );

    switch (strategy) {
      case OfflineFallbackStrategy.alwaysAllow:
        return LicenseStatus.gracePeriod;

      case OfflineFallbackStrategy.blockImmediately:
        return LicenseStatus.expired;

      case OfflineFallbackStrategy.degradedMode:
        return LicenseStatus.gracePeriod; // host app must check restrictedFeaturesInGrace

      case OfflineFallbackStrategy.gracePeriod:
        if (graceDaysUsed <= graceDays) {
          return LicenseStatus.gracePeriod;
        }
        // Try extension
        if (allowGraceExtensions && extensionsGranted < maxGraceExtensions) {
          AppShieldLogger.i(
            'GracePeriodPolicy: grace expired but extension allowed '
            '($extensionsGranted / $maxGraceExtensions).',
          );
          return LicenseStatus.gracePeriod;
        }
        return LicenseStatus.expired;
    }
  }

  /// True when the app is within the warning window.
  bool isInWarnWindow(int graceDaysUsed) =>
      strategy == OfflineFallbackStrategy.gracePeriod &&
      graceDaysUsed >= (graceDays - warnDaysBeforeExpiry) &&
      graceDaysUsed <= graceDays;

  /// Whether [featureKey] is restricted during the current grace period.
  bool isFeatureRestricted(String featureKey) =>
      strategy == OfflineFallbackStrategy.degradedMode &&
      restrictedFeaturesInGrace.contains(featureKey);

  /// Returns remaining grace days; 0 if strategy is not [gracePeriod].
  int remainingDays(int graceDaysUsed) =>
      strategy == OfflineFallbackStrategy.gracePeriod
          ? (graceDays - graceDaysUsed).clamp(0, graceDays)
          : 0;

  @override
  String toString() =>
      'GracePeriodPolicy(strategy: ${strategy.name}, '
      'graceDays: $graceDays, warn: $warnDaysBeforeExpiry)';
}
