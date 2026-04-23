// lib/src/ui/widgets/license_input.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/helpers.dart';
import '../themes/app_shield_theme.dart';

/// Text field for entering a license key.
/// Automatically formats input as XXXX-XXXX-XXXX-XXXX.
class LicenseInputField extends StatefulWidget {
  const LicenseInputField({
    super.key,
    required this.controller,
    required this.theme,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final AppShieldTheme         theme;
  final ValueChanged<String>?  onSubmitted;
  final bool                   enabled;

  @override
  State<LicenseInputField> createState() => _LicenseInputFieldState();
}

class _LicenseInputFieldState extends State<LicenseInputField> {
  bool _isValid    = false;
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    setState(() {
      _hasContent = text.isNotEmpty;
      _isValid    = AppShieldHelpers.isValidLicenseKeyFormat(text);
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final formatted = AppShieldHelpers.formatLicenseKey(data!.text!);
      widget.controller.text = formatted;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _hasContent
        ? (_isValid ? Colors.green : Colors.red)
        : widget.theme.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'License Key',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.theme.subtitleColor),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:    widget.controller,
          enabled:       widget.enabled,
          maxLength:     24, // XXXX-XXXX-XXXX-XXXX = 19 chars
          textCapitalization: TextCapitalization.characters,
          keyboardType:  TextInputType.text,
          inputFormatters: [
            _LicenseKeyFormatter(),
          ],
          style: TextStyle(
              fontFamily:  'monospace',
              fontSize:    18,
              fontWeight:  FontWeight.bold,
              letterSpacing: 2,
              color: widget.theme.textColor),
          decoration: InputDecoration(
            hintText:       'XXXX-XXXX-XXXX-XXXX',
            hintStyle:      TextStyle(
                color: widget.theme.textColor.withAlpha(76),
                letterSpacing: 2,
                fontSize: 16),
            counterText:    '',
            filled:         true,
            fillColor:      widget.theme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   BorderSide(color: widget.theme.primaryColor, width: 2),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasContent && _isValid)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                if (_hasContent && !_isValid)
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                IconButton(
                  icon:    const Icon(Icons.content_paste_outlined, size: 20),
                  tooltip: 'Paste',
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your license key.';
            }
            if (!AppShieldHelpers.isValidLicenseKeyFormat(value)) {
              return 'Invalid license key format. Expected: XXXX-XXXX-XXXX-XXXX';
            }
            return null;
          },
          onFieldSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}

/// Auto-formats input as XXXX-XXXX-XXXX-XXXX
class _LicenseKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('-');
      buffer.write(raw[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
