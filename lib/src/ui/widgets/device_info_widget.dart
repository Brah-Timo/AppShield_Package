// lib/src/ui/widgets/device_info_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/device_fingerprint.dart';
import '../../models/device_model.dart';
import '../themes/app_shield_theme.dart';

/// Displays the current device's fingerprint / ID.
class DeviceInfoWidget extends StatefulWidget {
  const DeviceInfoWidget({super.key, required this.theme});
  final AppShieldTheme theme;

  @override
  State<DeviceInfoWidget> createState() => _DeviceInfoWidgetState();
}

class _DeviceInfoWidgetState extends State<DeviceInfoWidget> {
  DeviceInfo? _info;
  bool        _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await DeviceFingerprintService.instance.getDeviceInfo();
      if (mounted) setState(() { _info = info; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyId() {
    if (_info == null) return;
    Clipboard.setData(ClipboardData(text: _info!.fingerprint));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Device ID copied'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        widget.theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: widget.theme.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.computer_outlined,
                size: 18, color: widget.theme.subtitleColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device ID',
                      style: TextStyle(
                          fontSize: 11,
                          color: widget.theme.subtitleColor)),
                  _loading
                      ? const SizedBox(
                          height: 14,
                          child: LinearProgressIndicator(minHeight: 2))
                      : Text(
                          _info?.fingerprint ?? 'Unknown',
                          style: TextStyle(
                              fontFamily:   'monospace',
                              fontWeight:   FontWeight.bold,
                              fontSize:     15,
                              color:        widget.theme.textColor,
                              letterSpacing: 1),
                        ),
                ],
              ),
            ),
            IconButton(
              icon:    const Icon(Icons.copy_outlined, size: 18),
              tooltip: 'Copy Device ID',
              onPressed: _copyId,
            ),
          ],
        ),
      );
}
