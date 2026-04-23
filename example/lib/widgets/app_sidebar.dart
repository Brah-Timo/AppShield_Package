// example/lib/widgets/app_sidebar.dart
//
// Sidebar navigation for the Windows desktop layout.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_shield/app_shield.dart';

class SidebarItem {
  const SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String   label;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final int                   selectedIndex;
  final List<SidebarItem>     items;
  final ValueChanged<int>     onItemSelected;
  final ThemeMode             themeMode;
  final VoidCallback          onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final isDark    = theme.brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final selColor  = const Color(0xFF3B82F6);

    return Container(
      width: 220,
      color: bgColor,
      child: Column(
        children: [
          // ── Logo area ──────────────────────────────────────────────────
          _SidebarLogo(),
          const Divider(color: Colors.white12, height: 1),

          // ── License status mini card ───────────────────────────────────
          Consumer<AppShieldProvider>(
            builder: (_, shield, __) => shield.license != null &&
                    AppShield.isInitialized
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: LicenseSummaryWidget(
                      license: shield.license!,
                      theme: AppShield.instance.config.resolvedTheme,
                      compact: true,
                    ),
                  )
                : _LicenseStatusMini(
                    status: shield.status,
                    plan:   shield.currentPlan ?? 'Unknown',
                  ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),

          // ── Nav items ──────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item     = items[i];
                final selected = i == selectedIndex;
                return _NavTile(
                  icon:       selected ? item.activeIcon : item.icon,
                  label:      item.label,
                  selected:   selected,
                  selColor:   selColor,
                  onTap:      () => onItemSelected(i),
                );
              },
            ),
          ),

          // ── Footer ─────────────────────────────────────────────────────
          const Divider(color: Colors.white12, height: 1),
          _SidebarFooter(
            themeMode:     themeMode,
            onToggleTheme: onToggleTheme,
          ),
        ],
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Container(
            width:  36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AppShield',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'License Manager',
                style: TextStyle(
                  color:    Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── License status mini ───────────────────────────────────────────────────

class _LicenseStatusMini extends StatelessWidget {
  const _LicenseStatusMini({required this.status, required this.plan});
  final LicenseStatus status;
  final String        plan;

  @override
  Widget build(BuildContext context) {
    final color = AppShieldColors.forStatus(status.name);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width:  8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.name.replaceAllMapped(
                    RegExp(r'([A-Z])'),
                    (m) => ' ${m.group(0)}',
                  ).trim(),
                  style: TextStyle(
                    color:      color,
                    fontSize:   11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  plan.toUpperCase(),
                  style: const TextStyle(
                    color:    Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selColor,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final bool     selected;
  final Color    selColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? selColor.withAlpha(40)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor:   Colors.white.withAlpha(10),
          onTap:        onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selColor.withAlpha(80)),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? selColor : Colors.white54,
                    size:  18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color:      selected ? Colors.white : Colors.white70,
                    fontSize:   13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode    themeMode;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'v1.0.0',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          const Spacer(),
          IconButton(
            icon:    Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: Colors.white54,
              size:  18,
            ),
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: onToggleTheme,
          ),
        ],
      ),
    );
  }
}
