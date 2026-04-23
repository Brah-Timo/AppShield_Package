// lib/src/core/license_export_service.dart
//
// Batch 14 – License Export Service.
// Generates human-readable and machine-readable license reports
// that can be saved to disk or shared via clipboard.

import 'dart:convert';

import '../models/license_model.dart';
import '../models/activity_log_entry.dart';
import '../utils/helpers.dart';
import '../utils/logger.dart';

/// Format to export the license report in.
enum LicenseExportFormat {
  /// Plain human-readable text
  plainText,

  /// JSON (machine-readable)
  json,

  /// Markdown (documentation-friendly)
  markdown,

  /// CSV (spreadsheet-friendly, for activity logs)
  csv,
}

/// Result of an export operation.
class LicenseExportResult {
  const LicenseExportResult({
    required this.content,
    required this.format,
    required this.generatedAt,
    required this.filename,
  });

  /// The exported content string.
  final String             content;

  /// The format used.
  final LicenseExportFormat format;

  /// When the export was generated.
  final DateTime           generatedAt;

  /// Suggested filename (without path).
  final String             filename;

  /// File extension matching [format].
  String get extension {
    switch (format) {
      case LicenseExportFormat.plainText: return 'txt';
      case LicenseExportFormat.json:      return 'json';
      case LicenseExportFormat.markdown:  return 'md';
      case LicenseExportFormat.csv:       return 'csv';
    }
  }

  @override
  String toString() =>
      'LicenseExportResult(format: ${format.name}, '
      'size: ${content.length}B, file: $filename)';
}

/// Service that generates license reports in multiple formats.
///
/// ```dart
/// final exporter = LicenseExportService.instance;
///
/// // Export full license report as Markdown
/// final result = await exporter.exportLicense(
///   license: AppShield.instance.currentLicense!,
///   format:  LicenseExportFormat.markdown,
/// );
/// print(result.content);
///
/// // Export activity log as CSV
/// final csv = await exporter.exportActivityLog(
///   entries: await AppShield.instance.getActivityLog(),
///   format:  LicenseExportFormat.csv,
/// );
/// ```
class LicenseExportService {
  LicenseExportService._();

  static final LicenseExportService _instance = LicenseExportService._();
  static LicenseExportService get instance => _instance;

  // ── License export ────────────────────────────────────────────────────────

  /// Exports a single [License] object.
  LicenseExportResult exportLicense({
    required License            license,
    LicenseExportFormat         format   = LicenseExportFormat.plainText,
    Map<String, String>         extra    = const {},
  }) {
    AppShieldLogger.d('LicenseExportService: exporting as ${format.name}.');

    final content = switch (format) {
      LicenseExportFormat.plainText => _licensePlainText(license, extra),
      LicenseExportFormat.json      => _licenseJson(license),
      LicenseExportFormat.markdown  => _licenseMarkdown(license, extra),
      LicenseExportFormat.csv       => _licenseCsv(license),
    };

    final ts  = DateTime.now();
    final slug = license.plan.replaceAll(' ', '_').toLowerCase();
    final filename = 'appshield_license_${slug}_'
        '${ts.year}${_pad(ts.month)}${_pad(ts.day)}.${_ext(format)}';

    return LicenseExportResult(
      content:     content,
      format:      format,
      generatedAt: ts,
      filename:    filename,
    );
  }

  // ── Activity log export ───────────────────────────────────────────────────

  /// Exports a list of [ActivityLogEntry] objects.
  LicenseExportResult exportActivityLog({
    required List<ActivityLogEntry> entries,
    LicenseExportFormat             format = LicenseExportFormat.csv,
  }) {
    AppShieldLogger.d(
        'LicenseExportService: exporting ${entries.length} log entries.');

    final content = switch (format) {
      LicenseExportFormat.csv       => _logCsv(entries),
      LicenseExportFormat.json      => _logJson(entries),
      LicenseExportFormat.markdown  => _logMarkdown(entries),
      LicenseExportFormat.plainText => _logPlainText(entries),
    };

    final ts       = DateTime.now();
    final filename = 'appshield_activity_'
        '${ts.year}${_pad(ts.month)}${_pad(ts.day)}.${_ext(format)}';

    return LicenseExportResult(
      content:     content,
      format:      format,
      generatedAt: ts,
      filename:    filename,
    );
  }

