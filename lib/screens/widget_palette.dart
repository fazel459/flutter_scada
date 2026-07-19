import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/widget_model.dart';
import '../models/template_model.dart';
import '../providers/providers.dart';

class WidgetPalette extends ConsumerWidget {
  const WidgetPalette({super.key});

  static const Map<String, List<WidgetType>> categories = {
    'Indicators': [
      WidgetType.gauge, WidgetType.level, WidgetType.temperature,
      WidgetType.pressure, WidgetType.digitalDisplay, WidgetType.textDisplay,
    ],
    'Controls': [
      WidgetType.switchWidget, WidgetType.slider, WidgetType.relay,
      WidgetType.led, WidgetType.ledDual, WidgetType.statusIndicator,
    ],
    'Vessels': [
      WidgetType.verticalTank, WidgetType.horizontalTank, WidgetType.fan, WidgetType.motor,
    ],
    'Valves': [WidgetType.gateValve, WidgetType.controlValve],
    'Charts': [
      WidgetType.graph, WidgetType.chart, WidgetType.verticalBar, WidgetType.horizontalBar,
    ],
    'Graphics': [
      WidgetType.staticLabel, WidgetType.staticImage, WidgetType.staticShape,
      WidgetType.staticPipe, WidgetType.staticPanel, WidgetType.staticIcon,
      WidgetType.staticLine, WidgetType.staticArrow,
    ],
    'Calculated': [
      WidgetType.calculated,
    ],
    'Advanced': [
      WidgetType.trendChart,
      WidgetType.spcChart,
      WidgetType.animatedPath,
      WidgetType.dataTable,
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedPaletteTypeProvider);
    final templates = ref.watch(templateProvider);
    final multiSelectMode = ref.watch(multiSelectModeProvider);
    final multiSelectedIds = ref.watch(multiSelectedIdsProvider);

    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.widgets, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Widgets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        multiSelectMode
                            ? '${multiSelectedIds.length} selected'
                            : 'Tap to select, tap canvas to place',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                      ),
                    ),
                    // دکمه Multi-Select
                    GestureDetector(
                      onTap: () {
                        final current = ref.read(multiSelectModeProvider);
                        ref.read(multiSelectModeProvider.notifier).state = !current;
                        if (current) ref.read(multiSelectedIdsProvider.notifier).state = {};
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: multiSelectMode ? Colors.orange.withValues(alpha: 0.3) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: multiSelectMode ? Colors.orange : const Color(0xFF475569),
                          ),
                        ),
                        child: Text(
                          multiSelectMode ? '✓ Select' : '☐ Multi',
                          style: TextStyle(
                            color: multiSelectMode ? Colors.orange : const Color(0xFF94A3B8),
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // نوار انتخاب
          if (selectedType != null && !multiSelectMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, color: Colors.blue, size: 12),
                  const SizedBox(width: 4),
                  Expanded(child: Text(selectedType.label, style: const TextStyle(color: Colors.blue, fontSize: 11))),
                  GestureDetector(
                    onTap: () => ref.read(selectedPaletteTypeProvider.notifier).state = null,
                    child: const Icon(Icons.close, color: Colors.blue, size: 14),
                  ),
                ],
              ),
            ),

          // دکمه ساخت تمپلت (وقتی multi-select فعال و حداقل 2 ویجت انتخاب شده)
          if (multiSelectMode && multiSelectedIds.length >= 2)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateTemplateDialog(context, ref),
                icon: const Icon(Icons.save_alt, size: 14),
                label: Text('Save as Template (${multiSelectedIds.length})', style: const TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(double.infinity, 32),
                ),
              ),
            ),

          // لیست ویجت‌ها و تمپلت‌ها
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(6),
              children: [
                // دسته‌بندی ویجت‌های استاندارد
                ...categories.entries.map((entry) => _buildCategory(entry.key, entry.value, ref, selectedType)),

                // تمپلت‌ها
                if (templates.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        const Text('MY TEMPLATES',
                            style: TextStyle(color: Color(0xFFEAB308), fontSize: 10, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${templates.length}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                      ],
                    ),
                  ),
                  ...templates.map((tpl) => _buildTemplateItem(tpl, ref, context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String name, List<WidgetType> types, WidgetRef ref, WidgetType? selectedType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(name.toUpperCase(),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1.2,
          ),
          itemCount: types.length,
          itemBuilder: (ctx, i) {
            final type = types[i];
            final isSelected = selectedType == type;
            return Draggable<WidgetType>(
              data: type,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 80, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
                  ),
                  child: Center(child: Text(type.icon, style: const TextStyle(fontSize: 18))),
                ),
              ),
              child: _PaletteItem(
                type: type, isSelected: isSelected,
                onTap: () {
                  if (isSelected) {
                    ref.read(selectedPaletteTypeProvider.notifier).state = null;
                  } else {
                    ref.read(selectedPaletteTypeProvider.notifier).state = type;
                  }
                },
              ),
            );
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildTemplateItem(WidgetTemplate tpl, WidgetRef ref, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () {
          // انتخاب تمپلت برای قرار دادن
          ref.read(selectedPaletteTypeProvider.notifier).state = null;
          // از طریق یک provider ویژه تمپلت انتخاب شده را مدیریت می‌کنیم
          _placeTemplate(ref, tpl);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(tpl.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tpl.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                    Text('${tpl.widgets.length} widgets',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                  ],
                ),
              ),
              // دکمه حذف
              GestureDetector(
                onTap: () => _deleteTemplate(context, ref, tpl),
                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _placeTemplate(WidgetRef ref, WidgetTemplate tpl) {
    final page = ref.read(currentPageProvider);
    if (page == null) return;

    // ویجت‌های تمپلت را با ID جدید و مختصات مرکز صفحه کپی کن
    const baseX = 100.0;
    const baseY = 100.0;

    for (final w in tpl.widgets) {
      final newWidget = w.copyWith(
        x: baseX + w.x,
        y: baseY + w.y,
      );
      // ID جدید تولید
      final copied = ScadaWidget(
        id: 'w-${DateTime.now().millisecondsSinceEpoch}-${w.id.hashCode.abs()}',
        type: newWidget.type,
        label: newWidget.label,
        x: newWidget.x,
        y: newWidget.y,
        width: newWidget.width,
        height: newWidget.height,
        zero: newWidget.zero,
        span: newWidget.span,
        offset: newWidget.offset,
        multiplier: newWidget.multiplier,
        unit: newWidget.unit,
        primaryColor: newWidget.primaryColor,
        secondaryColor: newWidget.secondaryColor,
        backgroundColor: newWidget.backgroundColor,
        textColor: newWidget.textColor,
        activeColor: newWidget.activeColor,
        inactiveColor: newWidget.inactiveColor,
        bgOpacity: newWidget.bgOpacity,
        bgTransparent: newWidget.bgTransparent,
        frameless: newWidget.frameless,
      );
      ref.read(currentPageProvider.notifier).addWidget(copied);
    }
  }

  void _showCreateTemplateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = '📦';
    final icons = ['📦', '🔧', '⚙️', '🏭', '📊', '🎛️', '💡', '🔌', '🛢️', '🌡️', '⚡', '🔥'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Create Template', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Template Name',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Icon', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: icons.map((ic) => GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = ic),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: selectedIcon == ic ? Colors.blue.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: selectedIcon == ic ? Colors.blue : Colors.transparent, width: 2),
                      ),
                      child: Center(child: Text(ic, style: const TextStyle(fontSize: 18))),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  '${ref.read(multiSelectedIdsProvider).length} widgets will be included',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                _createTemplate(ref, nameController.text.trim(), descController.text.trim(), selectedIcon);
                ref.read(multiSelectModeProvider.notifier).state = false;
                ref.read(multiSelectedIdsProvider.notifier).state = {};
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _createTemplate(WidgetRef ref, String name, String description, String icon) {
    final page = ref.read(currentPageProvider);
    final selectedIds = ref.read(multiSelectedIdsProvider);
    if (page == null || selectedIds.isEmpty) return;

    final selectedWidgets = page.widgets.where((w) => selectedIds.contains(w.id)).toList();
    if (selectedWidgets.isEmpty) return;

    // مختصات نسبی محاسبه - کمترین x و y به عنوان مبدا
    final minX = selectedWidgets.map((w) => w.x).reduce((a, b) => a < b ? a : b);
    final minY = selectedWidgets.map((w) => w.y).reduce((a, b) => a < b ? a : b);
    final maxX = selectedWidgets.map((w) => w.x + w.width).reduce((a, b) => a > b ? a : b);
    final maxY = selectedWidgets.map((w) => w.y + w.height).reduce((a, b) => a > b ? a : b);

    // ویجت‌ها با مختصات نسبی
    final relativeWidgets = selectedWidgets.map((w) => w.copyWith(
      x: w.x - minX,
      y: w.y - minY,
    )).toList();

    final template = WidgetTemplate(
      id: 'tpl-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description.isEmpty ? null : description,
      icon: icon,
      createdBy: ref.read(authProvider).user?.id ?? '',
      createdAt: DateTime.now(),
      width: maxX - minX,
      height: maxY - minY,
      widgets: relativeWidgets,
    );

    ref.read(templateProvider.notifier).addTemplate(template);
  }

  void _deleteTemplate(BuildContext context, WidgetRef ref, WidgetTemplate tpl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Template', style: TextStyle(color: Colors.white)),
        content: Text('Delete "${tpl.name}"?', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(templateProvider.notifier).removeTemplate(tpl.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem extends StatefulWidget {
  final WidgetType type;
  final bool isSelected;
  final VoidCallback onTap;
  const _PaletteItem({required this.type, required this.isSelected, required this.onTap});

  @override
  State<_PaletteItem> createState() => _PaletteItemState();
}

class _PaletteItemState extends State<_PaletteItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.blue.withValues(alpha: 0.25)
                : _hover ? Colors.blue.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? Colors.blue : _hover ? Colors.blue.withValues(alpha: 0.4) : Colors.transparent,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.type.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(widget.type.label,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.blue : Colors.white70,
                    fontSize: 8, fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  ), textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

