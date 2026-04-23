// example/lib/screens/settings_screen.dart
//
// Settings screen – license management, configuration info,
// theme toggle, reset, and debug tools.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/info_card.dart';
import '../widgets/activation_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode    themeMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (context, shield, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── License management ───────────────────────────────────────
            SectionTitle('License Management',
                icon: Icons.vpn_key_outlined),
            _LicenseManagementCard(shield: shield),
            const SizedBox(height: 20),

            // ── Configuration ────────────────────────────────────────────
            SectionTitle('Configuration',
                icon: Icons.settings_outlined),
            _ConfigCard(),
            const SizedBox(height: 20),

            // ── Appearance ───────────────────────────────────────────────
            SectionTitle('Appearance',
                icon: Icons.palette_outlined),
            InfoCard(
              child: SwitchListTile(
                title:    const Text('Dark Mode'),
                subtitle: const Text('Toggle light / dark theme'),
                value:    themeMode == ThemeMode.dark,
                onChanged: (_) => onToggleTheme(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Debug tools ──────────────────────────────────────────────
            SectionTitle('Developer Tools',
                icon: Icons.developer_mode_outlined),
            _DeveloperToolsCard(shield: shield),
            const SizedBox(height: 20),

            // ── Danger zone ──────────────────────────────────────────────
            SectionTitle('Danger Zone',
                icon: Icons.warning_amber_outlined),
            _DangerZoneCard(),
          ],
        );
      },
    );
  }
}

// ── License management card ───────────────────────────────────────────────

class _LicenseManagementCard extends StatelessWidget {
  const _LicenseManagementCard({required this.shield});
  final AppShieldProvider shield;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          // Activate
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title:   const Text('Activate License'),
            subtitle: const Text('Enter a license key to activate'),
            trailing: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ActivationDialog(shield: shield),
              ),
              child: const Text('Activate'),
            ),
          ),
          const Divider(height: 1),

          // Validate
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title:   const Text('Validate Online'),
            subtitle: const Text('Force an immediate online validation'),
            trailing: shield.isValidating
                ? const SizedBox(
                    width:  20,
                    height: 20,
                    child:  CircularProgressIndicator(strokeWidth: 2))
                : OutlinedButton(
                    onPressed: () => shield.validateOnline(),
                    child: const Text('Validate'),
                  ),
          ),
          const Divider(height: 1),

          // Deactivate
          if (shield.isLicenseValid) ...[
            ListTile(
              leading: const Icon(Icons.cancel_outlined,
                  color: Colors.red),
              title: const Text('Deactivate',
                  style: TextStyle(color: Colors.red)),
              subtitle:
                  const Text('Remove this device from the license'),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => _confirmDeactivate(context, shield),
                child: const Text('Deactivate'),
              ),
            ),
            const Divider(height: 1),
          ],

          // Trial
          ListTile(
            leading: const Icon(Icons.star_outline),
            title:   const Text('Start Trial'),
            subtitle: const Text('Begin your free evaluation period'),
            trailing: OutlinedButton(
              onPressed: () => _startTrial(context, shield),
              child: const Text('Start Trial'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(BuildContext context, AppShieldProvider shield) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Deactivate License'),
        content: const Text(
            'This will deactivate your license on this device. '
            'You can re-activate it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await shield.deactivate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('License deactivated.')),
                );
              }
            },
            child: const Text('Deactivate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrial(
      BuildContext context, AppShieldProvider shield) async {
    final ok = await shield.startTrial();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✓ Trial started!'
              : 'Could not start trial.'),
        ),
      );
    }
  }
}

