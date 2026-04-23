// example/lib/screens/features_screen.dart
//
// Features screen – demonstrates FeatureGuard, feature list,
// and feature-gating patterns.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

import '../widgets/info_card.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  // All features we want to display / gate
  static const _features = [
    _FeatureDef(
      key:     AppShieldConstants.featureAdvancedReports,
      label:   'Advanced Reports',
      icon:    Icons.analytics_outlined,
      color:   Color(0xFF3B82F6),
      description: 'Generate detailed PDF reports with charts and export.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureMultiUser,
      label:   'Multi-User Access',
      icon:    Icons.group_outlined,
      color:   Color(0xFF10B981),
      description: 'Allow multiple users to collaborate within one license.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureApiAccess,
      label:   'API Access',
      icon:    Icons.code_outlined,
      color:   Color(0xFF6366F1),
      description: 'Programmatic API access for integrations.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureCloudBackup,
      label:   'Cloud Backup',
      icon:    Icons.cloud_upload_outlined,
      color:   Color(0xFF0EA5E9),
      description: 'Automatic encrypted cloud backup of all data.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureExportPdf,
      label:   'PDF Export',
      icon:    Icons.picture_as_pdf_outlined,
      color:   Color(0xFFEF4444),
      description: 'Export any view to PDF with custom branding.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureWhiteLabel,
      label:   'White Label',
      icon:    Icons.business_outlined,
      color:   Color(0xFFF59E0B),
      description: 'Remove AppShield branding and use your own.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureMultiTenant,
      label:   'Multi-Tenant',
      icon:    Icons.domain_outlined,
      color:   Color(0xFF8B5CF6),
      description: 'Support multiple tenants within one deployment.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureSeatPooling,
      label:   'Seat Pooling',
      icon:    Icons.event_seat_outlined,
      color:   Color(0xFF14B8A6),
      description: 'Dynamic seat assignment from a shared pool.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featureAdvancedAnalytics,
      label:   'Advanced Analytics',
      icon:    Icons.bar_chart_outlined,
      color:   Color(0xFFEC4899),
      description: 'Deep usage analytics, heatmaps, and trends.',
    ),
    _FeatureDef(
      key:     AppShieldConstants.featurePrioritySupport,
      label:   'Priority Support',
      icon:    Icons.support_agent_outlined,
      color:   Color(0xFF22C55E),
      description: '24/7 priority support with SLA guarantees.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShieldProvider>(
      builder: (context, shield, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Summary row ──────────────────────────────────────────────
            _FeatureSummaryRow(shield: shield),
            const SizedBox(height: 20),

            // ── Feature grid ─────────────────────────────────────────────
            SectionTitle('Feature Gates', icon: Icons.extension_outlined),
            LayoutBuilder(
              builder: (_, constraints) {
                final cols = constraints.maxWidth < 600 ? 1
                    : constraints.maxWidth < 900 ? 2
                    : 3;
                return GridView.builder(
                  shrinkWrap:  true,
                  physics:     const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing:  12,
                    childAspectRatio: 2.0,
                  ),
                  itemCount: _features.length,
                  itemBuilder: (_, i) => _FeatureCard(
                    def:     _features[i],
                    enabled: shield.hasFeature(_features[i].key),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── FeatureGuard demo ─────────────────────────────────────────
            SectionTitle('FeatureGuard Demo', icon: Icons.lock_outline),
            _FeatureGuardDemo(),
          ],
        );
      },
    );
  }
}

// ── Feature summary row ───────────────────────────────────────────────────

class _FeatureSummaryRow extends StatelessWidget {
  const _FeatureSummaryRow({required this.shield});
  final AppShieldProvider shield;

  @override
  Widget build(BuildContext context) {
    final license = shield.license;
    final total   = license?.features.length ?? 0;
    final enabled = license?.features.values.where((v) => v).length ?? 0;

    return Row(
      children: [
        Expanded(
          child: MetricCard(
            label:    'Enabled Features',
            value:    '$enabled',
            icon:     Icons.check_circle_outline,
            color:    AppShieldColors.active,
            subtitle: 'of $total available',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            label:    'Plan',
            value:    (shield.currentPlan ?? 'Unknown').toUpperCase(),
            icon:     Icons.workspace_premium_outlined,
            color:    AppShieldColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetricCard(
            label:    'License Type',
            value:    shield.license?.type.name ?? '—',
            icon:     Icons.badge_outlined,
            color:    AppShieldColors.accent,
          ),
        ),
      ],
    );
  }

}

// ── Feature card ──────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.def, required this.enabled});
  final _FeatureDef def;
  final bool        enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? def.color : Colors.grey;

    return InfoCard(
      child: Row(
        children: [
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        color.withAlpha(enabled ? 30 : 15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(def.icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(def.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : Colors.grey,
                    )),
                Text(def.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11,
                        color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            enabled ? Icons.check_circle : Icons.lock_outline,
            color: enabled ? AppShieldColors.active : Colors.grey,
            size:  20,
          ),
        ],
      ),
    );
  }
}

// ── FeatureGuard demo ─────────────────────────────────────────────────────

class _FeatureGuardDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The widgets below demonstrate FeatureGuard – they show their '
          'content only when the associated feature is enabled in the license.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Advanced Reports guard
        FeatureGuard(
          feature:  AppShieldConstants.featureAdvancedReports,
          fallback: _GuardFallback(
            feature: 'Advanced Reports',
            color: const Color(0xFF3B82F6),
          ),
          child: _GuardContent(
            label: '📊 Advanced Reports',
            description: 'You have access to advanced reporting tools!',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 12),

        // API Access guard
        FeatureGuard(
          feature:  AppShieldConstants.featureApiAccess,
          fallback: _GuardFallback(
            feature: 'API Access',
            color: const Color(0xFF6366F1),
          ),
          child: _GuardContent(
            label: '🔌 API Access',
            description: 'Full programmatic API access is enabled!',
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 12),

        // White Label guard
        FeatureGuard(
          feature:  AppShieldConstants.featureWhiteLabel,
          fallback: _GuardFallback(
            feature: 'White Label',
            color: const Color(0xFFF59E0B),
          ),
          child: _GuardContent(
            label: '🏷 White Label',
            description: 'White label customisation is enabled!',
            color: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }
}

class _GuardContent extends StatelessWidget {
  const _GuardContent({
    required this.label,
    required this.description,
    required this.color,
  });
  final String label;
  final String description;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color)),
              Text(description,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuardFallback extends StatelessWidget {
  const _GuardFallback({required this.feature, required this.color});
  final String feature;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.grey.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.grey),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$feature (locked)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const Text('Upgrade your plan to unlock this feature.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
            icon:  const Icon(Icons.upgrade, size: 14),
            label: const Text('Upgrade'),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper classes ────────────────────────────────────────────────────────

class _FeatureDef {
  const _FeatureDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String   key;
  final String   label;
  final IconData icon;
  final Color    color;
  final String   description;
}
