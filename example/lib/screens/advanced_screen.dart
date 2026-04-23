// example/lib/screens/advanced_screen.dart
//
// Advanced screen – multi-tenant, seat pooling, cache inspector,
// webhook events, grace period policy, and health snapshot.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/info_card.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key});

  @override
  State<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _events = <_WebhookEventEntry>[];
  StreamSubscription<AppShieldEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    if (AppShield.isInitialized) {
      _eventSub = AppShield.instance.eventStream.listen((e) {
        if (mounted) {
          setState(() {
            _events.insert(0,
                _WebhookEventEntry(event: e, receivedAt: DateTime.now()));
            if (_events.length > 50) _events.removeLast();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ──────────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Multi-Tenant'),
            Tab(text: 'Seat Pooling'),
            Tab(text: 'Cache & Health'),
            Tab(text: 'Webhooks'),
          ],
        ),
        const Divider(height: 1),

        // ── Tab views ────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _MultiTenantTab(),
              _SeatPoolingTab(),
              _CacheHealthTab(),
              _WebhookTab(events: _events),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MULTI-TENANT TAB
// ─────────────────────────────────────────────────────────────────────────────

class _MultiTenantTab extends StatefulWidget {
  @override
  State<_MultiTenantTab> createState() => _MultiTenantTabState();
}

class _MultiTenantTabState extends State<_MultiTenantTab> {
  final _mgr = MultiTenantManager.instance;

  void _switchTenant(TenantContext t) {
    _mgr.switchTenant(t.tenantId);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to ${t.tenantName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenants = _mgr.all;
    final active  = _mgr.current;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionTitle('Registered Tenants', icon: Icons.domain_outlined),
        if (tenants.isEmpty)
          const _EmptyCard(message: 'No tenants registered.')
        else
          ...tenants.map((t) => _TenantCard(
                tenant:   t,
                isActive: active?.tenantId == t.tenantId,
                onSwitch: () => _switchTenant(t),
              )),
        const SizedBox(height: 20),
        if (active != null) ...[
          SectionTitle('Active Tenant', icon: Icons.business_outlined),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('Tenant ID',   active.tenantId),
                _Row('Name',        active.tenantName),
                _Row('App ID',      active.config.appId),
                _Row('Has License', active.hasValidLicense ? 'Yes' : 'No'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.isActive,
    required this.onSwitch,
  });

  final TenantContext tenant;
  final bool          isActive;
  final VoidCallback  onSwitch;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppShieldColors.primary : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InfoCard(
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.domain, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant.tenantName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(tenant.tenantId,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (isActive)
              const Chip(
                label: Text('Active', style: TextStyle(fontSize: 11)),
                backgroundColor: AppShieldColors.active,
                labelStyle: TextStyle(color: Colors.white),
              )
            else
              OutlinedButton(
                onPressed: onSwitch,
                child: const Text('Switch'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEAT POOLING TAB
// ─────────────────────────────────────────────────────────────────────────────

class _SeatPoolingTab extends StatefulWidget {
  @override
  State<_SeatPoolingTab> createState() => _SeatPoolingTabState();
}

class _SeatPoolingTabState extends State<_SeatPoolingTab> {
  late final LicensePoolManager _pool;

  @override
  void initState() {
    super.initState();
    // Create a demo pool; in production this would be a singleton injected
    // from the configuration layer.
    final shield    = AppShield.isInitialized ? AppShield.instance : null;
    final license   = shield?.currentLicense;
    final totalSeats = shield?.config.totalSeats ?? 25;

    if (license != null) {
      _pool = LicensePoolManager(
        license:    license,
        totalSeats: totalSeats,
      );
    } else {
      // Use a placeholder license for the demo UI when not activated
      _pool = LicensePoolManager(
        license: License(
          key:         'DEMO-DEMO-DEMO-DEMO',
          type:        LicenseType.enterprise,
          status:      LicenseStatus.active,
          deviceId:    'demo',
          appId:       'demo',
          plan:        'enterprise',
          activatedAt: DateTime.now(),
          expiresAt:   DateTime.now().add(const Duration(days: 365)),
          features:    {},
          limits:      {},
          signature:   '',
        ),
        totalSeats: totalSeats,
      );
    }
  }

  void _claimSeat() {
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final seat = _pool.claimSeat(userId: userId, userName: 'Demo User');
      if (seat == null) throw Exception('No seats available');
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat claimed for $userId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not claim seat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = _pool.activeSeats;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionTitle('Seat Pool', icon: Icons.event_seat_outlined),
        SeatUsageWidget(pool: _pool),
        const SizedBox(height: 20),

        // Claim seat button
        Row(
          children: [
            FilledButton.icon(
              icon:  const Icon(Icons.add, size: 16),
              label: const Text('Claim New Seat'),
              onPressed: _pool.availableSeats > 0 ? _claimSeat : null,
            ),
            const SizedBox(width: 12),
            Text('${_pool.availableSeats} seats available',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 20),

        // Seats list
        SectionTitle('Active Seats', icon: Icons.people_outlined),
        seats.isEmpty
            ? const _EmptyCard(message: 'No seats claimed yet.')
            : InfoCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics:    const NeverScrollableScrollPhysics(),
                  itemCount:  seats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final seat = seats[i];
                    return ListTile(
                      leading: const Icon(Icons.person_outline),
                      title:   Text(seat.userName  ?? seat.userId),
                      subtitle: Text(seat.seatId,
                          style: const TextStyle(fontSize: 10)),
                      trailing: IconButton(
                        icon:    const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        tooltip: 'Release seat',
                        onPressed: () {
                          _pool.releaseSeat(seatId: seat.seatId);
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CACHE & HEALTH TAB
// ─────────────────────────────────────────────────────────────────────────────

class _CacheHealthTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (_, shield, __) {
        final snapshot = shield.healthSnapshot;
        final cached   = AppShield.isInitialized
            ? AppShield.instance.cachedLicense
            : null;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── License cache ──────────────────────────────────────────
            SectionTitle('License Cache', icon: Icons.cached_outlined),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row('Cached License',
                      cached != null ? 'Yes' : 'No'),
                  if (cached != null) ...[
                    _Row('Plan',   cached.plan.toUpperCase()),
                    _Row('Status', cached.status.name),
                    _Row('Expires',
                        AppShieldHelpers.formatDate(cached.expiresAt)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon:  const Icon(Icons.clear, size: 14),
                        label: const Text('Invalidate Cache'),
                        onPressed: () {
                          if (AppShield.isInitialized) {
                            AppShield.instance.invalidateLicenseCache();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Cache invalidated.')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Health snapshot ────────────────────────────────────────
            SectionTitle('Health Snapshot', icon: Icons.monitor_heart_outlined),
            snapshot != null
                ? _HealthSnapshotCard(snapshot: snapshot)
                : const _EmptyCard(
                    message: 'Health monitoring not running.'),
          ],
        );
      },
    );
  }
}

class _HealthSnapshotCard extends StatelessWidget {
  const _HealthSnapshotCard({required this.snapshot});
  final LicenseHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final statusColor = snapshot.isCritical
        ? Colors.red
        : snapshot.status == LicenseHealthStatus.degraded
            ? Colors.orange
            : AppShieldColors.active;

    return Column(
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    snapshot.status.name.toUpperCase(),
                    style: TextStyle(
                      color:      statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Captured: ${AppShieldHelpers.formatDate(snapshot.capturedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Row('Days Remaining', '${snapshot.daysRemaining ?? "—"}'),
              _Row('Online', '${snapshot.isOnline ?? "Unknown"}'),
              _Row('Alerts', '${snapshot.alerts.length}'),
            ],
          ),
        ),
        if (snapshot.hasAlerts) ...[
          const SizedBox(height: 12),
          LicenseHealthCard(
            snapshot: snapshot,
            onResolve: (_) {},
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEBHOOK EVENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _WebhookTab extends StatelessWidget {
  const _WebhookTab({required this.events});
  final List<_WebhookEventEntry> events;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            SectionTitle('Webhook Events', icon: Icons.webhook_outlined),
            const Spacer(),
            Text('${events.length} events',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Live events dispatched through WebhookService.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _dispatchControls(context),
        const SizedBox(height: 16),
        events.isEmpty
            ? const _EmptyCard(message: 'No events received yet.')
            : InfoCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics:    const NeverScrollableScrollPhysics(),
                  itemCount:  events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = events[i];
                    return ListTile(
                      dense:   true,
                      leading: Icon(
                        _eventIcon(entry.event.type),
                        size:  20,
                        color: _eventColor(entry.event.type),
                      ),
                      title: Text(
                        entry.event.type.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _formatTime(entry.receivedAt),
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: entry.event.message != null
                          ? Text(
                              entry.event.message!,
                              style: const TextStyle(fontSize: 10,
                                  color: Colors.grey),
                            )
                          : null,
                    );
                  },
                ),
              ),
      ],
    );
  }

  Widget _dispatchControls(BuildContext context) {
    return Wrap(
      spacing:    8,
      runSpacing: 8,
      children: [
        _DispatchButton(
          label: 'Dispatch Activated',
          color: AppShieldColors.active,
          onPressed: () {
            final license = AppShield.isInitialized
                ? AppShield.instance.currentLicense
                : null;
            if (license != null) {
              WebhookService.instance.dispatchActivated(license);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Dispatched: licenseActivated')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('No active license to dispatch.')),
              );
            }
          },
        ),
        _DispatchButton(
          label: 'Dispatch Validated',
          color: AppShieldColors.info,
          onPressed: () {
            final license = AppShield.isInitialized
                ? AppShield.instance.currentLicense
                : null;
            if (license != null) {
              WebhookService.instance.dispatchValidationSuccess(license);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Dispatched: validationSuccess')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No active license.')),
              );
            }
          },
        ),
        _DispatchButton(
          label: 'Dispatch Grace Period',
          color: AppShieldColors.gracePeriod,
          onPressed: () {
            WebhookService.instance.dispatchGracePeriodStarted(
              AppShield.isInitialized
                  ? AppShield.instance.currentLicense
                  : null,
              7,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Dispatched: gracePeriodStarted')),
            );
          },
        ),
      ],
    );
  }

  IconData _eventIcon(AppShieldEventType t) {
    switch (t) {
      case AppShieldEventType.licenseActivated:   return Icons.check_circle;
      case AppShieldEventType.licenseExpired:     return Icons.cancel;
      case AppShieldEventType.tamperDetected:     return Icons.security;
      case AppShieldEventType.gracePeriodStarted: return Icons.timer;
      case AppShieldEventType.validationSuccess:  return Icons.verified;
      case AppShieldEventType.validationFailed:   return Icons.error;
      case AppShieldEventType.trialStarted:       return Icons.star;
      default:                                    return Icons.notifications;
    }
  }

  Color _eventColor(AppShieldEventType t) {
    switch (t) {
      case AppShieldEventType.licenseActivated:   return AppShieldColors.active;
      case AppShieldEventType.licenseExpired:     return AppShieldColors.expired;
      case AppShieldEventType.tamperDetected:     return Colors.red;
      case AppShieldEventType.gracePeriodStarted: return AppShieldColors.gracePeriod;
      case AppShieldEventType.validationSuccess:  return AppShieldColors.info;
      case AppShieldEventType.validationFailed:   return Colors.orange;
      case AppShieldEventType.trialStarted:       return AppShieldColors.trial;
      default:                                    return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, "0")}:'
        '${dt.minute.toString().padLeft(2, "0")}:'
        '${dt.second.toString().padLeft(2, "0")}';
  }
}

class _DispatchButton extends StatelessWidget {
  const _DispatchButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });
  final String       label;
  final Color        color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(message,
              style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}

class _WebhookEventEntry {
  const _WebhookEventEntry({
    required this.event,
    required this.receivedAt,
  });
  final AppShieldEvent event;
  final DateTime       receivedAt;
}
