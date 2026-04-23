// example/lib/screens/dashboard_screen.dart
//
// Dashboard screen – shows license status, health, quick actions,
// license details, device info, seat usage, renewal banner, and
// license progress visualisation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/activation_dialog.dart';
import '../widgets/info_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RenewalReminder? _currentReminder;
  StreamSubscription<RenewalReminder>? _reminderSub;

  @override
  void initState() {
    super.initState();
    _startRenewalMonitoring();
  }

  void _startRenewalMonitoring() {
    final svc = RenewalReminderService.instance;
    if (!svc.isRunning) {
      svc.startMonitoring(
        licenseProvider: () =>
            AppShield.isInitialized ? AppShield.instance.currentLicense : null,
        checkInterval: const Duration(hours: 6),
      );
    }
    _reminderSub = svc.reminderStream.listen((reminder) {
      if (mounted) setState(() => _currentReminder = reminder);
    });
    // Also check now
    if (AppShield.isInitialized) {
      svc.checkNow(AppShield.instance.currentLicense);
    }
  }

  @override
  void dispose() {
    _reminderSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (context, shield, _) => Column(
        children: [
          // ── Renewal banner (shown when license is expiring) ──────────────
          RenewalBannerWidget(
            reminder:  _currentReminder,
            renewLabel: 'Renew Now',
            onDismiss:  () => setState(() => _currentReminder = null),
            onRenew: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening renewal page…'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // ── Offline banner ───────────────────────────────────────────────
          OfflineRetryWidget(
            isOffline:  shield.isOffline,
            isRetrying: shield.isValidating,
            onRetry:    () => shield.validateOnline(),
          ),

          // ── Scrollable content ───────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async { await shield.validateOnline(); },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Status + Health row ────────────────────────────────
                  _StatusRow(shield: shield),
                  const SizedBox(height: 20),

                  // ── Quick actions ──────────────────────────────────────
                  _SectionHeader(
                      title: 'Quick Actions',
                      icon: Icons.flash_on_outlined),
                  const SizedBox(height: 12),
                  _QuickActionsRow(shield: shield),
                  const SizedBox(height: 20),

                  // ── License progress bar ────────────────────────────────
                  if (shield.license != null) ...[
                    _SectionHeader(
                        title: 'License Period',
                        icon: Icons.hourglass_bottom_outlined),
                    const SizedBox(height: 12),
                    InfoCard(
                      child: LicenseProgressBar(
                          license: shield.license!),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── License details ────────────────────────────────────
                  if (shield.license != null) ...[
                    _SectionHeader(
                        title: 'License Details',
                        icon: Icons.badge_outlined),
                    const SizedBox(height: 12),
                    _LicenseDetailsCard(license: shield.license!),
                    const SizedBox(height: 20),
                  ],

                  // ── Device info ────────────────────────────────────────
                  _SectionHeader(
                      title: 'Device Info',
                      icon: Icons.computer_outlined),
                  const SizedBox(height: 12),
                  if (AppShield.isInitialized)
                    DeviceInfoWidget(
                      theme: AppShield.instance.config.resolvedTheme,
                    ),
                  const SizedBox(height: 20),

                  // ── Seat usage ─────────────────────────────────────────
                  if (AppShield.isInitialized &&
                      AppShield.instance.config.enableSeatPooling &&
                      shield.license != null) ...[
                    _SectionHeader(
                        title: 'Seat Usage',
                        icon: Icons.people_outline),
                    const SizedBox(height: 12),
                    SeatUsageWidget(
                      pool: LicensePoolManager(
                        license:    shield.license!,
                        totalSeats: AppShield.instance.config.totalSeats,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Error banner ───────────────────────────────────────
                  if (shield.lastError != null) ...[
                    _ErrorBanner(message: shield.lastError!),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status + Health row ───────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.shield});
  final AppShieldProvider shield;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          Expanded(
            flex: 2,
            child: AppShield.isInitialized
                ? StatusCard(
                    status: shield.status,
                    theme:  AppShield.instance.config.resolvedTheme,
                  )
                : _PlaceholderCard(label: 'License status unavailable'),
          ),
          const SizedBox(width: 16),
          // Health card
          Expanded(
            flex: 3,
            child: shield.healthSnapshot != null
                ? LicenseHealthCard(
                    snapshot: shield.healthSnapshot!,
                    onResolve: (alert) =>
                        _handleAlert(context, alert, shield),
                  )
                : _PlaceholderCard(
                    label: 'Health monitoring starting…'),
          ),
        ],
      ),
    );
  }

  void _handleAlert(BuildContext context, HealthAlert alert,
      AppShieldProvider shield) {
    if (alert.code == 'LICENSE_EXPIRED' ||
        alert.code == 'EXPIRY_IMMINENT') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alert.message),
          action: SnackBarAction(
            label: 'Renew',
            onPressed: () {},
          ),
        ),
      );
    } else if (alert.code == 'VALIDATION_STALE') {
      shield.validateOnline();
    }
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.shield});
  final AppShieldProvider shield;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:     12,
      runSpacing:  12,
      children: [
        _ActionCard(
          icon:    Icons.refresh_outlined,
          label:   'Validate Online',
          color:   AppShieldColors.primary,
          loading: shield.isValidating,
          onTap:   shield.validateOnline,
        ),
        _ActionCard(
          icon:    shield.isLicenseValid
              ? Icons.remove_circle_outline
              : Icons.check_circle_outline,
          label:   shield.isLicenseValid ? 'Deactivate' : 'Activate',
          color:   shield.isLicenseValid
              ? AppShieldColors.expired
              : AppShieldColors.active,
          loading: shield.isActivating,
          onTap:   () => shield.isLicenseValid
              ? _confirmDeactivate(context, shield)
              : showDialog(
                  context: context,
                  builder: (_) => ActivationDialog(shield: shield),
                ),
        ),
        _ActionCard(
          icon:  Icons.star_outline,
          label: 'Start Trial',
          color: AppShieldColors.trial,
          onTap: () => _startTrial(context, shield),
        ),
        _ActionCard(
          icon:  Icons.info_outline,
          label: 'License Info',
          color: AppShieldColors.info,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LicenseInfoScreen()),
          ),
        ),
        _ActionCard(
          icon:  Icons.restore_outlined,
          label: 'Restore',
          color: AppShieldColors.warning,
          onTap: () => _showRestoreDialog(context, shield),
        ),
        _ActionCard(
          icon:  Icons.security_outlined,
          label: 'Tamper Check',
          color: AppShieldColors.revoked,
          onTap: () => _runTamperCheck(context),
        ),
      ],
    );
  }

  void _confirmDeactivate(BuildContext context, AppShieldProvider shield) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Deactivate License'),
        content: const Text(
            'Are you sure you want to deactivate on this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppShieldColors.expired),
            onPressed: () async {
              Navigator.pop(context);
              await shield.deactivate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('License deactivated.')),
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
              ? 'Trial started! Enjoy your evaluation period.'
              : 'Trial unavailable. It may have already been used.'),
        ),
      );
    }
  }

  void _showRestoreDialog(BuildContext context, AppShieldProvider shield) {
    final keyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Restore License'),
        content: SizedBox(
          width: 360,
          child: LicenseInputField(
            controller: keyCtrl,
            theme: AppShield.isInitialized
                ? AppShield.instance.config.resolvedTheme
                : AppShieldTheme.light(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result =
                  await shield.activate(keyCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.success
                        ? 'License restored successfully!'
                        : result.errorMessage ?? 'Restore failed.'),
                  ),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _runTamperCheck(BuildContext context) async {
    final records = await TamperDetector.instance.runChecks();
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tamper Check Results'),
          content: SizedBox(
            width: 400,
            child: records.isEmpty
                ? const Text('✓ No tamper issues detected.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: records.length,
                    itemBuilder: (_, i) {
                      final r = records[i];
                      return ListTile(
                        leading: const Icon(Icons.warning,
                            color: Colors.red),
                        title: Text(r.tamperType),
                        subtitle: Text('Tampering detected'),
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
        ),
      );
    }
  }
}

// ── Action card ───────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  final bool         loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: loading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                loading
                    ? SizedBox(
                        width:  22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color:      color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── License details card ──────────────────────────────────────────────────

class _LicenseDetailsCard extends StatelessWidget {
  const _LicenseDetailsCard({required this.license});
  final License license;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key row
          _KeyRow(licenseKey: license.key),
          const Divider(height: 20),

          Wrap(
            spacing:    40,
            runSpacing: 12,
            children: [
              _Field('Plan',       license.plan.toUpperCase(), bold: true),
              _Field('Type',       license.type.name),
              _Field('Status',     license.status.name),
              _Field('Customer',   license.customerName ?? '—'),
              _Field('Email',      license.customerEmail ?? '—'),
              _Field('Activated',
                  AppShieldHelpers.formatDate(license.activatedAt)),
              _Field('Expires',    license.isPerpetual
                  ? 'Never (Perpetual)'
                  : '${AppShieldHelpers.formatDate(license.expiresAt)} '
                    '(${license.daysRemaining} days)'),
              _Field('Device ID',
                  AppShieldHelpers.truncate(license.deviceId, 24)),
            ],
          ),

          if (license.isExpiringSoon) ...[
            const SizedBox(height: 12),
            ExpiryBadge(daysLeft: license.daysRemaining),
          ],
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.licenseKey});
  final String licenseKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.vpn_key_outlined,
            size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          AppShieldHelpers.obfuscateLicenseKey(licenseKey),
          style: const TextStyle(
            fontFamily: 'Courier New',
            fontSize:   14,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon:    const Icon(Icons.copy, size: 16),
          tooltip: 'Copy key',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: licenseKey));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('License key copied!')),
            );
          },
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool   bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.bold : null,
            )),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.red.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder card ──────────────────────────────────────────────────────

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Center(
        child: Text(label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String   title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18,
            color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}
