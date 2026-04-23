// lib/src/ui/themes/app_shield_theme.dart

import 'package:flutter/material.dart';

// Forward-declare constants used below without importing app_shield_colors.dart
// (to avoid circular reference: colors.dart re-exports theme.dart)
abstract class AppShieldThemeData {} // marker mixin for tree-shaking

/// Visual theme for all AppShield UI components.
class AppShieldTheme {
  const AppShieldTheme({
    required this.primaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.brightness,
    this.brandName  = 'AppShield',
    this.logoAsset,
    this.locale     = 'en',
    this.buttonStyle,
    this.inputDecoration,
  });

  final Color       primaryColor;
  final Color       backgroundColor;
  final Color       cardColor;
  final Color       textColor;
  final Color       subtitleColor;
  final Color       borderColor;
  final Brightness  brightness;
  final String      brandName;
  final String?     logoAsset;
  final String      locale;
  final ButtonStyle? buttonStyle;
  final InputDecoration? inputDecoration;

  // ── Presets ───────────────────────────────────────────────────────────────

  factory AppShieldTheme.light({
    Color  primaryColor    = const Color(0xFF3B82F6),
    Color  backgroundColor = const Color(0xFFF1F5F9),
    Color  cardColor       = Colors.white,
    Color  textColor       = const Color(0xFF1E293B),
    Color  subtitleColor   = const Color(0xFF64748B),
    Color  borderColor     = const Color(0xFFE2E8F0),
    String brandName       = 'AppShield',
    String? logoAsset,
    String locale          = 'en',
    ButtonStyle? buttonStyle,
    InputDecoration? inputDecoration,
  }) =>
      AppShieldTheme(
        primaryColor:    primaryColor,
        backgroundColor: backgroundColor,
        cardColor:       cardColor,
        textColor:       textColor,
        subtitleColor:   subtitleColor,
        borderColor:     borderColor,
        brightness:      Brightness.light,
        brandName:       brandName,
        logoAsset:       logoAsset,
        locale:          locale,
        buttonStyle:     buttonStyle,
        inputDecoration: inputDecoration,
      );

  factory AppShieldTheme.dark({
    Color  primaryColor    = const Color(0xFF6366F1),
    Color  backgroundColor = const Color(0xFF0F172A),
    Color  cardColor       = const Color(0xFF1E293B),
    Color  textColor       = const Color(0xFFF1F5F9),
    Color  subtitleColor   = const Color(0xFF94A3B8),
    Color  borderColor     = const Color(0xFF334155),
    String brandName       = 'AppShield',
    String? logoAsset,
    String locale          = 'en',
    ButtonStyle? buttonStyle,
    InputDecoration? inputDecoration,
  }) =>
      AppShieldTheme(
        primaryColor:    primaryColor,
        backgroundColor: backgroundColor,
        cardColor:       cardColor,
        textColor:       textColor,
        subtitleColor:   subtitleColor,
        borderColor:     borderColor,
        brightness:      Brightness.dark,
        brandName:       brandName,
        logoAsset:       logoAsset,
        locale:          locale,
        buttonStyle:     buttonStyle,
        inputDecoration: inputDecoration,
      );

  bool get isDark => brightness == Brightness.dark;

  ThemeData toThemeData() => ThemeData(
        brightness:    brightness,
        colorScheme:   ColorScheme.fromSeed(
          seedColor:   primaryColor,
          brightness:  brightness,
        ),
        scaffoldBackgroundColor: backgroundColor,
        cardColor:     cardColor,
        useMaterial3:  true,
      );
}
