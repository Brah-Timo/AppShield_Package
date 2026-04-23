// example/lib/widgets/title_bar.dart
//
// Top title bar widget for the Windows desktop layout.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    super.key,
    required this.title,
    required this.themeMode,
    required this.onToggleTheme,
    this.showMenu    = false,
    this.onMenuTap,
  });

  final String       title;
  final ThemeMode    themeMode;
  final VoidCallback onToggleTheme;
  final bool         showMenu;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              icon:      const Icon(Icons.menu),
              onPressed: onMenuTap,
            ),

          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          // ── License status chip ────────────────────────────────────────
          Consumer<AppShieldProvider>(
            builder: (_, shield, __) => _LicenseChip(status: shield.status),
          ),
          const SizedBox(width: 8),

          // ── Validate button ────────────────────────────────────────────
          Consumer<AppShieldProvider>(
            builder: (_, shield, __) => shield.isValidating
                ? const SizedBox(
                    width:  20,
                    height: 20,
                    child:  CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon:    const Icon(Icons.refresh_outlined),
                    tooltip: 'Validate license online',
                    onPressed: shield.validateOnline,
                  ),
          ),

          // ── Theme toggle (only if no sidebar) ─────────────────────────
          if (showMenu) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              tooltip:   'Toggle theme',
              onPressed: onToggleTheme,
            ),
          ],

          const SizedBox(width: 4),

          // ── Notification bell ──────────────────────────────────────────
          Consumer<AppShieldProvider>(
            builder: (_, shield, __) => _NotificationBell(
              hasAlerts: shield.healthSnapshot?.hasAlerts ?? false,
            ),
          ),
        ],
      ),
    );
  }
}

// ── License chip ──────────────────────────────────────────────────────────

class _LicenseChip extends StatelessWidget {
  const _LicenseChip({required this.status});
  final LicenseStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppShieldColors.forStatus(status.name);
    final label = _label(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _label(LicenseStatus s) {
    switch (s) {
      case LicenseStatus.active:         return 'Active';
      case LicenseStatus.trial:          return 'Trial';
      case LicenseStatus.gracePeriod:    return 'Grace Period';
      case LicenseStatus.expired:        return 'Expired';
      case LicenseStatus.revoked:        return 'Revoked';
      case LicenseStatus.suspended:      return 'Suspended';
      case LicenseStatus.offline:        return 'Offline';
      case LicenseStatus.tampered:       return 'Tampered';
      case LicenseStatus.deviceMismatch: return 'Device Mismatch';
      case LicenseStatus.notActivated:
      default:                           return 'Not Activated';
    }
  }
}

// ── Notification bell ─────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.hasAlerts});
  final bool hasAlerts;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon:    const Icon(Icons.notifications_outlined),
          tooltip: 'Health alerts',
          onPressed: () => _showAlertsDialog(context),
        ),
        if (hasAlerts)
          Positioned(
            right: 8,
            top:   8,
            child: Container(
              width:  8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  void _showAlertsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AlertsDialog(),
    );
  }
}

class _AlertsDialog extends StatelessWidget {
  const _AlertsDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (_, shield, __) {
        final alerts = shield.healthSnapshot?.alerts ?? [];
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications_outlined),
              SizedBox(width: 8),
              Text('Health Alerts'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: alerts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No alerts at this time.'),
                  )
                : ListView.separated(
                    shrinkWrap:    true,
                    itemCount:     alerts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final alert = alerts[i];
                      final color = _severityColor(alert.severity);
                      return ListTile(
                        leading: Icon(_severityIcon(alert.severity),
                            color: color),
                        title: Text(alert.message,
                            style: TextStyle(color: color)),
                        subtitle: Text(alert.code,
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Color _severityColor(HealthAlertSeverity s) {
    switch (s) {
      case HealthAlertSeverity.critical: return Colors.red;
      case HealthAlertSeverity.warning:  return Colors.orange;
      case HealthAlertSeverity.info:
      default:                           return Colors.blue;
    }
  }

  IconData _severityIcon(HealthAlertSeverity s) {
    switch (s) {
      case HealthAlertSeverity.critical: return Icons.error;
      case HealthAlertSeverity.warning:  return Icons.warning;
      case HealthAlertSeverity.info:
      default:                           return Icons.info;
    }
  }
}
