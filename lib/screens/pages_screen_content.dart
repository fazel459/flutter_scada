import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/models/enums.dart';
import 'package:flutter_scada/providers/providers.dart';
import 'package:flutter_scada/screens/workspace.dart';
import 'package:flutter_scada/utils/constants.dart';


import '../models/user_model.dart';
import '../models/page_model.dart';

class PagesScreenContent extends ConsumerStatefulWidget {
  const PagesScreenContent({super.key});

  @override
  ConsumerState<PagesScreenContent> createState() => _PagesScreenContentState();
}

class _PagesScreenContentState extends ConsumerState<PagesScreenContent> {

  @override
  void initState() {
    super.initState();
    // ✅ خودش بارگذاری را شروع می‌کند
    Future.microtask(() {
      ref.read(pagesProvider.notifier).loadPages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final pagesState = ref.watch(pagesProvider);
    final user = authState.user!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('📄', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text('Your Pages',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),

              // ✅ دکمه Refresh
              IconButton(
                onPressed: () {
                  ref.read(pagesProvider.notifier).loadPages();
                },
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),

              if (user.role.canDesign)
                ElevatedButton.icon(
                  onPressed: () => _createPage(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Page'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ✅ سه حالت: loading / error / content
          Expanded(
            child: _buildBody(pagesState, user),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(PagesState pagesState, User user) {
    // ── حالت لود ──
    if (pagesState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading pages...', 
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // ── حالت خطا ──
    if (pagesState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${pagesState.error}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(pagesProvider.notifier).loadPages();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue),
            ),
          ],
        ),
      );
    }

    // ── حالت خالی ──
    if (pagesState.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, size: 64,
                color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('No pages yet',
                style: TextStyle(fontSize: 18, color: Colors.white54)),
            if (user.role.canDesign) ...[
              const SizedBox(height: 8),
              const Text('Create your first SCADA page',
                  style: TextStyle(color: Colors.white30)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _createPage(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Page'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue),
              ),
            ],
          ],
        ),
      );
    }

    // ── حالت عادی — Grid ──
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 500
                    ? 2
                    : 1;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
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
        );
      },
    );
  }

  void _openPage(BuildContext context, WidgetRef ref, String id) async {
    // ✅ نمایش لودینگ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(currentPageProvider.notifier).loadPage(id);
      if (context.mounted) {
        Navigator.pop(context); // بستن لودینگ
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // بستن لودینگ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load page: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _createPage(BuildContext context, WidgetRef ref) async {
    try {
      final id = await ref.read(pagesProvider.notifier).createPage('New SCADA Page');
      await ref.read(currentPageProvider.notifier).loadPage(id);
      ref.read(designModeProvider.notifier).state = true;
      if (context.mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create page: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deletePage(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Page', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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

// ═════════════════════════════════════════════════════════════════════
// _PageCard — کارت صفحه
// ═════════════════════════════════════════════════════════════════════

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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: const Center(
                        child: Icon(Icons.bar_chart,
                            size: 48, color: Colors.white30),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(page.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (page.description.isNotEmpty)
                          Text(page.description,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
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
                    icon: const Icon(Icons.delete,
                        color: Colors.red, size: 18),
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
