// lib/src/guards/feature_guard.dart

import 'package:flutter/material.dart';
import '../../app_shield.dart';

/// Shows [child] only when the current license includes [feature].
/// Otherwise shows [fallback] (or a default upgrade prompt).
///
/// Usage:
/// ```dart
/// FeatureGuard(
///   feature:  AppShieldConstants.featureAdvancedReports,
///   child:    const AdvancedReportsPage(),
///   fallback: const UpgradePromptWidget(),
/// )
/// ```
class FeatureGuard extends StatelessWidget {
  const FeatureGuard({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
    this.showUpgradePrompt = true,
  });

  final String  feature;
  final Widget  child;

  /// Widget to show when the feature is locked.
  final Widget? fallback;

  /// Whether to show the built-in upgrade prompt when [fallback] is null.
  final bool showUpgradePrompt;

  @override
  Widget build(BuildContext context) {
    if (AppShield.instance.hasFeature(feature)) return child;
    if (fallback != null) return fallback!;
    if (showUpgradePrompt) return _UpgradePrompt(feature: feature);
    return const SizedBox.shrink();
  }
}

// ── Built-in upgrade prompt ───────────────────────────────────────────────

class _UpgradePrompt extends StatelessWidget {
  const _UpgradePrompt({required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        theme.colorScheme.surfaceContainerHighest
                          .withAlpha(128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(76),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline,
              size: 48, color: theme.colorScheme.secondary),
          const SizedBox(height: 12),
          Text('Feature Locked',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'The "$feature" feature requires a higher plan.\n'
            'Upgrade your license to unlock it.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon:    const Icon(Icons.upgrade),
            label:   const Text('Upgrade Plan'),
            onPressed: () {
              final url = AppShield.instance.config.buyLicenseUrl;
              if (url.isNotEmpty) {
                // Open URL — integrate url_launcher in your app
                debugPrint('Open: $url');
              }
            },
          ),
        ],
      ),
    );
  }
}