// ── Configuration card ────────────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!AppShield.isInitialized) {
      return const InfoCard(
        child: Text('AppShield not initialized.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final config = AppShield.instance.config;

    return InfoCard(
      child: Column(
        children: [
          _SettingsRow('App ID',          config.appId),
          _SettingsRow('API Base URL',     config.apiBaseUrl),
          _SettingsRow('Offline Mode',     config.enableOfflineMode ? 'Enabled' : 'Disabled'),
          _SettingsRow('Trial',            config.enableTrial ? 'Enabled (${config.trialDays}d)' : 'Disabled'),
          _SettingsRow('Device Binding',   config.enableDeviceBinding ? 'Enabled (max ${config.maxDevicesPerLicense})' : 'Disabled'),
          _SettingsRow('Clock Check',      config.enableClockCheck ? 'Enabled' : 'Disabled'),
          _SettingsRow('Validation Interval', '${config.validationIntervalHr}h'),
          _SettingsRow('Analytics',        config.enableAnalytics ? 'Enabled' : 'Disabled'),
          _SettingsRow('Health Monitor',   config.enableHealthMonitor ? 'Enabled' : 'Disabled'),
          _SettingsRow('Webhooks',         config.enableWebhooks ? 'Enabled' : 'Disabled'),
          _SettingsRow('License Cache',    config.enableLicenseCache ? 'Enabled (${config.cacheTTLMinutes}m TTL)' : 'Disabled'),
          _SettingsRow('Multi-Tenant',     config.enableMultiTenant ? 'Enabled' : 'Disabled'),
          _SettingsRow('Seat Pooling',     config.enableSeatPooling ? 'Enabled (${config.totalSeats} seats)' : 'Disabled'),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

// ── Developer tools card ──────────────────────────────────────────────────

class _DeveloperToolsCard extends StatelessWidget {
  const _DeveloperToolsCard({required this.shield});
  final AppShieldProvider shield;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          // Copy device fingerprint
          ListTile(
            leading: const Icon(Icons.fingerprint_outlined),
            title:   const Text('Copy Device Fingerprint'),
            subtitle: const Text('Copy this device\'s unique fingerprint'),
            trailing: IconButton(
              icon:    const Icon(Icons.copy),
              onPressed: () async {
                if (!AppShield.isInitialized) return;
                final fp = await DeviceFingerprintService.instance
                    .getFingerprint();
                if (context.mounted) {
                  await Clipboard.setData(ClipboardData(text: fp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Fingerprint copied!')),
                  );
                }
              },
            ),
          ),
          const Divider(height: 1),

          // Clear fingerprint cache
          ListTile(
            leading: const Icon(Icons.cached_outlined),
            title:   const Text('Clear Fingerprint Cache'),
            subtitle: const Text('Force recomputation of device fingerprint'),
            trailing: OutlinedButton(
              onPressed: () {
                DeviceFingerprintService.instance.clearCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Fingerprint cache cleared.')),
                );
              },
              child: const Text('Clear'),
            ),
          ),
          const Divider(height: 1),

          // Invalidate license cache
          ListTile(
            leading: const Icon(Icons.clear_all_outlined),
            title:   const Text('Invalidate License Cache'),
            subtitle: const Text('Clear the in-memory license cache'),
            trailing: OutlinedButton(
              onPressed: () {
                if (AppShield.isInitialized) {
                  AppShield.instance.invalidateLicenseCache();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('License cache invalidated.')),
                  );
                }
              },
              child: const Text('Invalidate'),
            ),
          ),
          const Divider(height: 1),

          // Show license JSON
          ListTile(
            leading: const Icon(Icons.data_object_outlined),
            title:   const Text('View License JSON'),
            subtitle: const Text('Show raw license data'),
            trailing: OutlinedButton(
              onPressed: shield.license != null
                  ? () => _showLicenseJson(context, shield.license!)
                  : null,
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLicenseJson(BuildContext context, License license) {
    final json = const JsonEncoder.withIndent('  ')
        .convert(license.toJson());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('License JSON'),
        content: SizedBox(
          width:  560,
          height: 400,
          child:  SingleChildScrollView(
            child: SelectableText(
              json,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize:   12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON copied!')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Danger zone card ──────────────────────────────────────────────────────

class _DangerZoneCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: ListTile(
        leading: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text('Reset AppShield',
            style: TextStyle(color: Colors.red)),
        subtitle: const Text(
            'Wipe ALL stored license data, analytics, and settings. '
            'This cannot be undone.',
            style: TextStyle(color: Colors.red, fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () => _confirmReset(context),
          child: const Text('Reset',
              style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Reset',
                style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
            'This will permanently delete all AppShield data on this device '
            'including licenses, analytics, and device bindings.\n\n'
            'Are you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await AppShield.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('AppShield has been reset.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Yes, Reset',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


