// lib/src/core/multi_tenant_manager.dart
//
// Batch 12 – Advanced: Multi-tenant / white-label support.
// Allows a single app binary to serve multiple tenants, each with
// their own AppShield configuration, license, and branding.

import '../models/license_model.dart';
import '../utils/logger.dart';
import '../../app_shield_config.dart';

/// A tenant context that groups an [AppShieldConfig] with its resolved license.
class TenantContext {
  TenantContext({
    required this.tenantId,
    required this.tenantName,
    required this.config,
    this.license,
    this.logoUrl,
    this.primaryColorHex,
    this.isActive = true,
  });

  final String         tenantId;
  final String         tenantName;
  final AppShieldConfig config;
  License?             license;
  final String?        logoUrl;
  final String?        primaryColorHex;
  bool                 isActive;

  bool get hasValidLicense =>
      license != null && (license!.isValid || license!.isPerpetual);

  Map<String, dynamic> toJson() => {
        'tenant_id':          tenantId,
        'tenant_name':        tenantName,
        'logo_url':           logoUrl,
        'primary_color_hex':  primaryColorHex,
        'is_active':          isActive,
        'has_valid_license':  hasValidLicense,
      };

  @override
  String toString() =>
      'TenantContext(id: $tenantId, name: $tenantName, '
      'license: ${license?.plan ?? "none"})';
}

/// Manages multiple [TenantContext]s and the currently active one.
///
/// ```dart
/// final mgr = MultiTenantManager.instance;
///
/// mgr.registerTenant(TenantContext(
///   tenantId:   'acme_corp',
///   tenantName: 'ACME Corporation',
///   config:     AppShieldConfig(appId: 'acme', ...),
/// ));
///
/// await mgr.switchTenant('acme_corp');
/// print(mgr.current?.tenantName);   // ACME Corporation
/// ```
class MultiTenantManager {
  MultiTenantManager._();
  static final MultiTenantManager instance = MultiTenantManager._();

  final _tenants = <String, TenantContext>{};
  TenantContext? _activeTenant;

  /// The currently active tenant context.
  TenantContext? get current => _activeTenant;

  /// All registered tenants.
  List<TenantContext> get all => _tenants.values.toList();

  int get count => _tenants.length;

  // ── Register / unregister ─────────────────────────────────────────────────

  void registerTenant(TenantContext context) {
    _tenants[context.tenantId] = context;
    AppShieldLogger.i('MultiTenantManager: tenant "${context.tenantId}" registered.');
    // Auto-select as active if it is the first one
    _activeTenant ??= context;
  }

  void unregisterTenant(String tenantId) {
    _tenants.remove(tenantId);
    if (_activeTenant?.tenantId == tenantId) {
      _activeTenant = _tenants.values.cast<TenantContext?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );
    }
    AppShieldLogger.i('MultiTenantManager: tenant "$tenantId" removed.');
  }

  // ── Switch ────────────────────────────────────────────────────────────────

  /// Activates a tenant by [tenantId].
  /// Returns false if the tenant does not exist or is inactive.
  bool switchTenant(String tenantId) {
    final ctx = _tenants[tenantId];
    if (ctx == null) {
      AppShieldLogger.w('MultiTenantManager: tenant "$tenantId" not found.');
      return false;
    }
    if (!ctx.isActive) {
      AppShieldLogger.w('MultiTenantManager: tenant "$tenantId" is inactive.');
      return false;
    }
    _activeTenant = ctx;
    AppShieldLogger.i('MultiTenantManager: switched to tenant "${ctx.tenantName}".');
    return true;
  }

  // ── License update ────────────────────────────────────────────────────────

  void updateLicense(String tenantId, License? license) {
    final ctx = _tenants[tenantId];
    if (ctx == null) return;
    ctx.license = license;
    AppShieldLogger.d(
      'MultiTenantManager: license updated for "$tenantId" '
      '(plan: ${license?.plan ?? "none"}).',
    );
  }

  // ── Feature / limit check for active tenant ───────────────────────────────

  bool hasFeature(String feature) =>
      _activeTenant?.license?.hasFeature(feature) ?? false;

  int getLimit(String key, {int defaultValue = 0}) =>
      _activeTenant?.license?.getLimit(key, defaultValue: defaultValue) ??
      defaultValue;

  bool get isLicenseValid => _activeTenant?.hasValidLicense ?? false;

  // ── Helpers ───────────────────────────────────────────────────────────────

  TenantContext? getById(String tenantId) => _tenants[tenantId];

  /// Returns tenants whose license is valid.
  List<TenantContext> get activeLicensedTenants =>
      _tenants.values.where((t) => t.hasValidLicense).toList();

  @override
  String toString() =>
      'MultiTenantManager(tenants=${_tenants.length}, '
      'active=${_activeTenant?.tenantId ?? "none"})';
}
