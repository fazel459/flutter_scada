// ignore_for_file: deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/enums.dart';
import 'dashboard_screen.dart';
import 'pages_screen_content.dart'; // ← محتوای PagesScreen بدون Scaffold
import 'tag_management_screen.dart';
import 'alarm_panel.dart';
import 'report_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    // بارگذاری اولیه
    // ref.read(pagesProvider.notifier).loadPages();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // آیتم‌های منو بر اساس نقش کاربر
    final menuItems = <_MenuItem>[
      _MenuItem(icon: Icons.dashboard, label: 'داشبورد', labelEn: 'Dashboard'),
      _MenuItem(icon: Icons.pages, label: 'صفحات', labelEn: 'Pages'),
      if (user.role.canDesign)
        _MenuItem(icon: Icons.label, label: 'تگ‌ها', labelEn: 'Tags'),
      _MenuItem(icon: Icons.notifications, label: 'هشدارها', labelEn: 'Alarms'),
      if (user.role.canDesign)
        _MenuItem(icon: Icons.analytics, label: 'گزارش‌ها', labelEn: 'Reports'),
      if (user.role.isAdmin)
        _MenuItem(icon: Icons.admin_panel_settings, label: 'مدیریت', labelEn: 'Admin'),
    ];

    return Scaffold(
      body: Row(
        children: [
          // ─── سایدبار ───
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isMobile
                ? 60
                : (_sidebarCollapsed ? 70 : 240),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                border: Border(
                  right: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: Column(
                children: [
                  // لوگو
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.settings,
                              color: Colors.white, size: 20),
                        ),
                        if (!_sidebarCollapsed && !isMobile) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'SCADA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // منو آیتم‌ها
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final isSelected = _selectedIndex == index;

                        return Tooltip(
                          message: (_sidebarCollapsed || isMobile)
                              ? item.labelEn
                              : '',
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF3B82F6).withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF3B82F6)
                                          .withOpacity(0.3))
                                  : null,
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                item.icon,
                                color: isSelected
                                    ? const Color(0xFF3B82F6)
                                    : Colors.white.withOpacity(0.6),
                                size: 22,
                              ),
                              title: (_sidebarCollapsed || isMobile)
                                  ? null
                                  : Text(
                                      item.labelEn,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                              onTap: () =>
                                  setState(() => _selectedIndex = index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Collapse button
                  if (!isMobile)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _sidebarCollapsed
                              ? Icons.chevron_right
                              : Icons.chevron_left,
                          color: Colors.white54,
                        ),
                        onPressed: () => setState(
                            () => _sidebarCollapsed = !_sidebarCollapsed),
                      ),
                    ),

                  // User info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF8B5CF6),
                          child: Text(
                            (user.displayName ?? user.username)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                        if (!_sidebarCollapsed && !isMobile) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? user.username,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user.role.label,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.white54, size: 18),
                            onPressed: () =>
                                ref.read(authProvider.notifier).logout(),
                            tooltip: 'Logout',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── محتوای اصلی ───
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: _buildContent(menuItems[_selectedIndex].labelEn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String page) {
    switch (page) {
      case 'Dashboard':
        return const DashboardScreen();

      case 'Pages':
        // ← محتوای PagesScreen (بدون Scaffold)
        return  const PagesScreenContent();

      case 'Tags':
        return const TagManagementScreen();

      case 'Alarms':
        return const AlarmPanel();

      case 'Reports':
        return const ReportScreen(pageId: '');

      case 'Admin':
        return _buildAdminContent();

      default:
        return const DashboardScreen();
    }
  }

  Widget _buildAdminContent() {
    return Consumer(
      builder: (context, ref, _) {
        final usersState = ref.watch(adminUsersProvider);

        if (usersState.users.isEmpty && !usersState.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(adminUsersProvider.notifier).loadUsers();
          });
        }

        if (usersState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('User Management',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: usersState.users.length,
                  itemBuilder: (ctx, i) {
                    final u = usersState.users[i];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(u.username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(u.username,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(u.email,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5))),
                        trailing: DropdownButton<UserRole>(
                          value: u.role,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: UserRole.values.map((r) {
                            return DropdownMenuItem(
                                value: r, child: Text(r.label));
                          }).toList(),
                          onChanged: (r) {
                            if (r != null) {
                              ref
                                  .read(adminUsersProvider.notifier)
                                  .updateUser(u.id, {'role': r.name});
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String labelEn;
  const _MenuItem(
      {required this.icon, required this.label, required this.labelEn});
}

