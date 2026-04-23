// lib/src/ui/widgets/seat_usage_widget.dart
//
// Batch 12 – Advanced UI: Visual seat-usage progress bar for enterprise pools.

import 'package:flutter/material.dart';
import '../../core/license_pool_manager.dart';
import '../themes/app_shield_colors.dart';

/// Displays a progress bar showing used vs available seats.
///
/// ```dart
/// SeatUsageWidget(pool: myLicensePoolManager)
/// ```
class SeatUsageWidget extends StatelessWidget {
  const SeatUsageWidget({
    super.key,
    required this.pool,
    this.showSeatList = false,
    this.compact      = false,
  });

  final LicensePoolManager pool;
  final bool               showSeatList;
  final bool               compact;

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final used      = pool.usedSeats;
    final total     = pool.totalSeats;
    final available = pool.availableSeats;
    final pct       = total > 0 ? used / total : 0.0;
    final barColor  = pct >= 0.9
        ? AppShieldColors.expired
        : pct >= 0.7
            ? AppShieldColors.warning
            : AppShieldColors.active;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_outlined,
              size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text('$used / $total seats',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w500,
                color:      barColor,
              )),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Seat Usage',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        barColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$available available',
                    style: TextStyle(
                      fontSize: 12,
                      color:    barColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:            pct,
                backgroundColor:  AppShieldColors.border,
                valueColor:       AlwaysStoppedAnimation<Color>(barColor),
                minHeight:        8,
              ),
            ),
            const SizedBox(height: 8),

            // Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$used used',
                    style: theme.textTheme.bodySmall),
                Text('$total total',
                    style: theme.textTheme.bodySmall),
              ],
            ),

            // Seat list
            if (showSeatList && pool.activeSeats.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Active Seats',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pool.activeSeats.map(
                (s) => _SeatTile(seat: s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat});
  final LicenseSeat seat;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense:   true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: AppShieldColors.primary.withAlpha(30),
        child: Text(
          (seat.userName ?? seat.userId).substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.bold,
            color:      AppShieldColors.primary,
          ),
        ),
      ),
      title:    Text(seat.userName ?? seat.userId,
          style: const TextStyle(fontSize: 13)),
      subtitle: seat.userEmail != null
          ? Text(seat.userEmail!,
              style: const TextStyle(fontSize: 11))
          : null,
      trailing: Text(
        _formatDate(seat.assignedAt),
        style: const TextStyle(fontSize: 11, color: AppShieldColors.textMuted),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
