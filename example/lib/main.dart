// example/lib/main.dart
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║           AppShield – Complete Windows Desktop Demo App                ║
// ║  Showcasing all features: activation, guards, analytics, multi-tenant, ║
// ║  seat pooling, health monitoring, webhooks, grace periods, and more.   ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_shield/app_shield.dart';

import 'screens/dashboard_screen.dart';
import 'screens/features_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/advanced_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/activity_log_screen.dart';
import 'screens/export_screen.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/title_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Build AppShield configuration ─────────────────────────────────────────
  final config = AppShieldConfig(
    // Required fields
    appId:      'com.example.appshield_demo',
    apiBaseUrl: 'https://license.mycompany.com/api',
    apiKey:     'demo_api_key_here',
    appSecret:  'demo_secret_passphrase_32chars!!',

    // RSA public key (replace with real key for production)
    publicKey: '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2a2rwplBQLzHPZe5TNJF
...your_real_rsa_public_key_here...
-----END PUBLIC KEY-----''',

    // Offline support
    enableOfflineMode: true,
    offlineGraceDays:  14,

    // Grace period policy
    gracePeriodPolicy: GracePeriodPolicy(
      strategy:             OfflineFallbackStrategy.gracePeriod,
      graceDays:            14,
      warnDaysBeforeExpiry: 3,
      allowGraceExtensions: true,
      maxGraceExtensions:   2,
      restrictedFeaturesInGrace: [
        AppShieldConstants.featureAdvancedReports,
        AppShieldConstants.featureExportPdf,
      ],
    ),

    // Trial
    enableTrial: true,
    trialDays:   14,

    // Device binding
    enableDeviceBinding:  true,
    maxDevicesPerLicense: 3,

    // Clock tamper detection
    enableClockCheck: true,

    // Validation interval
    validationIntervalHr: 12,

    // Subscription
    enableAutoRenewal: true,
    buyLicenseUrl:     'https://mycompany.com/buy',
    supportUrl:        'https://mycompany.com/support',

    // Telemetry (disable for demo)
    enableTelemetry: false,

    // Tamper detection
    enableTamperDetection:    true,
    enableRootJailbreakCheck: false,
    enableEmulatorCheck:      false,
    enableDebuggerCheck:      false,

    // Theme
    theme: AppShieldTheme.light(
      primaryColor:    const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFFF1F5F9),
      brandName:       'AppShield Demo',
    ),

    // Logging
    enableLogging: true,

    // Advanced (Batch 12)
    enableAnalytics:     true,
    enableHealthMonitor: true,
    enableWebhooks:      true,
    enableLicenseCache:  true,
    cacheTTLMinutes:     60,

    // Multi-tenant
    enableMultiTenant: true,
    tenantId:          'default_tenant',

    // Seat pooling
    enableSeatPooling: true,
    totalSeats:        25,

    // Network
    requestTimeoutSeconds: 30,
    enableRetryOnFailure:  true,
    retryCount:            3,

    // Custom headers
    customHeaders: {
      'X-Client-Version': '1.0.0',
      'X-Platform':       defaultTargetPlatform.name,
    },

    // Webhook callback
    onLicenseEvent: (event) {
      final e = event as AppShieldEvent;
      debugPrint('[AppShield] Event: ${e.type.name}');
    },
  );

  // ── Initialize AppShield ───────────────────────────────────────────────────
  try {
    await AppShield.initialize(config: config);

    // Register webhook handlers
    WebhookService.instance.addHandler(_globalWebhookHandler);

    // Register demo tenants
    _registerDemoTenants();

    AppShieldLogger.i('AppShield initialized successfully.');
  } catch (e, st) {
    AppShieldLogger.e('AppShield initialization failed', error: e, stackTrace: st);
    // App continues – guard will display activation screen
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppShieldProvider(
        enableHealthMonitor: true,
        enableAnalytics:     true,
        healthCheckInterval: const Duration(seconds: 30),
      )..initialize(),
      child: const AppShieldDemoApp(),
    ),
  );
}

// ── Global webhook handler ─────────────────────────────────────────────────

Future<void> _globalWebhookHandler(AppShieldEvent event) async {
  switch (event.type) {
    case AppShieldEventType.licenseExpired:
      AppShieldLogger.w('⚠ License expired!');
      break;
    case AppShieldEventType.tamperDetected:
      AppShieldLogger.e('🚨 Tamper detected: '
          '${event.tamperRecords?.map((r) => r.tamperType).join(", ")}');
      break;
    case AppShieldEventType.validationFailed:
      AppShieldLogger.w('Validation failed: ${event.message}');
      break;
    case AppShieldEventType.gracePeriodStarted:
      AppShieldLogger.i('Grace period started '
          '(${event.extra["grace_days"]} days).');
      break;
    default:
      AppShieldLogger.d('Webhook: ${event.type.name}');
  }
}

// ── Register demo tenants ──────────────────────────────────────────────────

void _registerDemoTenants() {
  final mgr = MultiTenantManager.instance;

  mgr.registerTenant(TenantContext(
    tenantId:        'acme_corp',
    tenantName:      'ACME Corporation',
    primaryColorHex: '#3B82F6',
    config: AppShieldConfig(
      appId:      'com.acme.myapp',
      apiBaseUrl: 'https://license.acme.com/api',
      apiKey:     'acme_api_key',
    ),
  ));

  mgr.registerTenant(TenantContext(
    tenantId:        'globex',
    tenantName:      'Globex Industries',
    primaryColorHex: '#10B981',
    config: AppShieldConfig(
      appId:      'com.globex.myapp',
      apiBaseUrl: 'https://license.globex.com/api',
      apiKey:     'globex_api_key',
    ),
  ));

  mgr.registerTenant(TenantContext(
    tenantId:        'initech',
    tenantName:      'Initech LLC',
    primaryColorHex: '#F59E0B',
    config: AppShieldConfig(
      appId:      'com.initech.myapp',
      apiBaseUrl: 'https://license.initech.com/api',
      apiKey:     'initech_api_key',
    ),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT APP WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AppShieldDemoApp extends StatefulWidget {
  const AppShieldDemoApp({super.key});

  @override
  State<AppShieldDemoApp> createState() => _AppShieldDemoAppState();
}

class _AppShieldDemoAppState extends State<AppShieldDemoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() => setState(() {
        _themeMode = _themeMode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
      });

  @override
  Widget build(BuildContext context) {
    final shieldTheme = AppShield.isInitialized
        ? AppShield.instance.config.resolvedTheme
        : AppShieldTheme.light();

    return MaterialApp(
      title:                      'AppShield Demo',
      debugShowCheckedModeBanner: false,
      theme:                      shieldTheme.toThemeData(),
      darkTheme:                  AppShieldTheme.dark().toThemeData(),
      themeMode:                  _themeMode,
      // Wrap with in-app notification overlay for license events
      builder: (ctx, child) => LicenseNotificationOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppShieldGuard(
        onLoading: () => const _SplashScreen(),
        onLicenseInvalid: () => ActivationScreen(onActivated: () {}),
        onTrialExpired: () => ExpiredScreen(
          onActivate: () {},
          message: 'Your trial has expired. Please activate a license.',
        ),
        child: _MainShell(
          themeMode: _themeMode,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:      const Color(0xFF3B82F6).withAlpha(100),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 52),
            ),
            const SizedBox(height: 28),
            const Text(
              'AppShield',
              style: TextStyle(
                color:         Colors.white,
                fontSize:      32,
                fontWeight:    FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Professional License Management',
              style: TextStyle(
                color:    Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  color:           Color(0xFF3B82F6),
                  backgroundColor: Color(0xFF1E293B),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Verifying license…',
              style: TextStyle(
                color:    Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SHELL  (sidebar + content)
// ─────────────────────────────────────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode    themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,            label: 'Dashboard'),
    _NavItem(icon: Icons.extension_outlined,       activeIcon: Icons.extension,            label: 'Features'),
    _NavItem(icon: Icons.bar_chart_outlined,       activeIcon: Icons.bar_chart,            label: 'Analytics'),
    _NavItem(icon: Icons.tune_outlined,            activeIcon: Icons.tune,                 label: 'Advanced'),
    _NavItem(icon: Icons.history_outlined,         activeIcon: Icons.history,              label: 'Activity'),
    _NavItem(icon: Icons.file_download_outlined,   activeIcon: Icons.file_download,        label: 'Export'),
    _NavItem(icon: Icons.settings_outlined,        activeIcon: Icons.settings,             label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final pages  = _buildPages();

    return AppShieldKeyboardShortcuts(
      showHelpOnF1: true,
      shortcuts: [
        const AppShieldShortcut(
          keys: ['F1'], description: 'Show this help', category: 'General'),
        const AppShieldShortcut(
          keys: ['Ctrl', 'Shift', 'A'],
          description: 'Open Activation dialog',
          category: 'License'),
        const AppShieldShortcut(
          keys: ['Ctrl', 'R'],
          description: 'Validate license online',
          category: 'License'),
        const AppShieldShortcut(
          keys: ['Ctrl', 'E'],
          description: 'Export license report',
          category: 'Tools'),
        const AppShieldShortcut(
          keys: ['Ctrl', 'D'],
          description: 'Open Developer Tools',
          category: 'Tools'),
        const AppShieldShortcut(
          keys: ['Ctrl', '1'],  description: 'Go to Dashboard',     category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '2'],  description: 'Go to Features',      category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '3'],  description: 'Go to Analytics',     category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '4'],  description: 'Go to Advanced',      category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '5'],  description: 'Go to Activity Log',  category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '6'],  description: 'Go to Export',        category: 'Navigation'),
        const AppShieldShortcut(
          keys: ['Ctrl', '7'],  description: 'Go to Settings',      category: 'Navigation'),
      ],
      child: Scaffold(
      key:  _scaffoldKey,
      body: Row(
        children: [
          // ── Sidebar (desktop layout) ───────────────────────────────────
          if (isWide)
            AppSidebar(
              selectedIndex:  _selectedIndex,
              items:          _navItems.map((e) => SidebarItem(
                icon:       e.icon,
                activeIcon: e.activeIcon,
                label:      e.label,
              )).toList(),
              onItemSelected: (i) => setState(() => _selectedIndex = i),
              themeMode:      widget.themeMode,
              onToggleTheme:  widget.onToggleTheme,
            ),

          // ── Main content ───────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                AppTitleBar(
                  title:         _navItems[_selectedIndex].label,
                  themeMode:     widget.themeMode,
                  onToggleTheme: widget.onToggleTheme,
                  showMenu:      !isWide,
                  onMenuTap:     () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(
                  child: IndexedStack(
                    index:    _selectedIndex,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // ── Drawer for narrow layout ───────────────────────────────────────
      drawer: isWide
          ? null
          : Drawer(
              child: AppSidebar(
                selectedIndex:  _selectedIndex,
                items:          _navItems.map((e) => SidebarItem(
                  icon:       e.icon,
                  activeIcon: e.activeIcon,
                  label:      e.label,
                )).toList(),
                onItemSelected: (i) {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = i);
                },
                themeMode:     widget.themeMode,
                onToggleTheme: widget.onToggleTheme,
              ),
            ),
      ),   // end Scaffold
    );     // end AppShieldKeyboardShortcuts
  }

  List<Widget> _buildPages() => [
    const DashboardScreen(),
    const FeaturesScreen(),
    const AnalyticsScreen(),
    const AdvancedScreen(),
    const ActivityLogScreen(),
    const ExportScreen(),
    SettingsScreen(
      themeMode:     widget.themeMode,
      onToggleTheme: widget.onToggleTheme,
    ),
  ];

}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String   label;
}
