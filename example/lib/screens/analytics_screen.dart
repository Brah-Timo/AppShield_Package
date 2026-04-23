// example/lib/screens/analytics_screen.dart
//
// Analytics screen – shows usage report, metrics, session data,
// and feature access analytics.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/info_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  LicenseUsageReport? _report;
  List<LicenseMetric> _recentMetrics = [];
  bool                _loading       = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!AppShield.isInitialized) {
      setState(() => _loading = false);
      return;
    }
    try {
      final report  = await AppShield.instance.generateUsageReport();
      final metrics = await AppShield.instance.getAnalyticsMetrics(limit: 20);
      if (mounted) {
        setState(() {
          _report        = report;
          _recentMetrics = metrics;
          _loading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (context, shield, _) {
        if (_loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Top metrics row ──────────────────────────────────────────
              SectionTitle('Usage Summary',
                  icon: Icons.bar_chart_outlined),
              _UsageSummaryRow(report: _report),
              const SizedBox(height: 20),

              // ── AnalyticsDashboardWidget ──────────────────────────────────
              if (_report != null) ...[
                SectionTitle('Analytics Dashboard',
                    icon: Icons.dashboard_outlined),
                AnalyticsDashboardWidget(report: _report!),
                const SizedBox(height: 20),
              ],

              // ── Recent activity ────────────────────────────────────────
              SectionTitle('Recent Events',
                  icon: Icons.history_outlined),
              _recentMetrics.isEmpty
                  ? _EmptyState(
                      icon:    Icons.bar_chart_outlined,
                      message: 'No analytics events recorded yet.',
                    )
                  : _RecentMetricsList(metrics: _recentMetrics),
              const SizedBox(height: 20),

              // ── Clear analytics button ─────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon:    const Icon(Icons.delete_outline, size: 16),
                  label:   const Text('Clear Analytics Data'),
                  style:   OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: _confirmClear,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Clear Analytics'),
        content: const Text(
            'This will permanently delete all locally stored analytics data.'),
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
              await AppShield.instance.clearAnalytics();
              if (mounted) _refresh();
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Usage summary row ─────────────────────────────────────────────────────

class _UsageSummaryRow extends StatelessWidget {
  const _UsageSummaryRow({required this.report});
  final LicenseUsageReport? report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing:    12,
      runSpacing: 12,
      children: [
        _MetricTile(
          label: 'Sessions',
          value: '${report?.sessionCount ?? 0}',
          icon:  Icons.login_outlined,
          color: AppShieldColors.primary,
        ),
        _MetricTile(
          label: 'Activations',
          value: '${report?.activations ?? 0}',
          icon:  Icons.check_circle_outline,
          color: AppShieldColors.active,
        ),
        _MetricTile(
          label: 'Validations',
          value: '${report?.validations ?? 0}',
          icon:  Icons.verified_outlined,
          color: AppShieldColors.info,
        ),
        _MetricTile(
          label: 'Tamper Attempts',
          value: '${report?.tamperAttempts ?? 0}',
          icon:  Icons.security_outlined,
          color: report != null && report!.tamperAttempts > 0
              ? Colors.red
              : AppShieldColors.active,
        ),
        _MetricTile(
          label: 'Deactivations',
          value: '${report?.deactivations ?? 0}',
          icon:  Icons.cancel_outlined,
          color: AppShieldColors.expired,
        ),
        _MetricTile(
          label: 'Features Used',
          value: '${report?.featureUsage.length ?? 0}',
          icon:  Icons.extension_outlined,
          color: AppShieldColors.accent,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
    return SizedBox(
      width: 150,
      child: MetricCard(
        label: label,
        value: value,
        icon:  icon,
        color: color,
      ),
    );
  }
}

// ── Recent metrics list ───────────────────────────────────────────────────

class _RecentMetricsList extends StatelessWidget {
  const _RecentMetricsList({required this.metrics});
  final List<LicenseMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        itemCount:  metrics.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = metrics[i];
          return ListTile(
            dense: true,
            leading: Icon(
              _eventIcon(m.event),
              color: _eventColor(m.event),
              size:  20,
            ),
            title: Text(
              m.event.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _formatTimestamp(m.timestamp),
              style: const TextStyle(fontSize: 10),
            ),
            trailing: m.plan != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:        AppShieldColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(m.plan!,
                        style: const TextStyle(fontSize: 10)),
                  )
                : null,
          );
        },
      ),
    );
  }

  IconData _eventIcon(String event) {
    if (event.contains('activation'))  return Icons.check_circle_outline;
    if (event.contains('validation'))  return Icons.verified_outlined;
    if (event.contains('deactivation')) return Icons.cancel_outlined;
    if (event.contains('tamper'))      return Icons.security;
    if (event.contains('session'))     return Icons.login_outlined;
    if (event.contains('feature'))     return Icons.extension_outlined;
    if (event.contains('trial'))       return Icons.star_outline;
    return Icons.event_note_outlined;
  }

  Color _eventColor(String event) {
    if (event.contains('activation'))  return AppShieldColors.active;
    if (event.contains('validation'))  return AppShieldColors.info;
    if (event.contains('deactivation')) return AppShieldColors.expired;
    if (event.contains('tamper'))      return Colors.red;
    if (event.contains('session'))     return AppShieldColors.primary;
    return Colors.grey;
  }

  String _formatTimestamp(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    return AppShieldHelpers.formatDate(dt);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
