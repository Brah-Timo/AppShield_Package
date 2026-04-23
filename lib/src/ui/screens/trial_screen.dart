// lib/src/ui/screens/trial_screen.dart

import 'package:flutter/material.dart';
import '../../../app_shield.dart';
import '../themes/app_shield_colors.dart';

/// Banner / screen shown during the trial period.
class TrialScreen extends StatelessWidget {
  const TrialScreen({super.key, this.onBuyTapped, this.onActivateTapped});
  final VoidCallback? onBuyTapped;
  final VoidCallback? onActivateTapped;

  @override
  Widget build(BuildContext context) {
    final daysLeft = AppShield.instance.trialDaysRemaining;
    final theme    = AppShield.instance.config.resolvedTheme;
    final urgent   = daysLeft <= 3;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppShieldColors.trial.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.science_outlined,
                      size: 48, color: AppShieldColors.trial),
                ),
              ),
              const SizedBox(height: 20),
              Text('Trial Mode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                urgent
                    ? 'Only $daysLeft day(s) left in your trial!'
                    : '$daysLeft day(s) remaining in your free trial.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: urgent
                        ? AppShieldColors.expired
                        : theme.subtitleColor),
              ),
              const SizedBox(height: 24),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: daysLeft / AppShield.instance.config.trialDays,
                  minHeight: 10,
                  backgroundColor: AppShieldColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      urgent ? AppShieldColors.expired : AppShieldColors.trial),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon:  const Icon(Icons.shopping_cart_outlined),
                label: const Text('Buy License Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: onBuyTapped,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon:  const Icon(Icons.vpn_key_outlined),
                label: const Text('Already have a license? Activate'),
                onPressed: onActivateTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact trial banner suitable for embedding inside any screen.
class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key, this.onUpgradeTapped});
  final VoidCallback? onUpgradeTapped;

  @override
  Widget build(BuildContext context) {
    final daysLeft = AppShield.instance.trialDaysRemaining;
    final urgent   = daysLeft <= 3;
    final color    = urgent ? AppShieldColors.expired : AppShieldColors.trial;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color:   color.withAlpha(30),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              urgent
                  ? 'Trial: $daysLeft day(s) left!'
                  : 'Trial mode — $daysLeft day(s) remaining',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: onUpgradeTapped,
            child: Text('Upgrade', style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
