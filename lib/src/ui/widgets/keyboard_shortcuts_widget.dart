// lib/src/ui/widgets/keyboard_shortcuts_widget.dart
//
// Keyboard shortcuts overlay widget for Windows/Linux desktop apps.
// Shows a help dialog listing all registered AppShield keyboard shortcuts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_shield_colors.dart';

/// A single keyboard shortcut definition.
class AppShieldShortcut {
  const AppShieldShortcut({
    required this.keys,
    required this.description,
    this.category = 'General',
  });

  /// Key combination, e.g. ['Ctrl', 'Shift', 'A']
  final List<String> keys;

  /// Human-readable description of what the shortcut does.
  final String description;

  /// Category grouping (e.g. 'License', 'Navigation').
  final String category;
}

/// Widget that listens for [LogicalKeyboardKey.f1] to open the shortcuts
/// help dialog, and wraps [child] so the focus scope captures key events.
///
/// ```dart
/// AppShieldKeyboardShortcuts(
///   shortcuts: [
///     AppShieldShortcut(
///       keys: ['Ctrl', 'Shift', 'A'],
///       description: 'Open Activation dialog',
///       category: 'License',
///     ),
///   ],
///   onShortcutTriggered: (shortcut) { /* handle */ },
///   child: MyScreen(),
/// )
/// ```
class AppShieldKeyboardShortcuts extends StatefulWidget {
  const AppShieldKeyboardShortcuts({
    super.key,
    required this.child,
    this.shortcuts = const [],
    this.onShortcutTriggered,
    this.showHelpOnF1 = true,
  });

  final Widget                                child;
  final List<AppShieldShortcut>               shortcuts;
  final ValueChanged<AppShieldShortcut>?      onShortcutTriggered;
  final bool                                  showHelpOnF1;

  @override
  State<AppShieldKeyboardShortcuts> createState() =>
      _AppShieldKeyboardShortcutsState();
}

class _AppShieldKeyboardShortcutsState
    extends State<AppShieldKeyboardShortcuts> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (widget.showHelpOnF1 &&
          event.logicalKey == LogicalKeyboardKey.f1) {
        _showHelp(context);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ShortcutsDialog(shortcuts: widget.shortcuts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode:   _focusNode,
      autofocus:   true,
      onKeyEvent:  _handleKeyEvent,
      child:       widget.child,
    );
  }
}

// ── Help dialog ──────────────────────────────────────────────────────────

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog({required this.shortcuts});
  final List<AppShieldShortcut> shortcuts;

  @override
  Widget build(BuildContext context) {
    // Group by category
    final grouped = <String, List<AppShieldShortcut>>{};
    for (final s in shortcuts) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard_outlined, size: 22),
          SizedBox(width: 8),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width:  480,
        height: 400,
        child:  shortcuts.isEmpty
            ? const Center(
                child: Text('No shortcuts registered.',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView(
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 12, bottom: 6),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...entry.value.map((s) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Wrap(
                                  spacing: 4,
                                  children: s.keys
                                      .map((k) => _KeyChip(label: k))
                                      .toList(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    s.description,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(),
                    ],
                  );
                }).toList(),
              ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'Press F1 to show this help',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        AppShieldColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(
          color: AppShieldColors.primary.withAlpha(80),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Courier New',
          fontSize:   11,
          fontWeight: FontWeight.bold,
          color:      AppShieldColors.primary,
        ),
      ),
    );
  }
}

/// Compact inline shortcut hint displayed next to a button or action.
///
/// ```dart
/// Row(children: [
///   const Text('Activate License'),
///   const Spacer(),
///   const ShortcutHint(keys: ['Ctrl', 'Shift', 'A']),
/// ])
/// ```
class ShortcutHint extends StatelessWidget {
  const ShortcutHint({
    super.key,
    required this.keys,
  });

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: keys.asMap().entries.map((e) {
        final isLast = e.key == keys.length - 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _KeyChip(label: e.value),
            if (!isLast) const Text(' + ',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        );
      }).toList(),
    );
  }
}
