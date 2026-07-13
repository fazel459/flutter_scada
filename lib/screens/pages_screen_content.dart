import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/models/enums.dart';
import 'package:flutter_scada/models/page_model.dart';
import 'package:flutter_scada/providers/providers.dart';
import 'package:flutter_scada/screens/workspace.dart';
import 'package:flutter_scada/utils/constants.dart';

class PagesScreenContent extends ConsumerWidget {
  const PagesScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          // Grid
          Expanded(
            child: pagesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : pagesState.pages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dashboard,
                                size: 64,
                                color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text('No pages yet',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white54)),
                            if (user.role.canDesign)
                              const Text(
                                'Create your first SCADA page',
                                style: TextStyle(color: Colors.white30),
                              ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth > 1200
                              ? 4
                              : constraints.maxWidth > 800
                                  ? 3
                                  : constraints.maxWidth > 500
                                      ? 2
                                      : 1;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
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
                                onTap: () =>
                                    _openPage(context, ref, page.id),
                                onDelete: user.role.isAdmin
                                    ? () => _deletePage(
                                        context, ref, page.id)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openPage(BuildContext context, WidgetRef ref, String id) async {
    await ref.read(currentPageProvider.notifier).loadPage(id);
    if (context.mounted) {
      // ✅ push نه pushReplacement — بک کار کند
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
    }
  }

  void _createPage(BuildContext context, WidgetRef ref) async {
    final id =
        await ref.read(pagesProvider.notifier).createPage('New SCADA Page');
    await ref.read(currentPageProvider.notifier).loadPage(id);
    ref.read(designModeProvider.notifier).state = true;
    if (context.mounted) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ScadaWorkspace()));
    }
  }

  void _deletePage(
      BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
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
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
