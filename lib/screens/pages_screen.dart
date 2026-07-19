// ignore_for_file: deprecated_member_use, unused_import

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/enums.dart';
import '../models/page_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'workspace.dart';

class PagesScreen extends ConsumerWidget {
  const PagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final pagesState = ref.watch(pagesProvider);
    final user = authState.user!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1A1A2E)],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.blue, size: 28),
                  const SizedBox(width: 12),
                  const Text('SCADA Dashboard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                  Text('👤 ${user.displayName ?? user.username} (${user.role.label})',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(width: 16),
                  if (user.role.isAdmin)
                    ElevatedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => const AdminDialog()),
                      icon: const Icon(Icons.admin_panel_settings, size: 16),
                      label: const Text('Admin'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Your Pages',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        if (user.role.canDesign)
                          ElevatedButton.icon(
                            onPressed: () => _createPage(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('New Page'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: pagesState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : pagesState.pages.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.dashboard, size: 64, color: Colors.white30),
                                      const SizedBox(height: 16),
                                      const Text('No pages yet',
                                          style: TextStyle(fontSize: 18, color: Colors.white54)),
                                      if (user.role.canDesign)
                                        const Text('Create your first SCADA page to get started',
                                            style: TextStyle(color: Colors.white30)),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: pagesState.pages.length,
                                  itemBuilder: (context, index) {
                                    final page = pagesState.pages[index];
                                    return _PageCard(
                                      page: page,
                                      onTap: () => _openPage(context, ref, page.id),
                                      onDelete: user.role.isAdmin
                                          ? () => _deletePage(context, ref, page.id)
                                          : null,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(BuildContext context, WidgetRef ref, String id) async {
    await ref.read(currentPageProvider.notifier).loadPage(id);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
    }
  }

  void _createPage(BuildContext context, WidgetRef ref) async {
    final id = await ref.read(pagesProvider.notifier).createPage('New SCADA Page');
    await ref.read(currentPageProvider.notifier).loadPage(id);
    ref.read(designModeProvider.notifier).state = true;
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
    }
  }

  void _deletePage(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('Are you sure you want to delete this page?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(pagesProvider.notifier).deletePage(id);
    }
  }
}

class _PageCard extends StatelessWidget {
  final PageSummary page;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PageCard({required this.page, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorFromHex(page.backgroundColor),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Icon(Icons.bar_chart, size: 48, color: Colors.white30),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(page.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (page.description.isNotEmpty)
                          Text(page.description,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              if (onDelete != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: onDelete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDialog extends StatelessWidget {
  const AdminDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Consumer(
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
            return ListView.builder(
              itemCount: usersState.users.length,
              itemBuilder: (ctx, i) {
                final u = usersState.users[i];
                return ListTile(
                  title: Text(u.username, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(u.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<UserRole>(
                        value: u.role,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        items: UserRole.values.map((r) {
                          return DropdownMenuItem(value: r, child: Text(r.label));
                        }).toList(),
                        onChanged: (r) {
                          if (r != null) {
                            ref.read(adminUsersProvider.notifier).updateUser(u.id, {'role': r.name});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          u.role == UserRole.viewer ? Icons.block : Icons.check_circle,
                          color: u.role == UserRole.viewer ? Colors.red : Colors.green,
                        ),
                        onPressed: () {
                          ref.read(adminUsersProvider.notifier).updateUser(
                            u.id,
                            {'isActive': !(u.role != UserRole.viewer)},
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

