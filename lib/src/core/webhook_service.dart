// lib/src/core/webhook_service.dart
//
// Batch 12 – Advanced: Outgoing webhook / callback dispatcher.
// Lets the host app react to AppShield events without polling.

import 'dart:async';
import '../models/license_model.dart';
import '../models/tamper_record.dart';
import '../utils/logger.dart';

/// Types of webhook events dispatched by AppShield.
enum AppShieldEventType {
  licenseActivated,
  licenseDeactivated,
  licenseExpired,
  licenseRevoked,
  licenseSuspended,
  licenseRenewed,
  licenseRestored,
  trialStarted,
  trialExpired,
  tamperDetected,
  gracePeriodStarted,
  gracePeriodExpired,
  validationSuccess,
  validationFailed,
  offlineModeEntered,
}

/// Payload delivered to every registered webhook handler.
class AppShieldEvent {
  const AppShieldEvent({
    required this.type,
    required this.timestamp,
    this.license,
    this.status,
    this.tamperRecords,
    this.message,
    this.extra = const {},
  });

  final AppShieldEventType     type;
  final DateTime               timestamp;
  final License?               license;
  final LicenseStatus?         status;
  final List<TamperRecord>?    tamperRecords;
  final String?                message;
  final Map<String, dynamic>   extra;

  @override
  String toString() =>
      'AppShieldEvent(${type.name}, at: $timestamp, status: $status)';
}

typedef AppShieldEventHandler = FutureOr<void> Function(AppShieldEvent event);

/// Dispatches [AppShieldEvent]s to all registered handlers.
///
/// Register a handler:
/// ```dart
/// WebhookService.instance.addHandler((event) {
///   if (event.type == AppShieldEventType.licenseExpired) {
///     showExpiryDialog();
///   }
/// });
/// ```
class WebhookService {
  WebhookService._();
  static final WebhookService instance = WebhookService._();

  final _handlers = <AppShieldEventHandler>[];
  final _eventController = StreamController<AppShieldEvent>.broadcast();

  /// Stream of all dispatched events (useful for reactive UIs).
  Stream<AppShieldEvent> get eventStream => _eventController.stream;

  /// Registers an event handler.
  void addHandler(AppShieldEventHandler handler) {
    _handlers.add(handler);
    AppShieldLogger.d('WebhookService: handler registered (total: ${_handlers.length})');
  }

  /// Removes a previously registered handler.
  void removeHandler(AppShieldEventHandler handler) {
    _handlers.remove(handler);
    AppShieldLogger.d('WebhookService: handler removed (total: ${_handlers.length})');
  }

  /// Removes all registered handlers.
  void clearHandlers() {
    _handlers.clear();
    AppShieldLogger.d('WebhookService: all handlers cleared.');
  }

  int get handlerCount => _handlers.length;

  /// Dispatches an event to all registered handlers (fire-and-forget).
  Future<void> dispatch(AppShieldEvent event) async {
    AppShieldLogger.d('WebhookService: dispatching ${event.type.name}');
    _eventController.add(event);
    for (final handler in List<AppShieldEventHandler>.from(_handlers)) {
      try {
        await handler(event);
      } catch (e, st) {
        AppShieldLogger.e(
          'WebhookService: handler threw an exception',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  // ── Convenience dispatchers ───────────────────────────────────────────────

  Future<void> dispatchActivated(License license) => dispatch(AppShieldEvent(
        type:      AppShieldEventType.licenseActivated,
        timestamp: DateTime.now().toUtc(),
        license:   license,
        status:    LicenseStatus.active,
      ));

  Future<void> dispatchDeactivated() => dispatch(AppShieldEvent(
        type:      AppShieldEventType.licenseDeactivated,
        timestamp: DateTime.now().toUtc(),
        status:    LicenseStatus.notActivated,
      ));

  Future<void> dispatchExpired(License? license) => dispatch(AppShieldEvent(
        type:      AppShieldEventType.licenseExpired,
        timestamp: DateTime.now().toUtc(),
        license:   license,
        status:    LicenseStatus.expired,
      ));

  Future<void> dispatchRevoked(License? license, {String? reason}) =>
      dispatch(AppShieldEvent(
        type:      AppShieldEventType.licenseRevoked,
        timestamp: DateTime.now().toUtc(),
        license:   license,
        status:    LicenseStatus.revoked,
        message:   reason,
      ));

  Future<void> dispatchTamperDetected(List<TamperRecord> records) =>
      dispatch(AppShieldEvent(
        type:          AppShieldEventType.tamperDetected,
        timestamp:     DateTime.now().toUtc(),
        tamperRecords: records,
        status:        LicenseStatus.tampered,
        message:       'Tampering detected: ${records.map((r) => r.tamperType).join(', ')}',
      ));

  Future<void> dispatchGracePeriodStarted(License? license, int graceDays) =>
      dispatch(AppShieldEvent(
        type:      AppShieldEventType.gracePeriodStarted,
        timestamp: DateTime.now().toUtc(),
        license:   license,
        status:    LicenseStatus.gracePeriod,
        extra:     {'grace_days': graceDays},
      ));

  Future<void> dispatchTrialStarted(int trialDays) => dispatch(AppShieldEvent(
        type:      AppShieldEventType.trialStarted,
        timestamp: DateTime.now().toUtc(),
        status:    LicenseStatus.trial,
        extra:     {'trial_days': trialDays},
      ));

  Future<void> dispatchValidationSuccess(License license) =>
      dispatch(AppShieldEvent(
        type:      AppShieldEventType.validationSuccess,
        timestamp: DateTime.now().toUtc(),
        license:   license,
        status:    LicenseStatus.active,
      ));

  Future<void> dispatchValidationFailed(String reason) =>
      dispatch(AppShieldEvent(
        type:      AppShieldEventType.validationFailed,
        timestamp: DateTime.now().toUtc(),
        message:   reason,
      ));

  void dispose() => _eventController.close();
}
