import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/enums.dart';
import '../models/widget_model.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../services/formula_engine.dart';

class PropertyPanel extends ConsumerStatefulWidget {
  const PropertyPanel({super.key});

  @override
  ConsumerState<PropertyPanel> createState() => _PropertyPanelState();
}

class _PropertyPanelState extends ConsumerState<PropertyPanel> {
  int _tabIndex = 0;
  final List<String> _tabs = ['General', 'Data', 'Alarm', 'Style'];

  @override
  Widget build(BuildContext context) {
    final widget = ref.watch(selectedWidgetProvider);
    if (widget == null) {
      return Container(
        width: 288,
        color: const Color(0xFF1E293B),
        child: const Center(
          child: Text('Select a widget\nto edit properties',
              style: TextStyle(color: Color(0xFF64748B)), textAlign: TextAlign.center),
        ),
      );
    }

    return Container(
      width: 240,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Text(widget.type.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.type.label} - ${widget.label}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => ref.read(selectedWidgetIdProvider.notifier).state = null,
                  child: const Icon(Icons.close, color: Colors.white54, size: 16),
                ),
              ],
            ),
          ),
          // Tabs (compact)
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF334155)))),
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final label = entry.value;
                final active = _tabIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: active ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(label,
                          style: TextStyle(
                            color: active ? Colors.blue : Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Content with scroll
          Flexible(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.all(10),
                shrinkWrap: true,
                children: [
                  if (_tabIndex == 0) ..._buildGeneralTab(widget),
                  if (_tabIndex == 1) ..._buildDataTab(widget),
                  if (_tabIndex == 2) ..._buildAlarmTab(widget),
                  if (_tabIndex == 3) ..._buildStyleTab(widget),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        const SizedBox(height: 2),
        child,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _textField(String label, String value, Function(String) onChanged) {
    return _field(
      label,
      SizedBox(
        height: 32,
        child: TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(String label, double value, Function(double) onChanged) {
    return _textField(label, value.toString(), (v) => onChanged(double.tryParse(v) ?? value));
  }

  Widget _boolField(String label, bool value, Function(bool) onChanged) {
    return _field(
      label,
      GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: value ? Colors.green : const Color(0xFF475569),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value ? 'Enabled' : 'Disabled',
              style: TextStyle(color: value ? Colors.white : Colors.white70, fontSize: 11)),
        ),
      ),
    );
  }

  Widget _colorField(String label, String hex, Function(String) onChanged) {
    return _field(
      label,
      GestureDetector(
        onTap: () => _showColorPicker(hex, onChanged),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: colorFromHex(hex),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24),
          ),
          child: Center(
            child: Text(colorToHex(colorFromHex(hex)),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(String current, Function(String) onChanged) {
    final colors = [
      '#EF4444', '#F97316', '#F59E0B', '#EAB308', '#84CC16',
      '#22C55E', '#10B981', '#14B8A6', '#06B6D4', '#3B82F6',
      '#6366F1', '#8B5CF6', '#A855F7', '#EC4899', '#F43F5E',
      '#64748B', '#475569', '#334155', '#1E293B', '#FFFFFF',
      '#000000',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Select Color', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((hex) {
              final isSelected = colorToHex(colorFromHex(hex)).toLowerCase() ==
                  colorToHex(colorFromHex(current)).toLowerCase();
              return GestureDetector(
                onTap: () {
                  onChanged(hex);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorFromHex(hex),
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : Border.all(color: Colors.white24),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ========== TABS ==========
  List<Widget> _buildGeneralTab(ScadaWidget w) {
    final isStatic = !w.type.isDataWidget;
    return [
      _textField('Label', w.label, (v) => _update(w.copyWith(label: v))),
      Row(
        children: [
          Expanded(child: _numberField('X', w.x, (v) => _update(w.copyWith(x: v)))),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Y', w.y, (v) => _update(w.copyWith(y: v)))),
        ],
      ),
      Row(
        children: [
          Expanded(child: _numberField('Width', w.width, (v) => _update(w.copyWith(width: v)))),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Height', w.height, (v) => _update(w.copyWith(height: v)))),
        ],
      ),
      _numberField('Rotation', w.staticRotation, (v) => _update(w.copyWith(staticRotation: v))),

      // ====== فیلدهای مخصوص ویجت‌های گرافیکی ======
      if (w.type == WidgetType.staticLabel) ...[
        _textField('Text', w.staticText, (v) => _update(w.copyWith(staticText: v))),
        _numberField('Font Size', w.staticFontSize, (v) => _update(w.copyWith(staticFontSize: v))),
        _colorField('Font Color', w.staticFontColor, (v) => _update(w.copyWith(staticFontColor: v))),
        _boolField('Bold', w.staticBold, (v) => _update(w.copyWith(staticBold: v))),
      ],
      if (w.type == WidgetType.staticImage) ...[
        _textField('Image URL', w.staticImageUrl, (v) => _update(w.copyWith(staticImageUrl: v))),
      ],
      if (w.type == WidgetType.staticShape) ...[
        _field('Shape', DropdownButtonFormField<String>(
          initialValue: w.staticShapeType,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem(value: 'rectangle', child: Text('Rectangle')),
            DropdownMenuItem(value: 'circle', child: Text('Circle')),
            DropdownMenuItem(value: 'ellipse', child: Text('Ellipse')),
            DropdownMenuItem(value: 'diamond', child: Text('Diamond')),
          ],
          onChanged: (v) => _update(w.copyWith(staticShapeType: v ?? 'rectangle')),
        )),
        _colorField('Fill Color', w.staticShapeColor, (v) => _update(w.copyWith(staticShapeColor: v))),
        _boolField('Filled', w.staticFilled, (v) => _update(w.copyWith(staticFilled: v))),
        _numberField('Border Width', w.staticShapeBorder, (v) => _update(w.copyWith(staticShapeBorder: v))),
        _colorField('Border Color', w.staticBorderColor, (v) => _update(w.copyWith(staticBorderColor: v))),
      ],
      if (w.type == WidgetType.staticPipe) ...[
        _field('Direction', DropdownButtonFormField<String>(
          initialValue: w.staticPipeDirection,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem(value: 'horizontal', child: Text('Horizontal ─')),
            DropdownMenuItem(value: 'vertical', child: Text('Vertical │')),
            DropdownMenuItem(value: 'elbow_right', child: Text('Elbow ┘')),
            DropdownMenuItem(value: 'elbow_left', child: Text('Elbow └')),
            DropdownMenuItem(value: 'tee_right', child: Text('Tee ┤')),
            DropdownMenuItem(value: 'tee_down', child: Text('Tee ┴')),
            DropdownMenuItem(value: 'cross', child: Text('Cross ┼')),
          ],
          onChanged: (v) => _update(w.copyWith(staticPipeDirection: v ?? 'horizontal')),
        )),
        _colorField('Pipe Color', w.staticPipeColor, (v) => _update(w.copyWith(staticPipeColor: v))),
        _numberField('Pipe Width', w.staticPipeWidth, (v) => _update(w.copyWith(staticPipeWidth: v))),
      ],
      if (w.type == WidgetType.staticPanel) ...[
        _textField('Title', w.staticPanelTitle, (v) => _update(w.copyWith(staticPanelTitle: v))),
        _colorField('Title Color', w.staticShapeColor, (v) => _update(w.copyWith(staticShapeColor: v))),
        _colorField('Border Color', w.staticBorderColor, (v) => _update(w.copyWith(staticBorderColor: v))),
      ],
      if (w.type == WidgetType.staticIcon) ...[
        _field('Icon', DropdownButtonFormField<String>(
          initialValue: w.staticIconName,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem(value: 'star', child: Text('⭐ Star')),
            DropdownMenuItem(value: 'warning', child: Text('⚠️ Warning')),
            DropdownMenuItem(value: 'fire', child: Text('🔥 Fire')),
            DropdownMenuItem(value: 'water', child: Text('💧 Water')),
            DropdownMenuItem(value: 'bolt', child: Text('⚡ Bolt')),
            DropdownMenuItem(value: 'gear', child: Text('⚙️ Gear')),
            DropdownMenuItem(value: 'tank', child: Text('🛢️ Tank')),
            DropdownMenuItem(value: 'pump', child: Text('💨 Pump')),
            DropdownMenuItem(value: 'alert', child: Text('🚨 Alert')),
            DropdownMenuItem(value: 'power', child: Text('🔋 Power')),
            DropdownMenuItem(value: 'factory', child: Text('🏭 Factory')),
            DropdownMenuItem(value: 'nuclear', child: Text('☢️ Nuclear')),
          ],
          onChanged: (v) => _update(w.copyWith(staticIconName: v ?? 'star')),
        )),
      ],
      if (w.type == WidgetType.staticLine) ...[
        _colorField('Line Color', w.staticShapeColor, (v) => _update(w.copyWith(staticShapeColor: v))),
        _numberField('Thickness', w.staticShapeBorder, (v) => _update(w.copyWith(staticShapeBorder: v))),
      ],
      if (w.type == WidgetType.staticArrow) ...[
        _field('Direction', DropdownButtonFormField<String>(
          initialValue: w.staticArrowDir,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem(value: 'right', child: Text('→ Right')),
            DropdownMenuItem(value: 'left', child: Text('← Left')),
            DropdownMenuItem(value: 'up', child: Text('↑ Up')),
            DropdownMenuItem(value: 'down', child: Text('↓ Down')),
          ],
          onChanged: (v) => _update(w.copyWith(staticArrowDir: v ?? 'right')),
        )),
        _colorField('Arrow Color', w.staticShapeColor, (v) => _update(w.copyWith(staticShapeColor: v))),
      ],

      // ====== فیلدهای Data Table ======
      if (w.type == WidgetType.dataTable) ...[
        Row(children: [
          Expanded(child: _numberField('Rows', w.tableRows.toDouble(), (v) {
            final newRows = v.toInt().clamp(1, 20);
            _update(w.copyWith(tableRows: newRows));
          })),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Cols', w.tableCols.toDouble(), (v) {
            final newCols = v.toInt().clamp(1, 10);
            _update(w.copyWith(tableCols: newCols));
          })),
        ]),
        _boolField('Show Header', w.tableShowHeader, (v) => _update(w.copyWith(tableShowHeader: v))),
        _boolField('Alarm Cell Coloring', w.tableAlarmColoring, (v) => _update(w.copyWith(tableAlarmColoring: v))),
        _boolField('Show Quality Icon', w.tableShowQualityIcon, (v) => _update(w.copyWith(tableShowQualityIcon: v))),
        _colorField('Header Color', w.tableHeaderColor, (v) => _update(w.copyWith(tableHeaderColor: v))),
        _colorField('Border Color', w.tableBorderColor, (v) => _update(w.copyWith(tableBorderColor: v))),
        const SizedBox(height: 8),
        _field('Cell Bindings', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tap cell to bind tag (${w.tableCells.length} bound)',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
            const SizedBox(height: 4),
            const SizedBox(height: 4),
            const Text('Tip: tap a bound cell again to change tag. Merge settings are edited per cell in the web preview.',
                style: TextStyle(color: Color(0xFF475569), fontSize: 8)),
            const SizedBox(height: 4),
            SizedBox(
              height: (w.tableRows * 28.0).clamp(56, 200),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: w.tableCols,
                  crossAxisSpacing: 2, mainAxisSpacing: 2,
                  childAspectRatio: 2.5,
                ),
                itemCount: w.tableRows * w.tableCols,
                itemBuilder: (ctx, idx) {
                  final r = idx ~/ w.tableCols;
                  final c = idx % w.tableCols;
                  final cell = w.tableCells.cast<Map<String, dynamic>?>().firstWhere(
                    (e) => e != null && e['row'] == r && e['col'] == c,
                    orElse: () => null,
                  );
                  final bound = cell != null && cell['tagId'] != null && cell['tagId'].toString().isNotEmpty;
                  return GestureDetector(
                    onTap: () => _showCellTagSelector(w, r, c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bound ? Colors.blue.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: bound ? Colors.blue.withValues(alpha: 0.4) : const Color(0xFF475569), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          bound ? (cell['tagName']?.toString() ?? '🏷️') : '[$r,$c]',
                          style: TextStyle(color: bound ? Colors.blue : const Color(0xFF64748B), fontSize: 7),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        )),
      ],

      // ====== فیلدهای Animated Path ======
      if (w.type == WidgetType.animatedPath) ...[
        _field('Direction', DropdownButtonFormField<String>(
          initialValue: w.pathDirection,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: const [
            DropdownMenuItem(value: 'horizontal', child: Text('→ Horizontal')),
            DropdownMenuItem(value: 'vertical', child: Text('↓ Vertical')),
            DropdownMenuItem(value: 'elbow_right', child: Text('↳ Elbow Right')),
            DropdownMenuItem(value: 'elbow_left', child: Text('↲ Elbow Left')),
            DropdownMenuItem(value: 'elbow_down', child: Text('↴ Elbow Down')),
            DropdownMenuItem(value: 'elbow_up', child: Text('↱ Elbow Up')),
            DropdownMenuItem(value: 'tee_right', child: Text('┤ Tee Right')),
            DropdownMenuItem(value: 'tee_down', child: Text('┴ Tee Down')),
            DropdownMenuItem(value: 'cross', child: Text('┼ Cross')),
          ],
          onChanged: (v) => _update(w.copyWith(pathDirection: v ?? 'horizontal')),
        )),
        _colorField('Flow Color', w.pathFlowColor, (v) => _update(w.copyWith(pathFlowColor: v))),
        _colorField('Pipe Color', w.staticPipeColor, (v) => _update(w.copyWith(staticPipeColor: v))),
        _numberField('Pipe Width', w.pathWidth, (v) => _update(w.copyWith(pathWidth: v))),
        _numberField('Speed', w.pathSpeed, (v) => _update(w.copyWith(pathSpeed: v))),
        _numberField('Lanes', w.pathLanes.toDouble(), (v) => _update(w.copyWith(pathLanes: v.toInt().clamp(1, 6)))),
        _textField('Display Text', w.pathDisplayText, (v) => _update(w.copyWith(pathDisplayText: v))),
        _boolField('Flowing', w.pathFlowing, (v) => _update(w.copyWith(pathFlowing: v))),
        _boolField('Reverse Flow', w.pathReverse, (v) => _update(w.copyWith(pathReverse: v))),
      ],

      // ====== فیلدهای SPC/Trend ======
      if (w.type == WidgetType.spcChart) ...[
        _numberField('UCL', w.spcUcl, (v) => _update(w.copyWith(spcUcl: v))),
        _numberField('LCL', w.spcLcl, (v) => _update(w.copyWith(spcLcl: v))),
        _numberField('Target (CL)', w.spcTarget, (v) => _update(w.copyWith(spcTarget: v))),
      ],
      if (w.type == WidgetType.trendChart || w.type == WidgetType.spcChart) ...[
        _numberField('History Points', w.trendPoints.toDouble(), (v) => _update(w.copyWith(trendPoints: v.toInt()))),
      ],

      // ====== فیلدهای مخصوص ویجت محاسباتی ======
      if (w.type == WidgetType.calculated) ...[
        _field('Formula', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 60,
              child: TextField(
                controller: TextEditingController(text: w.calcFormula),
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                onChanged: (v) => _update(w.copyWith(calcFormula: v)),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(6),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  hintText: '({TT-101} + {TT-102}) / 2',
                  hintStyle: TextStyle(color: Colors.purple.withValues(alpha: 0.3), fontSize: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF475569)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Validation
            Builder(builder: (ctx) {
              final validation = FormulaEngine.validate(w.calcFormula, w.calcInputTags);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: validation.valid ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(validation.valid ? Icons.check_circle : Icons.error,
                        size: 12, color: validation.valid ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Expanded(child: Text(
                      validation.valid ? 'Valid (test: ${validation.testResult?.toStringAsFixed(2)})' : validation.error ?? 'Error',
                      style: TextStyle(fontSize: 9, color: validation.valid ? Colors.green : Colors.red),
                    )),
                  ],
                ),
              );
            }),
          ],
        )),
        // Quick function buttons
        _field('Functions', Wrap(
          spacing: 3, runSpacing: 3,
          children: [
            ...['AVG', 'MIN', 'MAX', 'SUM', 'ABS', 'SQRT', 'IF', 'POW', 'ROUND'],
            if (w.calcIsDigital) ...['AND', 'OR', 'NOT', 'XOR', 'MAJORITY', 'COUNT_TRUE', 'LATCH', 'BOOL']
            else ...['AND', 'OR'],
          ].map((fn) =>
            GestureDetector(
              onTap: () {
                final newFormula = '${w.calcFormula}$fn()';
                _update(w.copyWith(calcFormula: newFormula));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Text(fn, style: const TextStyle(color: Colors.purple, fontSize: 9, fontFamily: 'monospace')),
              ),
            ),
          ).toList(),
        )),
        // نوع خروجی: آنالوگ یا دیجیتال
        _boolField('Digital Output (0/1)', w.calcIsDigital, (v) => _update(w.copyWith(calcIsDigital: v))),

        _field('Display As', DropdownButtonFormField<String>(
          value: w.calcDisplayAs,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: w.calcIsDigital ? const [
            DropdownMenuItem(value: 'led', child: Text('🔴 LED')),
            DropdownMenuItem(value: 'switch', child: Text('🔲 Switch')),
            DropdownMenuItem(value: 'status', child: Text('🚦 Status')),
          ] : const [
            DropdownMenuItem(value: 'digital', child: Text('🔢 Digital Display')),
            DropdownMenuItem(value: 'gauge', child: Text('🔘 Gauge')),
            DropdownMenuItem(value: 'bar', child: Text('📊 Bar')),
            DropdownMenuItem(value: 'text', child: Text('📝 Text')),
          ],
          onChanged: (v) => _update(w.copyWith(calcDisplayAs: v ?? (w.calcIsDigital ? 'led' : 'digital'))),
        )),

        // تنظیمات دیجیتال
        if (w.calcIsDigital) ...[
          _textField('True Label', w.calcTrueLabel, (v) => _update(w.copyWith(calcTrueLabel: v))),
          _textField('False Label', w.calcFalseLabel, (v) => _update(w.copyWith(calcFalseLabel: v))),
          _colorField('True Color', w.calcTrueColor, (v) => _update(w.copyWith(calcTrueColor: v))),
          _colorField('False Color', w.calcFalseColor, (v) => _update(w.copyWith(calcFalseColor: v))),
          _boolField('Blink on True', w.calcBlinkOnTrue, (v) => _update(w.copyWith(calcBlinkOnTrue: v))),
        ],

        _numberField('Refresh (ms)', w.calcRefreshMs.toDouble(), (v) => _update(w.copyWith(calcRefreshMs: v.toInt()))),
        // Used tags
        if (w.calcFormula.isNotEmpty)
          _field('Used Tags', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: FormulaEngine.extractTags(w.calcFormula).map((tag) =>
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('🏷️ $tag', style: const TextStyle(color: Colors.blue, fontSize: 10)),
              ),
            ).toList(),
          )),
      ],

      // ====== فیلدهای مخصوص ویجت‌های داده‌ای ======
      if (!isStatic) ...[
        _field('Unit', DropdownButtonFormField<String>(
          value: Constants.units.contains(w.unit) ? w.unit : '',
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: Constants.units.map((u) {
            return DropdownMenuItem(value: u, child: Text(u.isEmpty ? '(none)' : u));
          }).toList(),
          onChanged: (v) => _update(w.copyWith(unit: v ?? '')),
        )),
        Row(children: [
          Expanded(child: _numberField('Min', w.minValue, (v) => _update(w.copyWith(minValue: v)))),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Max', w.maxValue, (v) => _update(w.copyWith(maxValue: v)))),
        ]),
        Row(children: [
          Expanded(child: _numberField('Zero', w.zero, (v) => _update(w.copyWith(zero: v)))),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Span', w.span, (v) => _update(w.copyWith(span: v)))),
        ]),
        Row(children: [
          Expanded(child: _numberField('Offset', w.offset, (v) => _update(w.copyWith(offset: v)))),
          const SizedBox(width: 8),
          Expanded(child: _numberField('Multiplier', w.multiplier, (v) => _update(w.copyWith(multiplier: v)))),
        ]),
      ],
      if (w.states.isNotEmpty)
        _field('Current State', DropdownButtonFormField<String>(
          value: w.currentState ?? 'unknown',
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: _inputDecoration(),
          items: w.states.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value.label));
          }).toList(),
          onChanged: (v) => _update(w.copyWith(currentState: v)),
        )),
    ];
  }

  List<Widget> _buildDataTab(ScadaWidget w) {
    return [
      // ====== TAG BINDING بصری ======
      _field('Bind to Tag', GestureDetector(
        onTap: () => _showTagSelector(w),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: w.boundTagId != null ? Colors.blue.withOpacity(0.1) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: w.boundTagId != null ? Colors.blue.withOpacity(0.5) : const Color(0xFF475569)),
          ),
          child: Row(
            children: [
              Icon(Icons.label, size: 14, color: w.boundTagId != null ? Colors.blue : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                w.boundTagId ?? 'Select tag...',
                style: TextStyle(color: w.boundTagId != null ? Colors.blue : const Color(0xFF64748B), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )),
              if (w.boundTagId != null)
                GestureDetector(
                  onTap: () => _update(w.copyWith(boundTagId: '')),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
            ],
          ),
        ),
      )),

      // ====== PAGE LINK ======
      _field('Link to Page', GestureDetector(
        onTap: () => _showPageSelector(w),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: w.linkedPageId != null ? Colors.purple.withOpacity(0.1) : Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: w.linkedPageId != null ? Colors.purple.withOpacity(0.5) : const Color(0xFF475569)),
          ),
          child: Row(
            children: [
              Icon(Icons.link, size: 14, color: w.linkedPageId != null ? Colors.purple : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                w.linkedPageId != null ? '→ ${w.linkedPageId!.substring(0, 8)}...' : 'No link (tap to set)',
                style: TextStyle(color: w.linkedPageId != null ? Colors.purple : const Color(0xFF64748B), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )),
              if (w.linkedPageId != null)
                GestureDetector(
                  onTap: () => _update(w.copyWith(linkedPageId: '')),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
            ],
          ),
        ),
      )),

      const Divider(color: Color(0xFF334155), height: 20),

      _field(
        'Protocol',
        DropdownButtonFormField<ProtocolType>(
          value: w.dataSource.protocol,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDecoration(),
          items: ProtocolType.values.map((p) {
            return DropdownMenuItem(value: p, child: Text(p.label));
          }).toList(),
          onChanged: (p) => _update(w.copyWith(dataSource: w.dataSource.copyWith(protocol: p))),
        ),
      ),
      if (w.dataSource.protocol == ProtocolType.mqtt) ...[
        _textField('MQTT Broker', w.dataSource.mqttBroker ?? '', (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(mqttBroker: v)))),
        _textField('MQTT Topic', w.dataSource.mqttTopic ?? '', (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(mqttTopic: v)))),
        _numberField('MQTT Port', w.dataSource.mqttPort.toDouble(), (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(mqttPort: v.toInt())))),
      ],
      if (w.dataSource.protocol == ProtocolType.modbusTcp) ...[
        _textField('Modbus Host', w.dataSource.modbusHost ?? '', (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(modbusHost: v)))),
        _numberField('Modbus Port', w.dataSource.modbusPort.toDouble(), (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(modbusPort: v.toInt())))),
        _numberField('Unit ID', w.dataSource.modbusUnitId.toDouble(), (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(modbusUnitId: v.toInt())))),
        _numberField('Register', w.dataSource.modbusRegister.toDouble(), (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(modbusRegister: v.toInt())))),
        _field(
          'Register Type',
          DropdownButtonFormField<ModbusRegisterType>(
            value: w.dataSource.modbusRegisterType,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration(),
            items: ModbusRegisterType.values.map((t) {
              return DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()));
            }).toList(),
            onChanged: (t) => _update(w.copyWith(dataSource: w.dataSource.copyWith(modbusRegisterType: t))),
          ),
        ),
      ],
      _numberField('Poll Interval (ms)', w.dataSource.pollInterval.toDouble(), (v) => _update(w.copyWith(dataSource: w.dataSource.copyWith(pollInterval: v.toInt())))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: w.connectionStatus == ConnectionStatus.connected
                        ? Colors.green
                        : w.connectionStatus == ConnectionStatus.disconnected
                            ? Colors.red
                            : Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Text(w.connectionStatus.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            if (w.lastDataTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Last: ${w.lastDataTime!.toLocal().toString().substring(11, 19)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAlarmTab(ScadaWidget w) {
    return [
      _boolField('Alarms Enabled', w.alarm.enabled, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(enabled: v)))),
      if (w.alarm.enabled) ...[
        Row(
          children: [
            Expanded(child: _numberField('High', w.alarm.highThreshold, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(highThreshold: v))))),
            const SizedBox(width: 8),
            Expanded(child: _numberField('Low', w.alarm.lowThreshold, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(lowThreshold: v))))),
          ],
        ),
        Row(
          children: [
            Expanded(child: _numberField('HH', w.alarm.highHighThreshold, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(highHighThreshold: v))))),
            const SizedBox(width: 8),
            Expanded(child: _numberField('LL', w.alarm.lowLowThreshold, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(lowLowThreshold: v))))),
          ],
        ),
        _colorField('Normal Color', w.alarm.normalColor, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(normalColor: v)))),
        _colorField('Warning Color', w.alarm.warningColor, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(warningColor: v)))),
        _colorField('Alarm Color', w.alarm.alarmColor, (v) => _update(w.copyWith(alarm: w.alarm.copyWith(alarmColor: v)))),
      ],
    ];
  }

  List<Widget> _buildStyleTab(ScadaWidget w) {
    return [
      _boolField('Transparent BG', w.bgTransparent, (v) => _update(w.copyWith(bgTransparent: v))),
      _boolField('Frameless', w.frameless, (v) => _update(w.copyWith(frameless: v))),
      if (!w.bgTransparent) ...[
        _colorField('Background', w.backgroundColor, (v) => _update(w.copyWith(backgroundColor: v))),
        _field(
          'BG Opacity: ${(w.bgOpacity * 100).toInt()}%',
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.blue,
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: Colors.blue,
              overlayColor: Colors.blue.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: w.bgOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (v) => _update(w.copyWith(bgOpacity: v)),
            ),
          ),
        ),
      ],
      _colorField('Primary', w.primaryColor, (v) => _update(w.copyWith(primaryColor: v))),
      _colorField('Secondary', w.secondaryColor, (v) => _update(w.copyWith(secondaryColor: v))),
      _colorField('Text', w.textColor, (v) => _update(w.copyWith(textColor: v))),
      _colorField('Active', w.activeColor, (v) => _update(w.copyWith(activeColor: v))),
      _colorField('Inactive', w.inactiveColor, (v) => _update(w.copyWith(inactiveColor: v))),
      _boolField('Animated', w.animated, (v) => _update(w.copyWith(animated: v))),
    ];
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFF475569)),
      ),
    );
  }

  void _update(ScadaWidget updated) {
    ref.read(currentPageProvider.notifier).updateWidget(updated);
  }

  // ====== TAG SELECTOR DIALOG ======
  void _showTagSelector(ScadaWidget w) async {
    final api = ref.read(apiServiceProvider);
    List<Map<String, dynamic>> tags = [];
    try {
      final res = await api.get('/tags');
      tags = List<Map<String, dynamic>>.from(res['tags'] ?? []);
    } catch (_) {}

    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('🏷️ Select Tag', style: TextStyle(color: Colors.white, fontSize: 14)),
      content: SizedBox(
        width: 350, height: 400,
        child: tags.isEmpty
            ? const Center(child: Text('No tags found', style: TextStyle(color: Color(0xFF64748B))))
            : ListView.builder(
                itemCount: tags.length,
                itemBuilder: (_, i) {
                  final t = tags[i];
                  final selected = w.boundTagId == t['name'];
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: Colors.blue.withOpacity(0.1),
                    leading: Container(width: 8, height: 8, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (t['isActive'] == true) ? Colors.green : Colors.grey,
                    )),
                    title: Text(t['name'] ?? '', style: TextStyle(color: selected ? Colors.blue : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text('${t['group'] ?? ''} • ${t['protocol'] ?? ''} • ${t['unit'] ?? ''}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                    onTap: () {
                      _update(w.copyWith(
                        boundTagId: t['name'],
                        label: t['name'],
                        unit: t['unit'] ?? w.unit,
                      ));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ));
  }

  // ====== CELL TAG SELECTOR ======
  void _showCellTagSelector(ScadaWidget w, int row, int col) async {
    final api = ref.read(apiServiceProvider);
    List<Map<String, dynamic>> tags = [];
    try {
      final res = await api.get('/tags');
      tags = List<Map<String, dynamic>>.from(res['tags'] ?? []);
    } catch (_) {}

    final existing = w.tableCells.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e != null && e['row'] == row && e['col'] == col,
      orElse: () => null,
    );
    int rowSpan = ((existing?['rowSpan'] ?? 1) as num).toInt();
    int colSpan = ((existing?['colSpan'] ?? 1) as num).toInt();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('🏷️ Bind Cell [$row, $col]', style: const TextStyle(color: Colors.white, fontSize: 14)),
          content: SizedBox(
            width: 350,
            height: 430,
            child: Column(
              children: [
                // Merge controls
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Merge Cell', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Row Span', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                                DropdownButtonFormField<int>(
                                  value: rowSpan,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  decoration: _inputDecoration(),
                                  items: List.generate(4, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                                  onChanged: (v) => setDialogState(() => rowSpan = v ?? 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Col Span', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                                DropdownButtonFormField<int>(
                                  value: colSpan,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                  decoration: _inputDecoration(),
                                  items: List.generate(4, (i) => i + 1).map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
                                  onChanged: (v) => setDialogState(() => colSpan = v ?? 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Clear button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      final cells = List<Map<String, dynamic>>.from(w.tableCells);
                      cells.removeWhere((c) => c['row'] == row && c['col'] == col);
                      _update(w.copyWith(tableCells: cells));
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: const Center(child: Text('✕ Clear Binding', style: TextStyle(color: Colors.red, fontSize: 11))),
                    ),
                  ),
                ),

                // Tag list
                Expanded(
                  child: tags.isEmpty
                      ? const Center(child: Text('No tags', style: TextStyle(color: Color(0xFF64748B))))
                      : ListView.builder(
                          itemCount: tags.length,
                          itemBuilder: (_, i) {
                            final t = tags[i];
                            return ListTile(
                              dense: true,
                              leading: Container(width: 8, height: 8, decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (t['isActive'] == true) ? Colors.green : Colors.grey,
                              )),
                              title: Text(t['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: Text('${t['group'] ?? ''} • ${t['unit'] ?? ''}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                              onTap: () {
                                final cells = List<Map<String, dynamic>>.from(w.tableCells);
                                cells.removeWhere((c) => c['row'] == row && c['col'] == col);
                                cells.add({
                                  'row': row,
                                  'col': col,
                                  'rowSpan': rowSpan,
                                  'colSpan': colSpan,
                                  'tagId': t['name'],
                                  'tagName': t['name'],
                                  'tagDesc': t['description'] ?? '',
                                  'unit': t['unit'] ?? '',
                                  'value': t['lastValue'],
                                  'quality': t['quality'] ?? 'unknown',
                                  'alarmColor': t['alarmEnabled'] == true && t['lastValue'] != null
                                      ? (((t['lastValue'] as num).toDouble() > ((t['highAlarm'] ?? 999999) as num).toDouble()) ||
                                             ((t['lastValue'] as num).toDouble() < ((t['lowAlarm'] ?? -999999) as num).toDouble()))
                                          ? '#EF4444'
                                          : null
                                      : null,
                                });
                                _update(w.copyWith(tableCells: cells));
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  // ====== PAGE SELECTOR DIALOG ======
  void _showPageSelector(ScadaWidget w) async {
    final api = ref.read(apiServiceProvider);
    List<Map<String, dynamic>> pages = [];
    try {
      final res = await api.get('/pages');
      pages = (res['pages'] as List).map((p) => p as Map<String, dynamic>).toList();
    } catch (_) {}

    if (!mounted) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('📄 Link to Page', style: TextStyle(color: Colors.white, fontSize: 14)),
      content: SizedBox(
        width: 350, height: 300,
        child: pages.isEmpty
            ? const Center(child: Text('No pages found', style: TextStyle(color: Color(0xFF64748B))))
            : ListView.builder(
                itemCount: pages.length,
                itemBuilder: (_, i) {
                  final p = pages[i];
                  final selected = w.linkedPageId == p['id'];
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: Colors.purple.withOpacity(0.1),
                    leading: const Icon(Icons.dashboard, color: Color(0xFF64748B), size: 16),
                    title: Text(p['title'] ?? 'Untitled', style: TextStyle(color: selected ? Colors.purple : Colors.white, fontSize: 12)),
                    onTap: () {
                      _update(w.copyWith(linkedPageId: p['id']));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ));
  }
}
