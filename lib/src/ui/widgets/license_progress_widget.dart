// lib/src/ui/widgets/license_progress_widget.dart
//
// LicenseProgressWidget – animated progress bar that visualizes how much
// of the license period has elapsed. Also provides a compact version.

import 'package:flutter/material.dart';
import '../themes/app_shield_colors.dart';
import '../../models/license_model.dart';

/// Visualises the remaining license period as a horizontal progress bar.
///
/// ```dart
/// LicenseProgressBar(license: shield.license!)
/// ```
class LicenseProgressBar extends StatelessWidget {
  const LicenseProgressBar({
    super.key,
    required this.license,
    this.showLabel    = true,
    this.height       = 8.0,
    this.borderRadius = 8.0,
  });

  final License license;
  final bool    showLabel;
  final double  height;
  final double  borderRadius;

  @override
  Widget build(BuildContext context) {
    if (license.isPerpetual) {
      return _PerpetualBadge();
    }

    final total = license.expiresAt
        .difference(license.activatedAt)
        .inDays
        .clamp(1, 999999);
    final elapsed = DateTime.now()
        .difference(license.activatedAt)
        .inDays
        .clamp(0, total);
    final progress = (elapsed / total).clamp(0.0, 1.0);
    final remaining = license.daysRemaining;
    final color     = _colorFor(remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              Text(
                remaining > 0
                    ? '$remaining days remaining'
                    : 'Expired',
                style: TextStyle(
                  fontSize:   12,
                  color:      color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}% elapsed',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // Background
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                ),
              ),
              // Progress fill
              AnimatedFractionallySizedBox(
                duration:      const Duration(milliseconds: 600),
                curve:         Curves.easeOutCubic,
                widthFactor:   progress,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withAlpha(180),
                        color,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _colorFor(int days) {
    if (days <= 0)  return AppShieldColors.expired;
    if (days <= 3)  return AppShieldColors.expired;
    if (days <= 7)  return AppShieldColors.warning;
    if (days <= 30) return AppShieldColors.trial;
    return AppShieldColors.active;
  }
}

class _PerpetualBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:        AppShieldColors.active.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: AppShieldColors.active.withAlpha(80)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.all_inclusive,
              size: 14, color: AppShieldColors.active),
          SizedBox(width: 6),
          Text('Perpetual License',
              style: TextStyle(
                color:      AppShieldColors.active,
                fontWeight: FontWeight.bold,
                fontSize:   12,
              )),
        ],
      ),
    );
  }
}

/// Compact circular progress indicator for the remaining license period.
///
/// ```dart
/// LicenseProgressRing(license: shield.license!, size: 48)
/// ```
class LicenseProgressRing extends StatelessWidget {
  const LicenseProgressRing({
    super.key,
    required this.license,
    this.size = 56.0,
  });

  final License license;
  final double  size;

  @override
  Widget build(BuildContext context) {
    if (license.isPerpetual) {
      return SizedBox(
        width:  size,
        height: size,
        child: const Center(
          child: Icon(Icons.all_inclusive,
              color: AppShieldColors.active),
        ),
      );
    }

    final total   = license.expiresAt
        .difference(license.activatedAt)
        .inDays
        .clamp(1, 999999);
    final remaining = license.daysRemaining.clamp(0, total);
    final progress  = remaining / total;
    final color     = _colorFor(license.daysRemaining);

    return SizedBox(
      width:  size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value:            progress,
            strokeWidth:      4,
            backgroundColor:  color.withAlpha(30),
            valueColor:       AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            license.daysRemaining <= 0
                ? '!'
                : '${license.daysRemaining}',
            style: TextStyle(
              fontSize:   size * 0.24,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(int days) {
    if (days <= 0)  return AppShieldColors.expired;
    if (days <= 7)  return AppShieldColors.warning;
    if (days <= 30) return AppShieldColors.trial;
    return AppShieldColors.active;
  }
}
