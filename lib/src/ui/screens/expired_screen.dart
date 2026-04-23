// lib/src/ui/screens/expired_screen.dart

import 'package:flutter/material.dart';
import '../../../app_shield.dart';
import '../../models/license_model.dart';
import '../../utils/helpers.dart';
import '../themes/app_shield_colors.dart';

/// Shown when the license has expired, been revoked, or suspended.
class ExpiredScreen extends StatefulWidget {
  const ExpiredScreen({
    super.key,
    this.onActivate,
    this.message,
  });

  final VoidCallback? onActivate;
  final String?       message;

  @override
  State<ExpiredScreen> createState() => _ExpiredScreenState();
}

class _ExpiredScreenState extends State<ExpiredScreen> {
  Future<void> _openBuy() async {
    final url = AppShield.instance.config.buyLicenseUrl;
    debugPrint('Open buy URL: $url');
  }

  Future<void> _openSupport() async {
    final url = AppShield.instance.config.supportUrl;
    debugPrint('Open support URL: $url');
  }

  void _goToActivation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActivationScreen(onActivated: widget.onActivate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme     = AppShield.instance.config.resolvedTheme;
    final license   = AppShield.instance.currentLicense;
    final status    = license?.status;
    final isRevoked = status == LicenseStatus.revoked;
    final color     = isRevoked ? AppShieldColors.revoked : AppShieldColors.expired;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── Icon ──────────────────────────────────────────────────────
              Center(
                child: Container(
                  width:  100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRevoked
                        ? Icons.block_outlined
                        : Icons.timer_off_outlined,
                    size:  54,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                isRevoked ? 'License Revoked' : 'License Expired',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:      color,
                    ),
              ),
              const SizedBox(height: 12),

              // ── Message ───────────────────────────────────────────────────
              Text(
                widget.message ??
                    (isRevoked
                        ? 'Your license has been revoked. '
                          'Please contact support for assistance.'
                        : 'Your license expired on '
                          '${AppShieldHelpers.formatDate(license?.expiresAt ?? DateTime.now())}. '
                          'Please renew to continue using the app.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: theme.subtitleColor),
              ),
              const SizedBox(height: 32),

              // ── Info card ─────────────────────────────────────────────────
              if (license != null)
                _InfoCard(license: license, theme: theme),
              const SizedBox(height: 28),

              // ── Actions ───────────────────────────────────────────────────
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize:     const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon:  const Icon(Icons.shopping_cart_outlined),
                label: const Text(
                  'Renew / Buy License',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _openBuy,
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon:      const Icon(Icons.vpn_key_outlined),
                label:     const Text('Enter New License Key'),
                onPressed: _goToActivation,
              ),
              const SizedBox(height: 12),

              TextButton.icon(
                icon:      const Icon(Icons.support_agent_outlined),
                label:     const Text('Contact Support'),
                onPressed: _openSupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.license, required this.theme});
  final License license;
  final dynamic theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        theme.cardColor as Color,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: theme.borderColor as Color),
        ),
        child: Column(
          children: [
            _Row(label: 'Plan',        value: license.plan),
            _Row(
              label: 'Expired On',
              value: AppShieldHelpers.formatDate(license.expiresAt),
            ),
            _Row(
              label: 'License Key',
              value: AppShieldHelpers.obfuscateLicenseKey(license.key),
            ),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize:   13,
              ),
            ),
          ],
        ),
      );
}
