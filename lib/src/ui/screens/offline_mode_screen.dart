// lib/src/ui/screens/offline_mode_screen.dart

import 'package:flutter/material.dart';

import '../../../app_shield.dart';

/// Shown as an overlay or page when the app is running in offline/grace mode.
///
/// Use as an overlay by providing [child]:
/// ```dart
/// OfflineModeScreen(child: const HomePage(), graceDaysLeft: 3)
/// ```
///
/// Use as a standalone page (e.g. for Navigator) by omitting [child]:
/// ```dart
/// OfflineModeScreen(onRetry: () => Navigator.pop(context))
/// ```
class OfflineModeScreen extends StatelessWidget {
  const OfflineModeScreen({
    super.key,
    this.child,
    this.graceDaysLeft = 0,
    this.onRetry,
  });

  /// When provided, renders as an overlay banner above this widget.
  final Widget? child;

  /// Remaining grace-period days to display in the banner.
  final int graceDaysLeft;

  /// Called when the user taps "Retry". Defaults to an online validation.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // ── Standalone page mode (no child) ──────────────────────────────────
    if (child == null) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 80, color: Colors.orange.shade700),
                const SizedBox(height: 24),
                Text(
                  'You\'re Offline',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:      Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  graceDaysLeft > 0
                      ? 'Your license is in grace mode.\n'
                        '$graceDaysLeft day${graceDaysLeft == 1 ? '' : 's'} '
                        'remaining before re-validation is required.'
                      : 'Please connect to the internet to validate your license.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color:    Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon:     const Icon(Icons.refresh),
                  label:    const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry ??
                      () => AppShield.instance.validateOnline(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Overlay banner mode ───────────────────────────────────────────────
    return Stack(
      children: [
        child!,
        Positioned(
          top:   0,
          left:  0,
          right: 0,
          child: _OfflineBanner(
            graceDaysLeft: graceDaysLeft,
            onRetry:       onRetry,
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.graceDaysLeft, this.onRetry});
  final int            graceDaysLeft;
  final VoidCallback?  onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.orange.shade700,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                graceDaysLeft > 0
                    ? 'Offline mode — $graceDaysLeft day${graceDaysLeft == 1 ? '' : 's'} '
                      'remaining until re-validation required.'
                    : 'Offline — Please connect to validate your license.',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onRetry ??
                  () => AppShield.instance.validateOnline(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
