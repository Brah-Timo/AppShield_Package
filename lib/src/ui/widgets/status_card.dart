// lib/src/ui/widgets/status_card.dart

import 'package:flutter/material.dart';
import '../../models/license_model.dart';
import '../themes/app_shield_colors.dart';
import '../themes/app_shield_theme.dart';
// FIX: status_card.dart lives in lib/src/ui/widgets/
//      app_shield.dart lives in lib/
//      Correct relative path is 3 levels up: ../../../app_shield.dart
import '../../../app_shield.dart' show AppShield;

/// Displays the current license status with color-coding and an icon.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    required this.theme,
  });

  final LicenseStatus  status;
  final AppShieldTheme theme;

  @override
  Widget build(BuildContext context) {
    final color   = AppShieldColors.forStatus(status.name);
    final label   = _label(status);
    final icon    = _icon(status);
    final license = AppShield.isInitialized
        ? AppShield.instance.currentLicense
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color:  color.withAlpha(38),
              shape:  BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
                if (license != null && !license.isPerpetual &&
                    (status == LicenseStatus.active ||
                     status == LicenseStatus.trial ||
                     status == LicenseStatus.gracePeriod))
                  Text(
                    '${license.daysRemaining} day(s) remaining',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.subtitleColor),
                  ),
              ],
            ),
          ),
          _StatusDot(color: color),
        ],
      ),
    );
  }

  static String _label(LicenseStatus s) {
    switch (s) {
      case LicenseStatus.active:         return 'Active';
      case LicenseStatus.trial:          return 'Trial Mode';
      case LicenseStatus.gracePeriod:    return 'Grace Period';
      case LicenseStatus.expired:        return 'Expired';
      case LicenseStatus.revoked:        return 'Revoked';
      case LicenseStatus.suspended:      return 'Suspended';
      case LicenseStatus.tampered:       return 'Security Issue';
      case LicenseStatus.deviceMismatch: return 'Device Mismatch';
      case LicenseStatus.offline:        return 'Offline';
      case LicenseStatus.notActivated:   return 'Not Activated';
    }
  }

  static IconData _icon(LicenseStatus s) {
    switch (s) {
      case LicenseStatus.active:         return Icons.verified_outlined;
      case LicenseStatus.trial:          return Icons.science_outlined;
      case LicenseStatus.gracePeriod:    return Icons.hourglass_bottom_outlined;
      case LicenseStatus.expired:        return Icons.timer_off_outlined;
      case LicenseStatus.revoked:        return Icons.block_outlined;
      case LicenseStatus.suspended:      return Icons.pause_circle_outline;
      case LicenseStatus.tampered:       return Icons.gpp_bad_outlined;
      case LicenseStatus.deviceMismatch: return Icons.devices_other_outlined;
      case LicenseStatus.offline:        return Icons.cloud_off_outlined;
      case LicenseStatus.notActivated:   return Icons.lock_outline;
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
