// lib/src/core/license_pool_manager.dart
//
// Batch 12 – Advanced: License Pool / seat-based licensing support.
// Enables enterprise scenarios where multiple users share a pool of seats.

import '../models/license_model.dart';
import '../utils/logger.dart';

/// Represents a single seat in a license pool.
class LicenseSeat {
  LicenseSeat({
    required this.seatId,
    required this.userId,
    required this.assignedAt,
    this.deviceFingerprint,
    this.userName,
    this.userEmail,
    this.isActive = true,
  });

  final String    seatId;
  final String    userId;
  final DateTime  assignedAt;
  final String?   deviceFingerprint;
  final String?   userName;
  final String?   userEmail;
  bool            isActive;

  Map<String, dynamic> toJson() => {
        'seat_id':            seatId,
        'user_id':            userId,
        'assigned_at':        assignedAt.toIso8601String(),
        'device_fingerprint': deviceFingerprint,
        'user_name':          userName,
        'user_email':         userEmail,
        'is_active':          isActive,
      };

  factory LicenseSeat.fromJson(Map<String, dynamic> j) => LicenseSeat(
        seatId:            j['seat_id']            as String,
        userId:            j['user_id']             as String,
        assignedAt:        DateTime.parse(j['assigned_at'] as String),
        deviceFingerprint: j['device_fingerprint']  as String?,
        userName:          j['user_name']            as String?,
        userEmail:         j['user_email']           as String?,
        isActive:          j['is_active'] as bool? ?? true,
      );

  @override
  String toString() =>
      'LicenseSeat(id: $seatId, user: ${userEmail ?? userId}, active: $isActive)';
}

/// Manages a pool of [LicenseSeat]s for seat-based / enterprise licensing.
///
/// ```dart
/// final pool = LicensePoolManager(
///   license:   myEnterpriseLicense,
///   totalSeats: 50,
/// );
///
/// final seat = await pool.claimSeat(userId: 'user_123', deviceFingerprint: fp);
/// print('Remaining: ${pool.availableSeats}');
///
/// await pool.releaseSeat(seatId: seat!.seatId);
/// ```
class LicensePoolManager {
  LicensePoolManager({
    required this.license,
    required this.totalSeats,
    this.allowSeatReassignment = false,
  }) {
    AppShieldLogger.i(
      'LicensePoolManager: pool of $totalSeats seats '
      'for plan "${license.plan}".',
    );
  }

  final License  license;
  final int      totalSeats;
  final bool     allowSeatReassignment;

  final List<LicenseSeat> _seats = [];

  // ── Counts ────────────────────────────────────────────────────────────────

  int get usedSeats      => _seats.where((s) => s.isActive).length;
  int get availableSeats => totalSeats - usedSeats;
  int get totalUsed      => _seats.length;
  bool get hasAvailableSeats => availableSeats > 0;

  List<LicenseSeat> get activeSeats  =>
      _seats.where((s) => s.isActive).toList();
  List<LicenseSeat> get allSeats     => List.unmodifiable(_seats);

  // ── Claim ─────────────────────────────────────────────────────────────────

  /// Claims a seat for [userId].
  ///
  /// Returns null if no seats are available (and [allowSeatReassignment] is false).
  LicenseSeat? claimSeat({
    required String userId,
    String? deviceFingerprint,
    String? userName,
    String? userEmail,
  }) {
    // Check if user already has a seat
    final existing = _seats.firstWhere(
      (s) => s.userId == userId && s.isActive,
      orElse: () => LicenseSeat(
        seatId:     '',
        userId:     '',
        assignedAt: DateTime.now(),
      ),
    );

    if (existing.seatId.isNotEmpty) {
      AppShieldLogger.d('LicensePoolManager: user $userId already has seat ${existing.seatId}');
      return existing;
    }

    if (!hasAvailableSeats) {
      if (!allowSeatReassignment) {
        AppShieldLogger.w(
          'LicensePoolManager: no seats available '
          '(used=$usedSeats / total=$totalSeats)',
        );
        return null;
      }
      // Re-assign oldest seat
      final oldest = _seats
          .where((s) => s.isActive)
          .toList()
        ..sort((a, b) => a.assignedAt.compareTo(b.assignedAt));
      if (oldest.isNotEmpty) {
        oldest.first.isActive = false;
        AppShieldLogger.w(
          'LicensePoolManager: re-assigned seat ${oldest.first.seatId} '
          'from ${oldest.first.userId} to $userId',
        );
      }
    }

    final seat = LicenseSeat(
      seatId:            '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      userId:            userId,
      assignedAt:        DateTime.now().toUtc(),
      deviceFingerprint: deviceFingerprint,
      userName:          userName,
      userEmail:         userEmail,
    );
    _seats.add(seat);
    AppShieldLogger.i(
      'LicensePoolManager: seat ${seat.seatId} claimed by $userId '
      '(used=$usedSeats / total=$totalSeats)',
    );
    return seat;
  }

  // ── Release ───────────────────────────────────────────────────────────────

  /// Releases the seat with [seatId] or all seats belonging to [userId].
  bool releaseSeat({String? seatId, String? userId}) {
    assert(seatId != null || userId != null,
        'Provide seatId or userId to release a seat.');
    bool released = false;
    for (final s in _seats) {
      if ((seatId != null && s.seatId == seatId) ||
          (userId != null && s.userId == userId)) {
        s.isActive = false;
        released   = true;
        AppShieldLogger.i('LicensePoolManager: seat ${s.seatId} released.');
      }
    }
    return released;
  }

  // ── Lookup ────────────────────────────────────────────────────────────────

  LicenseSeat? findByUser(String userId) =>
      _seats.cast<LicenseSeat?>().firstWhere(
        (s) => s!.userId == userId && s.isActive,
        orElse: () => null,
      );

  LicenseSeat? findBySeatId(String seatId) =>
      _seats.cast<LicenseSeat?>().firstWhere(
        (s) => s!.seatId == seatId,
        orElse: () => null,
      );

  // ── Serialization ─────────────────────────────────────────────────────────

  List<Map<String, dynamic>> toJson() =>
      _seats.map((s) => s.toJson()).toList();

  void loadFromJson(List<Map<String, dynamic>> json) {
    _seats
      ..clear()
      ..addAll(json.map(LicenseSeat.fromJson));
  }

  @override
  String toString() =>
      'LicensePoolManager(total=$totalSeats, used=$usedSeats, available=$availableSeats)';
}
