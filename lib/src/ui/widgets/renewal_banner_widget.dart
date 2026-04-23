// lib/src/ui/widgets/renewal_banner_widget.dart
//
// Batch 14 – Renewal Banner Widget.
// A dismissible banner that appears when the license is expiring soon.

import 'package:flutter/material.dart';
import '../../core/renewal_reminder_service.dart';
import '../themes/app_shield_colors.dart';

/// A dismissible banner displayed when [reminder] is provided.
///
/// Typically placed at the top of a screen or inside a Column.
///
/// ```dart
/// RenewalBannerWidget(
///   reminder: currentReminder,   // nullable; banner hides when null
///   onRenew:  () => launchUrl(buyUrl),
///   onDismiss: () => setState(() => _reminder = null),
/// )
/// ```
class RenewalBannerWidget extends StatelessWidget {
  const RenewalBannerWidget({
    super.key,
    required this.reminder,
    this.onRenew,
    this.onDismiss,
    this.renewLabel = 'Renew Now',
  });

  final RenewalReminder? reminder;
  final VoidCallback?    onRenew;
  final VoidCallback?    onDismiss;
  final String           renewLabel;

  @override
  Widget build(BuildContext context) {
    if (reminder == null) return const SizedBox.shrink();

    final color = _colorFor(reminder!.severity);

    return Material(
      color:       color.withAlpha(25),
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: color.withAlpha(80))),
        ),
        child: Row(
          children: [
            Icon(_iconFor(reminder!.severity), color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reminder!.headline,
                style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.w600,
                  fontSize:   13,
                ),
              ),
            ),
            if (onRenew != null) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor:  Colors.white,
                  backgroundColor:  color,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onRenew,
                child: Text(renewLabel,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon:       const Icon(Icons.close, size: 16),
                color:      color,
                tooltip:    'Dismiss',
                onPressed:  onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorFor(RenewalReminderSeverity s) {
    switch (s) {
      case RenewalReminderSeverity.notice:  return AppShieldColors.info;
      case RenewalReminderSeverity.warning: return AppShieldColors.warning;
      case RenewalReminderSeverity.urgent:  return AppShieldColors.expired;
      case RenewalReminderSeverity.expired: return Colors.red.shade900;
    }
  }

  IconData _iconFor(RenewalReminderSeverity s) {
    switch (s) {
      case RenewalReminderSeverity.notice:  return Icons.info_outline;
      case RenewalReminderSeverity.warning: return Icons.warning_amber_outlined;
      case RenewalReminderSeverity.urgent:  return Icons.alarm_outlined;
      case RenewalReminderSeverity.expired: return Icons.cancel_outlined;
    }
  }
}

/// A compact inline chip variant of the renewal reminder.
class RenewalChip extends StatelessWidget {
  const RenewalChip({
    super.key,
    required this.reminder,
    this.onTap,
  });

  final RenewalReminder? reminder;
  final VoidCallback?    onTap;

  @override
  Widget build(BuildContext context) {
    if (reminder == null) return const SizedBox.shrink();

    final color = _colorFor(reminder!.severity);
    final days  = reminder!.daysRemaining;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:        color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(reminder!.severity), color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              days <= 0 ? 'Expired' : '${days}d left',
              style: TextStyle(
                color:      color,
                fontSize:   11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(RenewalReminderSeverity s) {
    switch (s) {
      case RenewalReminderSeverity.notice:  return AppShieldColors.info;
      case RenewalReminderSeverity.warning: return AppShieldColors.warning;
      case RenewalReminderSeverity.urgent:  return AppShieldColors.expired;
      case RenewalReminderSeverity.expired: return Colors.red;
    }
  }

  IconData _iconFor(RenewalReminderSeverity s) {
    switch (s) {
      case RenewalReminderSeverity.notice:  return Icons.info_outline;
      case RenewalReminderSeverity.warning: return Icons.warning_amber_outlined;
      case RenewalReminderSeverity.urgent:  return Icons.alarm;
      case RenewalReminderSeverity.expired: return Icons.cancel;
    }
  }
}