  // ── Plain-text ────────────────────────────────────────────────────────────

  String _licensePlainText(License lic, Map<String, String> extra) {
    final sb = StringBuffer();
    sb.writeln('════════════════════════════════════════');
    sb.writeln('  AppShield License Report');
    sb.writeln('  Generated: ${_fmt(DateTime.now())}');
    sb.writeln('════════════════════════════════════════');
    sb.writeln();
    sb.writeln('KEY        : ${AppShieldHelpers.obfuscateLicenseKey(lic.key)}');
    sb.writeln('PLAN       : ${lic.plan.toUpperCase()}');
    sb.writeln('TYPE       : ${lic.type.name}');
    sb.writeln('STATUS     : ${lic.status.name}');
    sb.writeln('CUSTOMER   : ${lic.customerName ?? "—"}');
    sb.writeln('EMAIL      : ${lic.customerEmail ?? "—"}');
    sb.writeln('APP ID     : ${lic.appId}');
    sb.writeln('DEVICE ID  : ${lic.deviceId}');
    sb.writeln('ACTIVATED  : ${AppShieldHelpers.formatDate(lic.activatedAt)}');
    sb.writeln('EXPIRES    : ${lic.isPerpetual ? "Never (Perpetual)" : AppShieldHelpers.formatDate(lic.expiresAt)}');
    if (!lic.isPerpetual) {
      sb.writeln('DAYS LEFT  : ${lic.daysRemaining}');
    }
    if (lic.lastValidatedAt != null) {
      sb.writeln('VALIDATED  : ${_fmt(lic.lastValidatedAt!)}');
    }

    if (lic.features.isNotEmpty) {
      sb.writeln();
      sb.writeln('── FEATURES ─────────────────────────────');
      for (final e in lic.features.entries) {
        final mark = e.value ? '✓' : '✗';
        sb.writeln('  $mark  ${e.key}');
      }
    }

    if (lic.limits.isNotEmpty) {
      sb.writeln();
      sb.writeln('── LIMITS ───────────────────────────────');
      for (final e in lic.limits.entries) {
        sb.writeln('  ${e.key.padRight(20)}: ${e.value}');
      }
    }

    if (extra.isNotEmpty) {
      sb.writeln();
      sb.writeln('── ADDITIONAL INFO ──────────────────────');
      for (final e in extra.entries) {
        sb.writeln('  ${e.key.padRight(20)}: ${e.value}');
      }
    }

    sb.writeln();
    sb.writeln('════════════════════════════════════════');
    return sb.toString();
  }

  // ── JSON ──────────────────────────────────────────────────────────────────

