// lib/src/ui/themes/app_shield_colors.dart
//
// IMPORTANT: Dart requires all `export` / `import` directives to appear
// before any declarations. The re-export below is therefore placed at the top.

// ── Re-export AppShieldTheme & AppShieldThemeData for backward-compat ────────
export 'app_shield_theme.dart' show AppShieldThemeData, AppShieldTheme;

import 'package:flutter/material.dart';

/// Semantic color palette for AppShield UI components.
class AppShieldColors {
  AppShieldColors._();

  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFF3B82F6); // blue-500
  static const Color accent    = Color(0xFF6366F1); // indigo-500
  static const Color onPrimary = Colors.white;

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color active      = Color(0xFF22C55E); // green-500
  static const Color trial       = Color(0xFF8B5CF6); // violet-500
  static const Color gracePeriod = Color(0xFFF59E0B); // amber-500
  static const Color expired     = Color(0xFFEF4444); // red-500
  static const Color revoked     = Color(0xFF991B1B); // red-800
  static const Color suspended   = Color(0xFFD97706); // amber-600
  static const Color offline     = Color(0xFF64748B); // slate-500
  static const Color tampered    = Color(0xFFDC2626); // red-600
  static const Color mismatch    = Color(0xFFEA580C); // orange-600
  static const Color inactive    = Color(0xFF94A3B8); // slate-400

  // ── UI ────────────────────────────────────────────────────────────────────
  static const Color warning     = Color(0xFFF59E0B); // amber-500
  static const Color info        = Color(0xFF0EA5E9); // sky-500
  static const Color success     = Color(0xFF16A34A); // green-600
  static const Color border      = Color(0xFFE2E8F0); // slate-200
  static const Color cardBg      = Colors.white;
  static const Color textMuted   = Color(0xFF94A3B8); // slate-400

  // ── Lookup helpers ────────────────────────────────────────────────────────

  /// Returns the semantic color for a given license status name.
  static Color forStatus(String statusName) {
    switch (statusName) {
      case 'active':         return active;
      case 'trial':          return trial;
      case 'gracePeriod':    return gracePeriod;
      case 'expired':        return expired;
      case 'revoked':        return revoked;
      case 'suspended':      return suspended;
      case 'tampered':       return tampered;
      case 'deviceMismatch': return mismatch;
      case 'offline':        return offline;
      default:               return inactive;
    }
  }

  /// Returns the semantic color for a notification severity.
  static Color forSeverity(String severity) {
    switch (severity) {
      case 'success': return success;
      case 'warning': return warning;
      case 'error':   return expired;
      default:        return info;
    }
  }
}
