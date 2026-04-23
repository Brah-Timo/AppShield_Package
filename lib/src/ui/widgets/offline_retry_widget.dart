// lib/src/ui/widgets/offline_retry_widget.dart
//
// OfflineRetryWidget – shows a banner / card when the app is offline
// and the license could not be validated. Provides a retry button.

import 'package:flutter/material.dart';
import '../themes/app_shield_colors.dart';

/// Displays an offline warning with a retry action.
///
/// ```dart
/// OfflineRetryWidget(
///   isOffline:   !shield.isOnline,
///   onRetry:     () => shield.validateOnline(),
///   isRetrying:  shield.isValidating,
///   graceEndsAt: license.expiresAt,
/// )
/// ```
class OfflineRetryWidget extends StatelessWidget {
  const OfflineRetryWidget({
    super.key,
    required this.isOffline,
    this.onRetry,
    this.isRetrying    = false,
    this.graceEndsAt,
    this.compact       = false,
  });

  /// When false the widget renders nothing (SizedBox.shrink).
  final bool        isOffline;

  /// Called when the user taps the retry button.
  final VoidCallback? onRetry;

  /// Shows a spinner inside the retry button while true.
  final bool          isRetrying;

  /// Optional end-of-grace-period date; adds a countdown warning.
  final DateTime?     graceEndsAt;

  /// When true, renders a compact inline chip instead of a full banner.
  final bool          compact;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return compact ? _CompactChip(this) : _FullBanner(this);
  }
}

// ── Full banner ──────────────────────────────────────────────────────────

class _FullBanner extends StatelessWidget {
  const _FullBanner(this.widget);
  final OfflineRetryWidget widget;

  @override
  Widget build(BuildContext context) {
    final graceEndsAt = widget.graceEndsAt;
    final daysLeft = graceEndsAt != null
        ? graceEndsAt.difference(DateTime.now()).inDays
        : null;

    return Container(
      margin:     const EdgeInsets.symmetric(vertical: 6),
      padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.orange.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.orange.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline – License not validated',
                  style: TextStyle(
                    color:      Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize:   13,
                  ),
                ),
                if (daysLeft != null)
                  Text(
                    daysLeft > 0
                        ? 'Grace period ends in $daysLeft day${daysLeft == 1 ? "" : "s"}'
                        : '⚠ Grace period has ended',
                    style: TextStyle(
                      color:    daysLeft > 0 ? Colors.orange : Colors.red,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RetryButton(widget),
        ],
      ),
    );
  }
}

// ── Compact chip ─────────────────────────────────────────────────────────

class _CompactChip extends StatelessWidget {
  const _CompactChip(this.widget);
  final OfflineRetryWidget widget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isRetrying ? null : widget.onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        Colors.orange.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: Colors.orange.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.isRetrying
                ? const SizedBox(
                    width:  10,
                    height: 10,
                    child:  CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.orange))
                : const Icon(Icons.wifi_off, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            const Text('Offline',
                style: TextStyle(
                    color: Colors.orange, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── Retry button ─────────────────────────────────────────────────────────

class _RetryButton extends StatelessWidget {
  const _RetryButton(this.widget);
  final OfflineRetryWidget widget;

  @override
  Widget build(BuildContext context) {
    if (widget.onRetry == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: widget.isRetrying
          ? const SizedBox(
              key:    ValueKey('spinner'),
              width:  20,
              height: 20,
              child:  CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.orange))
          : TextButton.icon(
              key:      const ValueKey('retry'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                backgroundColor: Colors.orange.withAlpha(18),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
              ),
              icon:     const Icon(Icons.refresh, size: 14),
              label:    const Text('Retry', style: TextStyle(fontSize: 12)),
              onPressed: widget.onRetry,
            ),
    );
  }
}

// ── Connection status dot ─────────────────────────────────────────────────

/// Small colored dot indicating online / offline status.
///
/// ```dart
/// ConnectionStatusDot(isOnline: shield.isOnline)
/// ```
class ConnectionStatusDot extends StatelessWidget {
  const ConnectionStatusDot({
    super.key,
    required this.isOnline,
    this.size = 8.0,
  });

  final bool   isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppShieldColors.active : Colors.orange;
    return Tooltip(
      message: isOnline ? 'Online' : 'Offline',
      child: Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          color:  color,
          shape:  BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withAlpha(100), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