  String _licenseJson(License lic) {
    final map = {
      ...lic.toJson(),
      'export_meta': {
        'generated_at':  DateTime.now().toIso8601String(),
        'days_remaining': lic.daysRemaining,
        'is_valid':       lic.isValid,
        'is_expiring_soon': lic.isExpiringSoon,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  // ── Markdown ──────────────────────────────────────────────────────────────

  String _licenseMarkdown(License lic, Map<String, String> extra) {
    final sb = StringBuffer();
    sb.writeln('# AppShield License Report');
    sb.writeln();
    sb.writeln('> Generated: ${_fmt(DateTime.now())}');
    sb.writeln();
    sb.writeln('## License Details');
    sb.writeln();
    sb.writeln('| Field        | Value |');
    sb.writeln('|:-------------|:------|');
    sb.writeln('| **Key**      | `${AppShieldHelpers.obfuscateLicenseKey(lic.key)}` |');
    sb.writeln('| **Plan**     | ${lic.plan.toUpperCase()} |');
    sb.writeln('| **Type**     | ${lic.type.name} |');
    sb.writeln('| **Status**   | ${lic.status.name} |');
    sb.writeln('| **Customer** | ${lic.customerName ?? "—"} |');
    sb.writeln('| **Email**    | ${lic.customerEmail ?? "—"} |');
    sb.writeln('| **App ID**   | `${lic.appId}` |');
    sb.writeln('| **Activated**| ${AppShieldHelpers.formatDate(lic.activatedAt)} |');
    sb.writeln('| **Expires**  | ${lic.isPerpetual ? "Perpetual" : AppShieldHelpers.formatDate(lic.expiresAt)} |');
    if (!lic.isPerpetual) {
      sb.writeln('| **Days Left**| ${lic.daysRemaining} |');
    }

    if (lic.features.isNotEmpty) {
      sb.writeln();
      sb.writeln('## Features');
      sb.writeln();
      for (final e in lic.features.entries) {
        sb.writeln('- [${e.value ? "x" : " "}] `${e.key}`');
      }
    }

    if (lic.limits.isNotEmpty) {
      sb.writeln();
      sb.writeln('## Limits');
      sb.writeln();
      sb.writeln('| Limit | Value |');
      sb.writeln('|:------|------:|');
      for (final e in lic.limits.entries) {
        sb.writeln('| `${e.key}` | ${e.value} |');
      }
    }

    if (extra.isNotEmpty) {
      sb.writeln();
      sb.writeln('## Additional Info');
      sb.writeln();
      for (final e in extra.entries) {
        sb.writeln('- **${e.key}**: ${e.value}');
      }
    }

    return sb.toString();
  }

  // ── CSV (license) ─────────────────────────────────────────────────────────

  String _licenseCsv(License lic) {
    final rows = <String>[
      'field,value',
      'key,${_csvEscape(lic.key)}',
      'plan,${_csvEscape(lic.plan)}',
      'type,${lic.type.name}',
      'status,${lic.status.name}',
      'customer_name,${_csvEscape(lic.customerName ?? "")}',
      'customer_email,${_csvEscape(lic.customerEmail ?? "")}',
      'app_id,${_csvEscape(lic.appId)}',
      'device_id,${_csvEscape(lic.deviceId)}',
      'activated_at,${lic.activatedAt.toIso8601String()}',
      'expires_at,${lic.expiresAt.toIso8601String()}',
      'days_remaining,${lic.daysRemaining}',
      'is_valid,${lic.isValid}',
      'is_perpetual,${lic.isPerpetual}',
    ];
    return rows.join('\n');
  }

  // ── Activity log exports ──────────────────────────────────────────────────

  String _logCsv(List<ActivityLogEntry> entries) {
    final lines = <String>[
      'timestamp,action,details,license_key,device_fingerprint',
    ];
    for (final e in entries) {
      lines.add([
        e.timestamp.toIso8601String(),
        _csvEscape(e.action),
        _csvEscape(e.details ?? ''),
        _csvEscape(e.licenseKey ?? ''),
        _csvEscape(e.deviceFingerprint ?? ''),
      ].join(','));
    }
    return lines.join('\n');
  }

  String _logJson(List<ActivityLogEntry> entries) =>
      const JsonEncoder.withIndent('  ')
          .convert(entries.map((e) => e.toJson()).toList());

  String _logMarkdown(List<ActivityLogEntry> entries) {
    final sb = StringBuffer();
    sb.writeln('# AppShield Activity Log');
    sb.writeln();
    sb.writeln('> Generated: ${_fmt(DateTime.now())} — ${entries.length} events');
    sb.writeln();
    sb.writeln('| Timestamp | Action | Details |');
    sb.writeln('|:----------|:-------|:--------|');
    for (final e in entries) {
      sb.writeln('| ${_fmt(e.timestamp)} '
          '| `${e.action}` '
          '| ${e.details ?? "—"} |');
    }
    return sb.toString();
  }

  String _logPlainText(List<ActivityLogEntry> entries) {
    final sb = StringBuffer();
    sb.writeln('AppShield Activity Log — ${entries.length} events');
    sb.writeln('Generated: ${_fmt(DateTime.now())}');
    sb.writeln('─' * 60);
    for (final e in entries) {
      sb.writeln('[${_fmt(e.timestamp)}] ${e.action.padRight(20)} '
          '${e.details ?? ""}');
    }
    return sb.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(DateTime dt) =>
      '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
      '${_pad(dt.hour)}:${_pad(dt.minute)}:${_pad(dt.second)}';

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _ext(LicenseExportFormat f) {
    switch (f) {
      case LicenseExportFormat.plainText: return 'txt';
      case LicenseExportFormat.json:      return 'json';
      case LicenseExportFormat.markdown:  return 'md';
      case LicenseExportFormat.csv:       return 'csv';
    }
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
