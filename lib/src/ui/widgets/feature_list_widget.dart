// lib/src/ui/widgets/feature_list_widget.dart

import 'package:flutter/material.dart';
import '../themes/app_shield_colors.dart';

/// Renders a list of feature flags (enabled/disabled) from a license.
class FeatureListWidget extends StatelessWidget {
  const FeatureListWidget({
    super.key,
    required this.features,
    this.showDisabled = true,
  });

  final Map<String, bool> features;
  final bool              showDisabled;

  @override
  Widget build(BuildContext context) {
    final entries = features.entries
        .where((e) => showDisabled || e.value)
        .toList()
      ..sort((a, b) {
        if (a.value && !b.value) return -1;
        if (!a.value && b.value) return 1;
        return a.key.compareTo(b.key);
      });

    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No features defined.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    return Column(
      children: entries
          .map((e) => _FeatureRow(
                featureKey: e.key,
                enabled:    e.value,
              ))
          .toList(),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.featureKey, required this.enabled});
  final String featureKey;
  final bool   enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
              size:  18,
              color: enabled ? AppShieldColors.active : AppShieldColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _prettify(featureKey),
                style: TextStyle(
                    fontSize:   13,
                    color:      enabled ? null : AppShieldColors.textMuted,
                    decoration: enabled ? null : TextDecoration.lineThrough),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:        (enabled ? AppShieldColors.active : AppShieldColors.textMuted)
                    .withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                enabled ? 'Enabled' : 'Locked',
                style: TextStyle(
                    fontSize:   10,
                    color:      enabled ? AppShieldColors.active : AppShieldColors.textMuted,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

  String _prettify(String key) =>
      key.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');
}
