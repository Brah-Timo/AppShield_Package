// lib/src/ui/widgets/license_health_widget.dart
//
// Batch 12 – Advanced UI: Compact license-health indicator widget.

import 'package:flutter/material.dart';
import '../../core/license_health_monitor.dart';
import '../themes/app_shield_colors.dart';

/// Compact badge showing the current [LicenseHealthStatus].
///
/// ```dart
/// LicenseHealthBadge(
///   snapshot: snapshot,
///   showDetails: true,
/// )
/// ```
class LicenseHealthBadge extends StatelessWidget {
  const LicenseHealthBadge({
    super.key,
    required this.snapshot,
    this.showDetails = false,
    this.size        = 12.0,
  });

  final LicenseHealthSnapshot snapshot;
  final bool                  showDetails;
  final double                size;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(snapshot.status);
    final label = _labelFor(snapshot.status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color:      color.withAlpha(128),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        if (showDetails) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize:   12,
              fontWeight: FontWeight.w500,
              color:      color,
            ),
          ),
        ],
      ],
    );
  }

  Color _colorFor(LicenseHealthStatus s) {
    switch (s) {
      case LicenseHealthStatus.healthy:  return AppShieldColors.active;
      case LicenseHealthStatus.degraded: return AppShieldColors.warning;
      case LicenseHealthStatus.critical: return AppShieldColors.expired;
      case LicenseHealthStatus.unknown:  return AppShieldColors.inactive;
    }
  }

  String _labelFor(LicenseHealthStatus s) {
    switch (s) {
      case LicenseHealthStatus.healthy:  return 'Healthy';
      case LicenseHealthStatus.degraded: return 'Degraded';
      case LicenseHealthStatus.critical: return 'Critical';
      case LicenseHealthStatus.unknown:  return 'Unknown';
    }
  }
}

/// Expanded card showing all active health alerts.
class LicenseHealthCard extends StatelessWidget {
  const LicenseHealthCard({
    super.key,
    required this.snapshot,
    this.onResolve,
  });

  final LicenseHealthSnapshot       snapshot;
  final void Function(HealthAlert)? onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!snapshot.hasAlerts) {
      return _buildHealthyCard(theme);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _borderColor(snapshot.status),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LicenseHealthBadge(snapshot: snapshot, showDetails: true),
                const Spacer(),
                Text(
                  '${snapshot.alerts.length} alert(s)',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(height: 20),
            ...snapshot.alerts.map((a) => _AlertTile(alert: a, onResolve: onResolve)),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthyCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppShieldColors.active.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppShieldColors.active),
            const SizedBox(width: 12),
            Text('License is healthy',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppShieldColors.active)),
          ],
        ),
      ),
    );
  }

  Color _borderColor(LicenseHealthStatus s) {
    switch (s) {
      case LicenseHealthStatus.healthy:  return AppShieldColors.active;
      case LicenseHealthStatus.degraded: return AppShieldColors.warning;
      case LicenseHealthStatus.critical: return AppShieldColors.expired;
      case LicenseHealthStatus.unknown:  return AppShieldColors.inactive;
    }
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, this.onResolve});
  final HealthAlert                 alert;
  final void Function(HealthAlert)? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(alert.severity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_severityIcon(alert.severity), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                      color:      color,
                    )),
                if (alert.details != null)
                  Text(
                    alert.details!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · '),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (onResolve != null)
            TextButton(
              onPressed: () => onResolve!(alert),
              child: const Text('Fix', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Color _severityColor(HealthAlertSeverity s) {
    switch (s) {
      case HealthAlertSeverity.info:     return AppShieldColors.info;
      case HealthAlertSeverity.warning:  return AppShieldColors.warning;
      case HealthAlertSeverity.critical: return AppShieldColors.expired;
    }
  }

  IconData _severityIcon(HealthAlertSeverity s) {
    switch (s) {
      case HealthAlertSeverity.info:     return Icons.info_outline;
      case HealthAlertSeverity.warning:  return Icons.warning_amber_outlined;
      case HealthAlertSeverity.critical: return Icons.error_outline;
    }
  }
}
