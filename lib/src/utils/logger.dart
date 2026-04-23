// lib/src/utils/logger.dart

import 'dart:developer' as developer;

/// Log levels supported by AppShieldLogger.
enum LogLevel { verbose, debug, info, warning, error, none }

/// Internal logger for AppShield.
/// All output is suppressed when [_enabled] is false.
class AppShieldLogger {
  AppShieldLogger._();

  static LogLevel _level   = LogLevel.info;
  static bool     _enabled = true;

  static void setLevel(LogLevel level) => _level = level;
  static void setEnabled(bool enabled) => _enabled = enabled;

  static void v(String message, {String? tag}) =>
      _log(LogLevel.verbose, message, tag: tag);

  static void d(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void i(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);

  static void w(String message, {String? tag, Object? error}) =>
      _log(LogLevel.warning, message, tag: tag, error: error);

  static void e(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    if (level.index < _level.index) return;

    final prefix = _prefix(level);
    final label  = tag != null ? '[$tag]' : '[AppShield]';
    final output = '$prefix $label $message';

    developer.log(
      output,
      name: 'AppShield',
      error: error,
      stackTrace: stackTrace,
      level: _dartLevel(level),
    );
  }

  static String _prefix(LogLevel level) {
    switch (level) {
      case LogLevel.verbose: return 'VERBOSE';
      case LogLevel.debug:   return 'DEBUG  ';
      case LogLevel.info:    return 'INFO   ';
      case LogLevel.warning: return 'WARN   ';
      case LogLevel.error:   return 'ERROR  ';
      case LogLevel.none:    return '';
    }
  }

  static int _dartLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose: return 400;
      case LogLevel.debug:   return 500;
      case LogLevel.info:    return 800;
      case LogLevel.warning: return 900;
      case LogLevel.error:   return 1000;
      case LogLevel.none:    return 0;
    }
  }
}
