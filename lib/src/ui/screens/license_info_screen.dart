// lib/src/ui/screens/license_info_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_shield.dart';
import '../../models/license_model.dart';
import '../../utils/helpers.dart';
import '../themes/app_shield_colors.dart';
import '../widgets/expiry_badge.dart';
import '../widgets/feature_list_widget.dart';
import '../widgets/status_card.dart';

/// Displays full details of the current license.
class LicenseInfoScreen extends StatefulWidget {
  const LicenseInfoScreen({super.key});

  @override
  State<LicenseInfoScreen> createState() => _LicenseInfoScreenState();
}

class _LicenseInfoScreenState extends State<LicenseInfoScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await AppShield.instance.validateOnline();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _deactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate License'),
        content: const Text(
            'Are you sure you want to deactivate this device? '
            'You will need to re-activate to use the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deactivate',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await AppShield.instance.deactivate();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = AppShield.instance.config.resolvedTheme;
    final license = AppShield.instance.currentLicense;

    if (license == null) {
      return Scaffold(
        appBar:   AppBar(title: const Text('License Info')),
        body:     const Center(child: Text('No license found.')),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title:       const Text('License Information'),
        actions: [
          IconButton(
            icon:      _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip:   'Refresh',
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Status card ─────────────────────────────────────────────────
          StatusCard(status: license.status, theme: theme),
          const SizedBox(height: 16),

          // ── Main info ────────────────────────────────────────────────────
          _Section(
            title: 'License Details',
            theme: theme,
            children: [
              _InfoRow(
                label: 'License Key',
                value: AppShieldHelpers.obfuscateLicenseKey(license.key),
                copyValue: license.key,
              ),
              _InfoRow(label: 'Plan',        value: license.plan.toUpperCase()),
              _InfoRow(label: 'Type',        value: license.type.name),
              _InfoRow(label: 'Status',      value: license.status.name,
                  valueColor: AppShieldColors.forStatus(license.status.name)),
              _InfoRow(label: 'Activated',   value: AppShieldHelpers.formatDate(license.activatedAt)),
              _InfoRow(
                label: 'Expires',
                value: license.isPerpetual
                    ? 'Never (Perpetual)'
                    : AppShieldHelpers.formatDate(license.expiresAt),
                trailing: license.isPerpetual
                    ? null
                    : ExpiryBadge(daysLeft: license.daysRemaining),
              ),
              if (license.lastValidatedAt != null)
                _InfoRow(label: 'Last Validated',
                    value: AppShieldHelpers.formatDateTime(license.lastValidatedAt!)),
              if (license.customerEmail != null)
                _InfoRow(label: 'Registered Email', value: license.customerEmail!),
            ],
          ),
          const SizedBox(height: 16),

          // ── Device ───────────────────────────────────────────────────────
          _Section(
            title: 'Device',
            theme: theme,
            children: [
              _InfoRow(
                label: 'Device ID',
                value: license.deviceId,
                copyValue: license.deviceId,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Features ─────────────────────────────────────────────────────
          _Section(
            title: 'Features',
            theme: theme,
            children: [
              FeatureListWidget(features: license.features),
            ],
          ),
          const SizedBox(height: 16),

          // ── Limits ───────────────────────────────────────────────────────
          if (license.limits.isNotEmpty)
            _Section(
              title: 'Limits',
              theme: theme,
              children: [
                for (final entry in license.limits.entries)
                  _InfoRow(
                    label: entry.key.replaceAll('_', ' ').toUpperCase(),
                    value: entry.value.toString(),
                  ),
              ],
            ),
          const SizedBox(height: 28),

          // ── Actions ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon:  const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _isRefreshing ? null : _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon:  const Icon(Icons.upgrade),
                  label: const Text('Upgrade'),
                  onPressed: () {
                    final url = AppShield.instance.config.buyLicenseUrl;
                    debugPrint('Open: $url');
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon:  const Icon(Icons.phonelink_erase_outlined, color: Colors.red),
            label: const Text('Deactivate This Device',
                style: TextStyle(color: Colors.red)),
            onPressed: _deactivate,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.theme, required this.children});
  final String title;
  final theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color:        theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: theme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Colors.grey)),
            ),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(12), child: Column(children: children)),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyValue,
    this.valueColor,
    this.trailing,
  });
  final String  label;
  final String  value;
  final String? copyValue;
  final Color?  valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: valueColor)),
            ),
            if (trailing != null) trailing!,
            if (copyValue != null)
              IconButton(
                icon:    const Icon(Icons.copy_outlined, size: 16),
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copyValue!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
          ],
        ),
      );
}
