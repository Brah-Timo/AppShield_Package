// lib/src/ui/widgets/license_notification_widget.dart
//
// In-app notification overlay for AppShield license events.
// Shows toast-style notifications when license events occur.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/webhook_service.dart';
import '../themes/app_shield_colors.dart';

/// A notification entry displayed in the overlay.
class _LicenseNotification {
  _LicenseNotification({
    required this.event,
    required this.id,
  });

  final AppShieldEvent event;
  final int            id;
  bool                 dismissed = false;
}

/// Listens to [WebhookService] events and shows toast-style notifications.
///
/// Wrap your top-level widget (e.g. inside [MaterialApp.builder]):
///
/// ```dart
/// MaterialApp(
///   builder: (ctx, child) => LicenseNotificationOverlay(child: child!),
///   ...
/// )
/// ```
class LicenseNotificationOverlay extends StatefulWidget {
  const LicenseNotificationOverlay({
    super.key,
    required this.child,
    this.maxVisible = 3,
    this.autoDismissDuration = const Duration(seconds: 5),
  });

  final Widget   child;
  final int      maxVisible;
  final Duration autoDismissDuration;

  @override
  State<LicenseNotificationOverlay> createState() =>
      _LicenseNotificationOverlayState();
}

class _LicenseNotificationOverlayState
    extends State<LicenseNotificationOverlay> {
  final _notifications = <_LicenseNotification>[];
  StreamSubscription<AppShieldEvent>? _sub;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _sub = WebhookService.instance.eventStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(AppShieldEvent event) {
    if (!mounted) return;
    // Only show certain event types
    if (!_shouldShow(event.type)) return;

    final note = _LicenseNotification(event: event, id: _nextId++);
    setState(() {
      _notifications.insert(0, note);
      // Keep max visible
      if (_notifications.length > widget.maxVisible) {
        _notifications.removeLast();
      }
    });

    // Auto-dismiss
    Future.delayed(widget.autoDismissDuration, () {
      _dismiss(note.id);
    });
  }

  bool _shouldShow(AppShieldEventType type) {
    switch (type) {
      case AppShieldEventType.licenseActivated:
      case AppShieldEventType.licenseExpired:
      case AppShieldEventType.tamperDetected:
      case AppShieldEventType.gracePeriodStarted:
      case AppShieldEventType.validationFailed:
        return true;
      default:
        return false;
    }
  }

  void _dismiss(int id) {
    if (!mounted) return;
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_notifications.isNotEmpty)
          Positioned(
            bottom: 24,
            right:  24,
            child:  Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _notifications.map((n) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _NotificationToast(
                      notification: n,
                      onDismiss:    () => _dismiss(n.id),
                    ),
                  )).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Toast widget ──────────────────────────────────────────────────────────

class _NotificationToast extends StatelessWidget {
  const _NotificationToast({
    required this.notification,
    required this.onDismiss,
  });

  final _LicenseNotification notification;
  final VoidCallback          onDismiss;

  @override
  Widget build(BuildContext context) {
    final event = notification.event;
    final color = _colorFor(event.type);

    return Material(
      elevation:    8,
      borderRadius: BorderRadius.circular(10),
      color:        Colors.transparent,
      child: Container(
        width:   320,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: color.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color:      color.withAlpha(40),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        color.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_iconFor(event.type), color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleFor(event.type),
                    style: TextStyle(
                      color:      color,
                      fontWeight: FontWeight.bold,
                      fontSize:   13,
                    ),
                  ),
                  if (event.message != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.message!,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(AppShieldEventType t) {
    switch (t) {
      case AppShieldEventType.licenseActivated:   return AppShieldColors.active;
      case AppShieldEventType.licenseExpired:     return AppShieldColors.expired;
      case AppShieldEventType.tamperDetected:     return Colors.red;
      case AppShieldEventType.gracePeriodStarted: return AppShieldColors.gracePeriod;
      case AppShieldEventType.validationFailed:   return Colors.orange;
      default:                                    return AppShieldColors.info;
    }
  }

  IconData _iconFor(AppShieldEventType t) {
    switch (t) {
      case AppShieldEventType.licenseActivated:   return Icons.check_circle_rounded;
      case AppShieldEventType.licenseExpired:     return Icons.cancel_rounded;
      case AppShieldEventType.tamperDetected:     return Icons.security_rounded;
      case AppShieldEventType.gracePeriodStarted: return Icons.timer_rounded;
      case AppShieldEventType.validationFailed:   return Icons.error_rounded;
      default:                                    return Icons.notifications_rounded;
    }
  }

  String _titleFor(AppShieldEventType t) {
    switch (t) {
      case AppShieldEventType.licenseActivated:   return 'License Activated';
      case AppShieldEventType.licenseExpired:     return 'License Expired';
      case AppShieldEventType.tamperDetected:     return '⚠ Tamper Detected';
      case AppShieldEventType.gracePeriodStarted: return 'Grace Period Started';
      case AppShieldEventType.validationFailed:   return 'Validation Failed';
      default:                                    return 'License Event';
    }
  }
}
