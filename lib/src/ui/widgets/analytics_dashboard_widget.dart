// lib/src/ui/widgets/analytics_dashboard_widget.dart
//
// Batch 12 – Advanced UI: Compact analytics dashboard widget.

import 'package:flutter/material.dart';
import '../../core/license_analytics.dart';
import '../themes/app_shield_colors.dart';

/// A compact analytics dashboard showing key license metrics.
///
/// ```dart
/// FutureBuilder<LicenseUsageReport>(
///   future: LicenseAnalytics.instance.generateReport('com.myapp'),
///   builder: (ctx, snap) => snap.hasData
///     ? AnalyticsDashboardWidget(report: snap.data!)
///     : const CircularProgressIndicator(),
/// )
/// ```
class AnalyticsDashboardWidget extends StatelessWidget {
  const AnalyticsDashboardWidget({
    super.key,
    required this.report,
    this.showFeatureChart = true,
    this.compact          = false,
  });

  final LicenseUsageReport report;
  final bool               showFeatureChart;
  final bool               compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) return _buildCompact(theme);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const Divider(height: 24),
            _buildMetricsGrid(theme),
            if (showFeatureChart && report.featureUsage.isNotEmpty) ...[
              const Divider(height: 24),
              _buildFeatureChart(theme),
            ],
            const SizedBox(height: 8),
            Text(
              'Generated: ${_fmt(report.generatedAt)}',
              style: const TextStyle(fontSize: 11, color: AppShieldColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MiniStat(
          label: 'Sessions',
          value: report.sessionCount.toString(),
          icon:  Icons.play_circle_outline,
          color: AppShieldColors.primary,
        ),
        _MiniStat(
          label: 'Activations',
          value: report.activations.toString(),
          icon:  Icons.verified_outlined,
          color: AppShieldColors.active,
        ),
        _MiniStat(
          label: 'Tamper Attempts',
          value: report.tamperAttempts.toString(),
          icon:  Icons.security,
          color: report.tamperAttempts > 0
              ? AppShieldColors.expired
              : AppShieldColors.active,
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.bar_chart, size: 20),
        const SizedBox(width: 8),
        Text('License Analytics',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        if (report.currentPlan != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AppShieldColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              report.currentPlan!.toUpperCase(),
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color:      AppShieldColors.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap:     true,
      physics:        const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing:  8,
      childAspectRatio: 1.5,
      children: [
        _MetricTile(
          label: 'Sessions',
          value: report.sessionCount,
          icon:  Icons.play_circle_outline,
          color: AppShieldColors.primary,
        ),
        _MetricTile(
          label: 'Activations',
          value: report.activations,
          icon:  Icons.verified_outlined,
          color: AppShieldColors.active,
        ),
        _MetricTile(
          label: 'Validations',
          value: report.validations,
          icon:  Icons.refresh,
          color: AppShieldColors.info,
        ),
        _MetricTile(
          label: 'Deactivations',
          value: report.deactivations,
          icon:  Icons.remove_circle_outline,
          color: AppShieldColors.gracePeriod,
        ),
        _MetricTile(
          label: 'Tamper',
          value: report.tamperAttempts,
          icon:  Icons.security,
          color: report.tamperAttempts > 0
              ? AppShieldColors.expired
              : AppShieldColors.active,
        ),
        _MetricTile(
          label: 'Total Events',
          value: report.totalEvents,
          icon:  Icons.timeline,
          color: AppShieldColors.accent,
        ),
      ],
    );
  }

  Widget _buildFeatureChart(ThemeData theme) {
    final sorted = report.featureUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feature Usage',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...sorted.take(6).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(fontSize: 12)),
                      Text('${entry.value}x',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppShieldColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           entry.value / maxVal,
                      backgroundColor: AppShieldColors.border,
                      valueColor:      const AlwaysStoppedAnimation<Color>(
                          AppShieldColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} UTC';
}

// ── Supporting sub-widgets ─────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      color,
            ),
          ),
          Text(label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.bold,
              color:      color,
            )),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppShieldColors.textMuted)),
      ],
    );
  }
}
