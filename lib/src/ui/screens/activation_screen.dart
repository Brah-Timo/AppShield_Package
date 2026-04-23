// lib/src/ui/screens/activation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app_shield.dart';
import '../../models/license_model.dart';
import '../themes/app_shield_colors.dart';
import '../widgets/license_input.dart';
import '../widgets/status_card.dart';
import '../widgets/device_info_widget.dart';

/// Main activation screen shown when no valid license is found.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({
    super.key,
    this.onActivated,
  });

  /// Callback triggered after a successful activation.
  final VoidCallback? onActivated;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController  = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  bool   _isActivating    = false;
  bool   _isValidating    = false;
  bool   _isStartingTrial = false;
  String _errorMessage    = '';
  String _successMessage  = '';

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isActivating  = true;
      _errorMessage  = '';
      _successMessage = '';
    });

    final result = await AppShield.instance.activate(_keyController.text.trim());
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _successMessage = 'License activated successfully!';
        _isActivating   = false;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onActivated?.call();
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Activation failed.';
        _isActivating  = false;
      });
    }
  }

  Future<void> _validateOffline() async {
    setState(() { _isValidating = true; _errorMessage = ''; });
    try {
      final status = await AppShield.instance.checkLicense();
      if (!mounted) return;
      if (status == LicenseStatus.active ||
          status == LicenseStatus.gracePeriod ||
          status == LicenseStatus.trial) {
        widget.onActivated?.call();
      } else {
        setState(() { _errorMessage = 'No valid offline license found.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _errorMessage = 'Offline validation failed.'; });
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _startTrial() async {
    setState(() { _isStartingTrial = true; _errorMessage = ''; });
    try {
      await AppShield.instance.startTrial();
      if (!mounted) return;
      setState(() {
        _successMessage = 'Trial started! Enjoy your free period.';
      });
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onActivated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isStartingTrial = false);
    }
  }

  void _openRestoreDialog() {
    showDialog(
      context: context,
      builder: (_) => _RestoreDialog(onRestored: widget.onActivated),
    );
  }

  void _openBuyPage() {
    final url = AppShield.instance.config.buyLicenseUrl;
    debugPrint('Open buy URL: $url'); // Replace with url_launcher
  }

  void _openSupportPage() {
    final url = AppShield.instance.config.supportUrl;
    debugPrint('Open support URL: $url');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme     = AppShield.instance.config.resolvedTheme;
    final brandName = theme.brandName;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ─────────────────────────────────────────────────
                _Header(
                  brandName:    brandName,
                  logoAsset:    theme.logoAsset,
                  primaryColor: theme.primaryColor,
                ),
                const SizedBox(height: 32),

                // ── Status card ────────────────────────────────────────────
                StatusCard(
                  status: LicenseStatus.notActivated,
                  theme:  theme,
                ),
                const SizedBox(height: 20),

                // ── Device info ────────────────────────────────────────────
                DeviceInfoWidget(theme: theme),
                const SizedBox(height: 20),

                // ── License input ──────────────────────────────────────────
                LicenseInputField(
                  controller:  _keyController,
                  theme:       theme,
                  onSubmitted: (_) => _activate(),
                ),
                const SizedBox(height: 12),

                // ── Messages ───────────────────────────────────────────────
                if (_errorMessage.isNotEmpty)
                  _MessageBanner(message: _errorMessage,   isError: true),
                if (_successMessage.isNotEmpty)
                  _MessageBanner(message: _successMessage, isError: false),

                const SizedBox(height: 16),

                // ── Primary action ─────────────────────────────────────────
                _PrimaryButton(
                  label:   'Activate Now',
                  icon:    Icons.verified_outlined,
                  color:   theme.primaryColor,
                  loading: _isActivating,
                  onTap:   _activate,
                ),
                const SizedBox(height: 10),

                // ── Secondary actions ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryButton(
                        label:   'Validate Offline',
                        icon:    Icons.offline_bolt_outlined,
                        loading: _isValidating,
                        onTap:   _validateOffline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SecondaryButton(
                        label:   'Restore',
                        icon:    Icons.restore_outlined,
                        loading: false,
                        onTap:   _openRestoreDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Trial ──────────────────────────────────────────────────
                if (AppShield.instance.config.enableTrial)
                  _SecondaryButton(
                    label:     'Start Free Trial '
                               '(${AppShield.instance.config.trialDays} days)',
                    icon:      Icons.card_giftcard_outlined,
                    loading:   _isStartingTrial,
                    onTap:     _startTrial,
                    fullWidth: true,
                  ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),

                // ── Footer links ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _FooterLink(
                      label: 'Buy License',
                      icon:  Icons.shopping_cart_outlined,
                      onTap: _openBuyPage,
                    ),
                    _FooterLink(
                      label: 'Support',
                      icon:  Icons.help_outline,
                      onTap: _openSupportPage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Sub-widgets ──────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.brandName,
    required this.primaryColor,
    this.logoAsset,
  });
  final String  brandName;
  final Color   primaryColor;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (logoAsset != null)
          Image.asset(logoAsset!, height: 64)
        else
          Icon(Icons.shield_outlined, size: 64, color: primaryColor),
        const SizedBox(height: 12),
        Text(
          brandName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight:  FontWeight.bold,
                color:       primaryColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Please activate your license to continue',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });
  final String     label;
  final IconData   icon;
  final Color      color;
  final bool       loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: loading ? null : onTap,
      );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
    this.fullWidth = false,
  });
  final String     label;
  final IconData   icon;
  final bool       loading;
  final VoidCallback onTap;
  final bool       fullWidth;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(fullWidth ? double.infinity : 0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label:     Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: loading ? null : onTap,
      );
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String     label;
  final IconData   icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        icon:      Icon(icon, size: 16),
        label:     Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onTap,
      );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});
  final String message;
  final bool   isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppShieldColors.expired : AppShieldColors.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withAlpha(25),
        border:       Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size:  18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Restore Dialog ───────────────────────────────

class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog({this.onRestored});
  final VoidCallback? onRestored;

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _keyCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool   _loading  = false;
  String _error    = '';

  @override
  void dispose() {
    _keyCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your license key.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    final result = await AppShield.instance.restore(
      licenseKey: key,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop();
      widget.onRestored?.call();
    } else {
      setState(() {
        _error   = result.errorMessage ?? 'Restore failed.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Restore License'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _keyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'License Key',
                  hintText:  'XXXX-XXXX-XXXX-XXXX',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText:  'you@example.com',
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _error,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _loading ? null : _restore,
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Restore'),
          ),
        ],
      );
}
