// lib/src/ui/widgets/license_summary_widget.dart
//
// LicenseSummaryWidget – a compact summary card that shows the most
// important license information at a glance.

import 'package:flutter/material.dart';
import '../../models/license_model.dart';
import '../themes/app_shield_colors.dart';
import '../themes/app_shield_theme.dart';
import '../../utils/helpers.dart';

/// Compact summary card for a [License].
///
/// Suitable for embedding in headers, sidebars, or overview panels.
///
/// ```dart
/// LicenseSummaryWidget(
///   license: AppShield.instance.currentLicense!,
///   theme:   AppShield.instance.config.resolvedTheme,
/// )
/// ```
class LicenseSummaryWidget extends StatelessWidget {
  const LicenseSummaryWidget({
    super.key,
    required this.license,
    required this.theme,
    this.compact = false,
    this.onTap,
  });

  final License         license;
  final AppShieldTheme  theme;
  final bool            compact;
  final VoidCallback?   onTap;

  @override
  Widget build(BuildContext context) {
    return compact ? _CompactCard(this) : _FullCard(this);
  }
}

// ── Full card ─────────────────────────────────────────────────────────────

class _FullCard extends StatelessWidget {
  const _FullCard(this.w);
  final LicenseSummaryWidget w;

  @override
  Widget build(BuildContext context) {
    final license = w.license;
    final color   = _statusColor(license.status);

    return Material(
      color:        w.theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: w.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        color.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _statusIcon(license.status),
                      color: color,
                      size:  20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          license.plan.toUpperCase(),
                          style: TextStyle(
                            color:      color,
                            fontWeight: FontWeight.bold,
                            fontSize:   14,
                          ),
                        ),
                        Text(
                          license.status.name,
                          style: TextStyle(
                            color:    w.theme.subtitleColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!license.isPerpetual)
                    _DaysChip(daysRemaining: license.daysRemaining),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: w.theme.borderColor, height: 1),
              const SizedBox(height: 10),

              // Key + customer
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      label: 'Key',
                      value: AppShieldHelpers.obfuscateLicenseKey(
                          license.key),
                      theme: w.theme,
                      mono:  true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoItem(
                      label: 'Customer',
                      value: license.customerName ?? '—',
                      theme: w.theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      label: 'Activated',
                      value: AppShieldHelpers.formatDate(
                          license.activatedAt),
                      theme: w.theme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoItem(
                      label: 'Expires',
                      value: license.isPerpetual
                          ? 'Never'
                          : AppShieldHelpers.formatDate(
                              license.expiresAt),
                      theme: w.theme,
                    ),
                  ),
                ],
              ),

              if (license.features.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing:    6,
                  runSpacing: 4,
                  children: license.features.entries
                      .where((e) => e.value)
                      .take(6)
                      .map((e) => _FeatureChip(featureKey: e.key, theme: w.theme))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact card ──────────────────────────────────────────────────────────

class _CompactCard extends StatelessWidget {
  const _CompactCard(this.w);
  final LicenseSummaryWidget w;

  @override
  Widget build(BuildContext context) {
    final license = w.license;
    final color   = _statusColor(license.status);

    return Material(
      color:        w.theme.cardColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: w.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(_statusIcon(license.status), color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                license.plan.toUpperCase(),
                style: TextStyle(
                  color:      color,
                  fontWeight: FontWeight.bold,
                  fontSize:   12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${license.status.name}',
                style: TextStyle(
                  color:    w.theme.subtitleColor,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (!license.isPerpetual)
                _DaysChip(daysRemaining: license.daysRemaining),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

Color _statusColor(LicenseStatus s) {
  switch (s) {
    case LicenseStatus.active:          return AppShieldColors.active;
    case LicenseStatus.trial:           return AppShieldColors.trial;
    case LicenseStatus.gracePeriod:     return AppShieldColors.gracePeriod;
    case LicenseStatus.expired:         return AppShieldColors.expired;
    case LicenseStatus.revoked:         return AppShieldColors.revoked;
    case LicenseStatus.notActivated:    return Colors.grey;
    default:                            return Colors.grey;
  }
}

IconData _statusIcon(LicenseStatus s) {
  switch (s) {
    case LicenseStatus.active:       return Icons.verified_rounded;
    case LicenseStatus.trial:        return Icons.star_rounded;
    case LicenseStatus.gracePeriod:  return Icons.timer_rounded;
    case LicenseStatus.expired:      return Icons.cancel_rounded;
    case LicenseStatus.revoked:      return Icons.block_rounded;
    default:                         return Icons.help_outline_rounded;
  }
}

class _DaysChip extends StatelessWidget {
  const _DaysChip({required this.daysRemaining});
  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (daysRemaining <= 0)  color = AppShieldColors.expired;
    else if (daysRemaining <= 7)  color = AppShieldColors.warning;
    else if (daysRemaining <= 30) color = AppShieldColors.trial;
    else                          color = AppShieldColors.active;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        daysRemaining <= 0 ? 'Expired' : '${daysRemaining}d',
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
    required this.theme,
    this.mono = false,
  });
  final String         label;
  final String         value;
  final AppShieldTheme theme;
  final bool           mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 10,
              color:    theme.subtitleColor,
            )),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize:   12,
            color:      theme.textColor,
            fontFamily: mono ? 'Courier New' : null,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.featureKey, required this.theme});
  final String         featureKey;
  final AppShieldTheme theme;

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        AppShieldColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        featureKey.replaceAll('_', ' '),
        style: const TextStyle(
          fontSize:   10,
          color:      AppShieldColors.primary,
        ),
      ),
    );
  }
}
