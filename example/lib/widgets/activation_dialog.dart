// example/lib/widgets/activation_dialog.dart
//
// Activation dialog for entering / submitting a license key.

import 'package:flutter/material.dart';
import 'package:app_shield/app_shield.dart';

class ActivationDialog extends StatefulWidget {
  const ActivationDialog({super.key, required this.shield});
  final AppShieldProvider shield;

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final _keyCtrl  = TextEditingController();
  String? _error;
  bool    _loading = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter a license key.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await widget.shield.activate(key);
    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ License activated successfully!')),
      );
    } else {
      setState(() {
        _loading = false;
        _error   = result.errorMessage ?? widget.shield.lastError ?? 'Activation failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.vpn_key_outlined),
          const SizedBox(width: 8),
          const Text('Activate License'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your license key to activate AppShield.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LicenseInputField(
              controller: _keyCtrl,
              theme: AppShield.isInitialized
                  ? AppShield.instance.config.resolvedTheme
                  : AppShieldTheme.light(),
              onSubmitted: (_) => _activate(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Format: XXXX-XXXX-XXXX-XXXX',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _activate,
          icon: _loading
              ? const SizedBox(
                  width:  14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 16),
          label: Text(_loading ? 'Activating…' : 'Activate'),
        ),
      ],
    );
  }
}
