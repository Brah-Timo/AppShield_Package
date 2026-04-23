// lib/src/ui/widgets/expiry_badge.dart

import 'package:flutter/material.dart';
import '../themes/app_shield_colors.dart';

/// Compact badge showing days remaining until expiry.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.daysLeft});
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (daysLeft <= 3)       color = AppShieldColors.expired;
    else if (daysLeft <= 7)  color = AppShieldColors.warning;
    else if (daysLeft <= 30) color = AppShieldColors.trial;
    else                     color = AppShieldColors.active;

    final label = daysLeft <= 0
        ? 'Expired'
        : '$daysLeft day${daysLeft == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(128)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color:      color,
            fontSize:   11,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}
