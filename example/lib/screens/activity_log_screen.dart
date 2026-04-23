// example/lib/screens/activity_log_screen.dart
//
// Activity log screen – displays all recorded license activity events.

import 'package:flutter/material.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/info_card.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityLogEntry> _log      = [];
  bool                   _loading  = true;
  String?                _filter;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _loading = true);
    try {
      if (AppShield.isInitialized) {
        final entries = await AppShield.instance.getActivityLog();
        if (mounted) {
          setState(() {
            _log     = entries.reversed.toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ActivityLogEntry> get _filteredLog {
    if (_filter == null || _filter!.isEmpty) return _log;
    return _log
        .where((e) =>
            e.action.toLowerCase().contains(_filter!.toLowerCase()) ||
            (e.details ?? '').toLowerCase().contains(_filter!.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText:    'Filter events…',
                    prefixIcon:  const Icon(Icons.search, size: 18),
                    isDense:     true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 12),
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon:    const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadLog,
              ),
            ],
          ),
        ),

        // ── Stats row ───────────────────────────────────────────────────
        if (_log.isNotEmpty) _StatsRow(log: _log),

        // ── Log list ─────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLog.isEmpty
                  ? _EmptyState(
                      icon: Icons.history,
                      message: _filter != null && _filter!.isNotEmpty
                          ? 'No events match "$_filter".'
                          : 'No activity recorded yet.',
                    )
                  : ListView.separated(
                      padding:    const EdgeInsets.symmetric(horizontal: 16),
                      itemCount:  _filteredLog.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _LogEntryCard(entry: _filteredLog[i]),
                    ),
        ),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.log});
  final List<ActivityLogEntry> log;

  @override
  Widget build(BuildContext context) {
    final activations  = log.where((e) => e.action == AppShieldConstants.actionActivate).length;
    final validations  = log.where((e) => e.action == AppShieldConstants.actionValidate).length;
    final tamperEvents = log.where((e) => e.action.contains('tamper')).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _StatChip(label: 'Total',       value: log.length.toString(),  color: AppShieldColors.primary),
          const SizedBox(width: 8),
          _StatChip(label: 'Activations', value: activations.toString(), color: AppShieldColors.active),
          const SizedBox(width: 8),
          _StatChip(label: 'Validations', value: validations.toString(), color: AppShieldColors.info),
          const SizedBox(width: 8),
          _StatChip(label: 'Tamper',      value: tamperEvents.toString(),
              color: tamperEvents > 0 ? Colors.red : Colors.grey),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      color,
        ),
      ),
    );
  }
}

// ── Log entry card ────────────────────────────────────────────────────────

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.entry});
  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _actionColor(entry.action);

    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              color:        color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_actionIcon(entry.action), color: color, size: 18),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _actionLabel(entry.action),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(entry.timestamp),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (entry.details != null && entry.details!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (entry.licenseKey != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    AppShieldHelpers.obfuscateLicenseKey(entry.licenseKey!),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize:   11,
                      color:      Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    if (action == AppShieldConstants.actionActivate)   return AppShieldColors.active;
    if (action == AppShieldConstants.actionDeactivate) return AppShieldColors.expired;
    if (action == AppShieldConstants.actionValidate)   return AppShieldColors.info;
    if (action == AppShieldConstants.actionTrialStart) return AppShieldColors.trial;
    if (action.contains('tamper'))                     return Colors.red;
    if (action.contains('grace'))                      return AppShieldColors.gracePeriod;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action == AppShieldConstants.actionActivate)   return Icons.check_circle_outline;
    if (action == AppShieldConstants.actionDeactivate) return Icons.cancel_outlined;
    if (action == AppShieldConstants.actionValidate)   return Icons.verified_outlined;
    if (action == AppShieldConstants.actionTrialStart) return Icons.star_outline;
    if (action.contains('tamper'))                     return Icons.security_outlined;
    if (action.contains('grace'))                      return Icons.timer_outlined;
    return Icons.event_note_outlined;
  }

  String _actionLabel(String action) =>
      action.replaceAll('_', ' ').split(' ')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  String _formatTime(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withAlpha(100)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
