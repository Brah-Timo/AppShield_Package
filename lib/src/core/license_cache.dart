// lib/src/core/license_cache.dart
//
// Batch 12 – Advanced: In-memory license cache with TTL and observers.
// Reduces redundant disk reads and enables reactive UI updates.

import 'dart:async';
import '../models/license_model.dart';
import '../utils/logger.dart';

/// In-memory cache for the current [License] with automatic TTL invalidation.
///
/// ```dart
/// LicenseCache.instance.put(license, ttlMinutes: 60);
/// final cached = LicenseCache.instance.get();
/// ```
class LicenseCache {
  LicenseCache._();
  static final LicenseCache instance = LicenseCache._();

  License?  _license;
  DateTime? _cachedAt;
  int       _ttlMinutes = 60;

  final _changeController = StreamController<License?>.broadcast();

  /// Stream of cache updates (null = cache cleared).
  Stream<License?> get onChange => _changeController.stream;

  /// Currently cached license (null if empty or expired).
  License? get current {
    if (_license == null || _cachedAt == null) return null;
    final age = DateTime.now().difference(_cachedAt!).inMinutes;
    if (age > _ttlMinutes) {
      AppShieldLogger.d('LicenseCache TTL expired (age=${age}m > ttl=${_ttlMinutes}m)');
      _license  = null;
      _cachedAt = null;
      _changeController.add(null);
      return null;
    }
    return _license;
  }

  bool get isEmpty => current == null;
  bool get isNotEmpty => current != null;

  /// Stores [license] in the cache with [ttlMinutes] time-to-live.
  void put(License license, {int ttlMinutes = 60}) {
    _license    = license;
    _cachedAt   = DateTime.now();
    _ttlMinutes = ttlMinutes;
    AppShieldLogger.d('LicenseCache updated (ttl=${ttlMinutes}m, plan=${license.plan})');
    _changeController.add(license);
  }

  /// Forces the cache to refresh on next read.
  void invalidate() {
    AppShieldLogger.d('LicenseCache invalidated.');
    _license  = null;
    _cachedAt = null;
    _changeController.add(null);
  }

  /// Age of the cached entry in minutes, or -1 if empty.
  int get ageMinutes {
    if (_cachedAt == null) return -1;
    return DateTime.now().difference(_cachedAt!).inMinutes;
  }

  void dispose() => _changeController.close();
}
