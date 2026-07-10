import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/models/alarm_model.dart';
import 'package:flutter_scada/models/page_model.dart';
import 'package:flutter_scada/models/user_model.dart';
import 'package:flutter_scada/screens/pages_screen.dart';
import 'package:uuid/uuid.dart';
import '../providers/providers.dart';
import '../models/widget_model.dart';
import '../models/enums.dart';
import '../services/data_service.dart';
import '../widgets/widget_view.dart';
import '../screens/widget_palette.dart';
import '../screens/property_panel.dart';
import '../screens/alarm_panel.dart';
import '../screens/report_screen.dart';
import '../utils/constants.dart';

class ScadaWorkspace extends ConsumerStatefulWidget {
  const ScadaWorkspace({super.key});

  @override
  ConsumerState<ScadaWorkspace> createState() => _ScadaWorkspaceState();
}

class _ScadaWorkspaceState extends ConsumerState<ScadaWorkspace> {
  final GlobalKey _canvasKey = GlobalKey();
  late DataSimulationService _dataService;
  Timer? _connectionTimer;

  DragData? _dragData;
  ResizeData? _resizeData;

  @override
  void initState() {
    super.initState();
    _dataService = DataSimulationService(
      (updated) {
        // Only update during view mode (not design mode)
        if (!ref.read(designModeProvider)) {
          ref.read(currentPageProvider.notifier).updateWidget(updated);
        }
      },
      (w, type, value) {
        // Add local alarm
        final alarm = _createAlarm(w, type, value);
        ref.read(alarmProvider.notifier).addLocalAlarm(alarm);
      },
    );
  }

  @override
  void dispose() {
    _dataService.dispose();
    _connectionTimer?.cancel();
    super.dispose();
  }

  AlarmLog _createAlarm(ScadaWidget w, String type, double value) {
    return AlarmLog(
      widgetId: w.id,
      widgetLabel: w.label,
      alarmType: type,
      value: value,
      threshold: type.contains('high')
          ? (type == 'highHigh' ? w.alarm.highHighThreshold : w.alarm.highThreshold)
          : (type == 'lowLow' ? w.alarm.lowLowThreshold : w.alarm.lowThreshold),
      message: '${w.label} $type alarm: ${value.toStringAsFixed(1)}',
      createdAt: DateTime.now(),
    );
  }

  void _startDataSimulation() {
    final page = ref.read(currentPageProvider);
    if (page != null && !ref.read(designModeProvider)) {
      _dataService.start(page.widgets);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(currentPageProvider);
    final designMode = ref.watch(designModeProvider);
    final user = ref.watch(authProvider).user!;
    final panels = ref.watch(panelsVisibleProvider);
    final alarmState = ref.watch(alarmProvider);
    final serverTime = ref.watch(serverTimeProvider).value ?? DateTime.now();

    if (page == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Constants.getTheme(page.theme);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Container(
        color: colorFromHex(theme['bg']!),
        child: Column(
          children: [
            // ============ TOOLBAR ============
            _buildToolbar(context, ref, page, designMode, user, alarmState.unacknowledged, serverTime, isMobile),

            // ============ MAIN AREA ============
            Expanded(
              child: Stack(
                children: [
                  // Canvas - همیشه تمام صفحه
                  Positioned.fill(
                    child: _buildCanvas(context, ref, page, designMode, panels),
                  ),

                  // Widget palette - در موبایل overlay
                  if (designMode && panels['widgetPalette'] == true)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: isMobile ? null : 0,
                      width: isMobile ? 180 : 224,
                      height: isMobile ? MediaQuery.of(context).size.height * 0.55 : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: isMobile
                              ? const BorderRadius.only(bottomRight: Radius.circular(12))
                              : null,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                        child: const WidgetPalette(),
                      ),
                    ),

                  // Property panel - در موبایل overlay
                  if (designMode && panels['propertyPanel'] == true && ref.watch(selectedWidgetProvider) != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: isMobile ? null : 0,
                      child: const PropertyPanel(),
                    ),
                ],
              ),
            ),

            // Alarm panel
            if (panels['alarmPanel'] == true)
              SizedBox(
                height: isMobile ? 150 : 200,
                child: const AlarmPanel(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref, ScadaPage page, bool designMode,
      User user, int unacknowledged, DateTime serverTime, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
            onPressed: () => _goBack(context, ref),
            tooltip: 'Back',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),

          // Title (کوتاه‌تر در موبایل)
          if (!isMobile)
            Flexible(
              child: Text(page.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),

          // Design/View toggle
          if (user.role.canDesign)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: isMobile
                  ? IconButton(
                      onPressed: () => ref.read(designModeProvider.notifier).state = !designMode,
                      icon: Icon(designMode ? Icons.visibility : Icons.build,
                          size: 18, color: designMode ? Colors.orange : Colors.white70),
                      tooltip: designMode ? 'View' : 'Design',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    )
                  : ElevatedButton.icon(
                      onPressed: () => ref.read(designModeProvider.notifier).state = !designMode,
                      icon: Icon(designMode ? Icons.visibility : Icons.build, size: 14),
                      label: Text(designMode ? 'View' : 'Design', style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: designMode ? Colors.orange : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
            ),

          const Spacer(),

          // Status (فقط در دسکتاپ)
          if (!isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !designMode ? Colors.green : Colors.amber,
                )),
                const SizedBox(width: 4),
                Text(_timeString(serverTime),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),

          // Reports
          _toolbarIcon(Icons.analytics, 'Reports', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ReportScreen(pageId: page.id)));
          }, isMobile: isMobile),

          // Undo/Redo
          if (designMode) ...[
            _toolbarIcon(Icons.undo, 'Undo', () {
              final data = ref.read(undoRedoProvider.notifier).undo();
              if (data != null) {
                final widgets = data.map((j) => ScadaWidget.fromJson(j)).toList();
                final p = ref.read(currentPageProvider);
                if (p != null) ref.read(currentPageProvider.notifier).updatePage(p.copyWith(widgets: widgets));
              }
            }, isMobile: isMobile),
            _toolbarIcon(Icons.redo, 'Redo', () {
              final data = ref.read(undoRedoProvider.notifier).redo();
              if (data != null) {
                final widgets = data.map((j) => ScadaWidget.fromJson(j)).toList();
                final p = ref.read(currentPageProvider);
                if (p != null) ref.read(currentPageProvider.notifier).updatePage(p.copyWith(widgets: widgets));
              }
            }, isMobile: isMobile),
          ],

          // Grid toggle
          if (designMode)
            _toolbarIcon(
              ref.watch(gridEnabledProvider) ? Icons.grid_on : Icons.grid_off,
              'Grid',
              () => ref.read(gridEnabledProvider.notifier).state = !ref.read(gridEnabledProvider),
              isMobile: isMobile,
            ),

          // Smart Guides toggle
          if (designMode)
            _toolbarIcon(
              Icons.straighten,
              ref.watch(smartGuidesEnabledProvider) ? 'Guides ON' : 'Guides OFF',
              () => ref.read(smartGuidesEnabledProvider.notifier).state = !ref.read(smartGuidesEnabledProvider),
              color: ref.watch(smartGuidesEnabledProvider) ? Colors.green : null,
              isMobile: isMobile,
            ),

          // Save
          if (designMode)
            _toolbarIcon(Icons.save, 'Save', () => _savePage(ref), color: Colors.green, isMobile: isMobile),

          // Alarm toggle
          _toolbarIcon(
            Icons.notifications,
            'Alarms',
            () => ref.read(panelsVisibleProvider.notifier).update((s) => {...s, 'alarmPanel': !(s['alarmPanel'] ?? false)}),
            badge: unacknowledged,
            isMobile: isMobile,
          ),

          // Panels toggle
          if (designMode)
            _toolbarIcon(Icons.widgets, 'Widgets',
              () => ref.read(panelsVisibleProvider.notifier).update((s) => {...s, 'widgetPalette': !(s['widgetPalette'] ?? false)}),
              isMobile: isMobile),
          if (designMode)
            _toolbarIcon(Icons.tune, 'Props',
              () => ref.read(panelsVisibleProvider.notifier).update((s) => {...s, 'propertyPanel': !(s['propertyPanel'] ?? false)}),
              isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _toolbarIcon(IconData icon, String tooltip, VoidCallback onPressed, {Color? color, int? badge, bool isMobile = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Stack(
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 18, color: color ?? Colors.white70),
            tooltip: tooltip,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          if (badge != null && badge > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 14),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$badge', style: const TextStyle(fontSize: 8, color: Colors.white), textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  double _snapToGrid(double value, double gridSize, bool enabled) {
    if (!enabled) return value;
    return (value / gridSize).round() * gridSize;
  }

  static const double _guideSnapThreshold = 5.0;

  SmartGuideLines _computeSmartGuides(WidgetRef ref, ScadaWidget dragging, double newX, double newY) {
    final page = ref.read(currentPageProvider);
    if (page == null) return const SmartGuideLines();

    final canvasW = page.width;
    final canvasH = page.height;
    final dragL = newX;
    final dragR = newX + dragging.width;
    final dragT = newY;
    final dragB = newY + dragging.height;
    final dragCx = newX + dragging.width / 2;
    final dragCy = newY + dragging.height / 2;

    final vLines = <double>[];
    final hLines = <double>[];
    final cvLines = <double>[];
    final chLines = <double>[];

    // Canvas center
    if ((dragCx - canvasW / 2).abs() < _guideSnapThreshold) cvLines.add(canvasW / 2);
    if ((dragCy - canvasH / 2).abs() < _guideSnapThreshold) chLines.add(canvasH / 2);

    for (final other in page.widgets) {
      if (other.id == dragging.id) continue;
      final oL = other.x;
      final oR = other.x + other.width;
      final oT = other.y;
      final oB = other.y + other.height;
      final oCx = other.x + other.width / 2;
      final oCy = other.y + other.height / 2;

      // Left edges
      if ((dragL - oL).abs() < _guideSnapThreshold) vLines.add(oL);
      // Right edges
      if ((dragR - oR).abs() < _guideSnapThreshold) vLines.add(oR);
      // Left to Right
      if ((dragL - oR).abs() < _guideSnapThreshold) vLines.add(oR);
      // Right to Left
      if ((dragR - oL).abs() < _guideSnapThreshold) vLines.add(oL);
      // Center X
      if ((dragCx - oCx).abs() < _guideSnapThreshold) cvLines.add(oCx);

      // Top edges
      if ((dragT - oT).abs() < _guideSnapThreshold) hLines.add(oT);
      // Bottom edges
      if ((dragB - oB).abs() < _guideSnapThreshold) hLines.add(oB);
      // Top to Bottom
      if ((dragT - oB).abs() < _guideSnapThreshold) hLines.add(oB);
      // Bottom to Top
      if ((dragB - oT).abs() < _guideSnapThreshold) hLines.add(oT);
      // Center Y
      if ((dragCy - oCy).abs() < _guideSnapThreshold) chLines.add(oCy);
    }

    return SmartGuideLines(
      verticalLines: vLines.toSet().toList(),
      horizontalLines: hLines.toSet().toList(),
      centerVertical: cvLines.toSet().toList(),
      centerHorizontal: chLines.toSet().toList(),
    );
  }

  (double, double) _snapToGuides(SmartGuideLines guides, ScadaWidget w, double x, double y) {
    var nx = x;
    var ny = y;
    final cx = x + w.width / 2;
    final cy = y + w.height / 2;

    for (final gx in guides.verticalLines) {
      if ((x - gx).abs() < _guideSnapThreshold) nx = gx;
      if ((x + w.width - gx).abs() < _guideSnapThreshold) nx = gx - w.width;
    }
    for (final gx in guides.centerVertical) {
      if ((cx - gx).abs() < _guideSnapThreshold) nx = gx - w.width / 2;
    }
    for (final gy in guides.horizontalLines) {
      if ((y - gy).abs() < _guideSnapThreshold) ny = gy;
      if ((y + w.height - gy).abs() < _guideSnapThreshold) ny = gy - w.height;
    }
    for (final gy in guides.centerHorizontal) {
      if ((cy - gy).abs() < _guideSnapThreshold) ny = gy - w.height / 2;
    }
    return (nx, ny);
  }

  Widget _buildCanvas(BuildContext context, WidgetRef ref, ScadaPage page, bool designMode, Map<String, bool> panels) {
    final selectedPaletteType = ref.watch(selectedPaletteTypeProvider);
    final gridEnabled = ref.watch(gridEnabledProvider);
    final gridSize = ref.watch(gridSizeProvider);
    final snapEnabled = ref.watch(snapToGridProvider);

    return Container(
      color: colorFromHex(page.backgroundColor),
      child: Stack(
        children: [
          // Background image if set
          if (page.backgroundImage != null)
            Positioned.fill(
              child: Image.network(page.backgroundImage!, fit: BoxFit.cover),
            ),
          // Grid overlay
          if (designMode && gridEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GridPainter(gridSize),
                ),
              ),
            ),
          // Drag area + Tap-to-place area
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: GestureDetector(
                onTapUp: (details) {
                  if (!designMode) return;

                  // اگر ویجتی از palette انتخاب شده، اینجا قرار بده
                  if (selectedPaletteType != null) {
                    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final local = renderBox.globalToLocal(details.globalPosition);
                      _addWidget(ref, selectedPaletteType, local.dx, local.dy);
                      // انتخاب palette حفظ می‌شود تا بتوان چند ویجت یکسان گذاشت
                    }
                    return;
                  }

                  // در غیر این صورت deselect ویجت فعلی
                  ref.read(selectedWidgetIdProvider.notifier).state = null;
                },
                child: DragTarget<WidgetType>(
                  onAcceptWithDetails: (details) {
                    final type = details.data;
                    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final local = renderBox.globalToLocal(details.offset);
                      _addWidget(ref, type, local.dx, local.dy);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      key: _canvasKey,
                      width: math.max(page.width, MediaQuery.of(context).size.width),
                      height: math.max(page.height, MediaQuery.of(context).size.height),
                      decoration: BoxDecoration(
                        border: designMode
                            ? Border.all(
                                color: selectedPaletteType != null
                                    ? Colors.blue.withOpacity(0.4)
                                    : Colors.blue.withOpacity(0.2),
                                width: selectedPaletteType != null ? 2 : 1,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: (List.from(page.widgets)..sort((a, b) => (a.zOrder).compareTo(b.zOrder))).map((widget) {
                          return _buildWidget(widget as ScadaWidget, ref, designMode);
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Smart Guide Lines overlay
          if (designMode)
            Consumer(builder: (ctx, ref, _) {
              final guides = ref.watch(activeGuidesProvider);
              if (!guides.hasAny) return const SizedBox.shrink();
              return Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SmartGuidesPainter(guides)),
                ),
              );
            }),

          // پیام بالای صفحه وقتی ویجت از palette انتخاب شده
          if (designMode && selectedPaletteType != null)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to place: ${selectedPaletteType.label}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(selectedPaletteTypeProvider.notifier).state = null,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // راهنمای صفحه خالی
          if (designMode && page.widgets.isEmpty)
            Center(
              child: IgnorePointer(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎨', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      selectedPaletteType != null
                          ? 'Now tap anywhere to place ${selectedPaletteType.label}'
                          : 'Select a widget from the panel,\nthen tap here to place it',
                      style: const TextStyle(color: Colors.white38, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Or drag & drop widgets on desktop',
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWidget(ScadaWidget widget, WidgetRef ref, bool designMode) {
    final selectedId = ref.watch(selectedWidgetIdProvider);
    final selectedPaletteType = ref.watch(selectedPaletteTypeProvider);
    final multiMode = ref.watch(multiSelectModeProvider);
    final multiIds = ref.watch(multiSelectedIdsProvider);
    final isSelected = selectedId == widget.id;
    final isMultiSelected = multiMode && multiIds.contains(widget.id);

    return Positioned(
      left: widget.x,
      top: widget.y,
      // اضافه کردن فضا برای نوار اکشن شناور
      width: widget.width,
      height: widget.height + (designMode && isSelected ? 44 : 0),
      child: Column(
        children: [
          // ویجت اصلی
          SizedBox(
            width: widget.width,
            height: widget.height,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (designMode && selectedPaletteType == null) {
                  // Multi-select mode
                  final multiMode = ref.read(multiSelectModeProvider);
                  if (multiMode) {
                    final ids = Set<String>.from(ref.read(multiSelectedIdsProvider));
                    if (ids.contains(widget.id)) {
                      ids.remove(widget.id);
                    } else {
                      ids.add(widget.id);
                    }
                    ref.read(multiSelectedIdsProvider.notifier).state = ids;
                  } else {
                    ref.read(selectedWidgetIdProvider.notifier).state = widget.id;
                  }
                }
              },
              child: GestureDetector(
                onTap: () {
                  if (selectedPaletteType != null) return;
                  final multiMode = ref.read(multiSelectModeProvider);
                  if (!multiMode) {
                    ref.read(selectedWidgetIdProvider.notifier).state = widget.id;
                  }
                  // View mode: اگر لینک صفحه داشته باشد → ناوبری
                  if (!designMode && widget.linkedPageId != null && widget.linkedPageId!.isNotEmpty) {
                    _navigateToPage(context, ref, widget.linkedPageId!);
                  }
                },
                onPanStart: designMode && selectedPaletteType == null && !widget.locked ? (details) {
                  ref.read(selectedWidgetIdProvider.notifier).state = widget.id;
                  _dragData = DragData(
                    widgetId: widget.id,
                    offsetX: details.localPosition.dx,
                    offsetY: details.localPosition.dy,
                  );
                } : null,
                onPanUpdate: designMode && selectedPaletteType == null && !widget.locked ? (details) {
            if (_dragData?.widgetId == widget.id) {
              final dx = details.localPosition.dx - _dragData!.offsetX;
              final dy = details.localPosition.dy - _dragData!.offsetY;
              final snap = ref.read(snapToGridProvider) && ref.read(gridEnabledProvider);
              final grid = ref.read(gridSizeProvider);
              var nx = math.max(0.0, widget.x + dx);
              var ny = math.max(0.0, widget.y + dy);
              if (snap) { nx = _snapToGrid(nx, grid, true); ny = _snapToGrid(ny, grid, true); }

              // Smart Guides
              if (ref.read(smartGuidesEnabledProvider)) {
                final guides = _computeSmartGuides(ref, widget, nx, ny);
                final (sx, sy) = _snapToGuides(guides, widget, nx, ny);
                nx = sx; ny = sy;
                ref.read(activeGuidesProvider.notifier).state = guides;
              }

              final updated = widget.copyWith(x: nx, y: ny);
                    _dragData = _dragData!.copyWith(offsetX: details.localPosition.dx, offsetY: details.localPosition.dy);
                    ref.read(currentPageProvider.notifier).updateWidget(updated);
                  }
                } : null,
                onPanEnd: designMode ? (_) {
            _dragData = null;
            ref.read(activeGuidesProvider.notifier).state = const SmartGuideLines();
            final p = ref.read(currentPageProvider);
            if (p != null) ref.read(undoRedoProvider.notifier).pushState(p.widgets.map((w) => w.toJson()).toList());
          } : null,
                child: Container(
                  decoration: isMultiSelected ? BoxDecoration(
                    border: Border.all(color: Colors.orange, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ) : null,
                  child: ScadaWidgetView(
                  widget: widget,
                  designMode: designMode,
                  selected: isSelected,
                  onResizeStart: designMode && !widget.locked ? (handle) {
                    _resizeData = ResizeData(
                      widgetId: widget.id,
                      handle: handle,
                      startX: widget.x,
                      startY: widget.y,
                      startW: widget.width,
                      startH: widget.height,
                    );
                    _resizeStartScale = _getScale(ref);
                  } : null,
                  onResizeUpdate: designMode ? (dx, dy) {
                    if (_resizeData?.widgetId == widget.id) {
                      _applyResize(ref, widget, _resizeData!, dx, dy);
                    }
                  } : null,
            onResizeEnd: designMode ? () {
              _resizeData = null;
            } : null,
          ),
        ),
        ),
      ),
    ),

          // نوار اکشن شناور - حذف / کپی / تنظیمات
          if (designMode && isSelected)
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF475569)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(Icons.copy, Colors.blue, 'Copy', () => _copyWidget(ref)),
                  _actionButton(Icons.delete, Colors.red, 'Delete', () => _deleteWidget(ref)),
                  _actionButton(Icons.tune, Colors.white70, 'Props', () {
                    ref.read(panelsVisibleProvider.notifier).update((s) => {...s, 'propertyPanel': true});
                  }),
                  // Lock
                  _actionButton(
                    widget.locked ? Icons.lock : Icons.lock_open,
                    widget.locked ? Colors.orange : Colors.white54,
                    widget.locked ? 'Unlock' : 'Lock',
                    () => ref.read(currentPageProvider.notifier).updateWidget(widget.copyWith(locked: !widget.locked)),
                  ),
                  // Z-Order
                  _actionButton(Icons.arrow_upward, Colors.white54, 'Bring Forward', () {
                    ref.read(currentPageProvider.notifier).updateWidget(widget.copyWith(zOrder: widget.zOrder + 1));
                  }),
                  _actionButton(Icons.arrow_downward, Colors.white54, 'Send Back', () {
                    ref.read(currentPageProvider.notifier).updateWidget(widget.copyWith(zOrder: math.max(0, widget.zOrder - 1)));
                  }),
                  const SizedBox(width: 4),
                  Text('${widget.width.toInt()}×${widget.height.toInt()}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                  if (widget.locked) const Padding(padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.lock, size: 10, color: Colors.orange)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  double _resizeStartScale = 1.0;

  double _getScale(WidgetRef ref) => 1.0;

  void _applyResize(WidgetRef ref, ScadaWidget widget, ResizeData data, double dx, double dy) {
    String handle = data.handle;
    double newW = data.startW;
    double newH = data.startH;
    double newX = data.startX;
    double newY = data.startY;

    if (handle.contains('e')) newW = math.max(40, data.startW + dx);
    if (handle.contains('s')) newH = math.max(40, data.startH + dy);
    if (handle.contains('w')) {
      newW = math.max(40, data.startW - dx);
      newX = data.startX + dx;
    }
    if (handle.contains('n')) {
      newH = math.max(40, data.startH - dy);
      newY = data.startY + dy;
    }

    ref.read(currentPageProvider.notifier).updateWidget(
      widget.copyWith(x: newX, y: newY, width: newW, height: newH),
    );
  }

  // ============ ACTIONS ============
  void _addWidget(WidgetRef ref, WidgetType type, double x, double y) {
    final snap = ref.read(snapToGridProvider);
    final grid = ref.read(gridSizeProvider);
    final sx = _snapToGrid(x, grid, snap && ref.read(gridEnabledProvider));
    final sy = _snapToGrid(y, grid, snap && ref.read(gridEnabledProvider));

    final id = const Uuid().v4();
    final widget = _createWidget(id, type, sx, sy);
    ref.read(currentPageProvider.notifier).addWidget(widget);
    ref.read(selectedWidgetIdProvider.notifier).state = id;

    // Push undo state
    final page = ref.read(currentPageProvider);
    if (page != null) {
      ref.read(undoRedoProvider.notifier).pushState(page.widgets.map((w) => w.toJson()).toList());
    }
  }

  ScadaWidget _createWidget(String id, WidgetType type, double x, double y) {
    final Map<WidgetType, Map<String, double>> sizes = {
      WidgetType.gauge: {'w': 200, 'h': 200},
      WidgetType.verticalTank: {'w': 120, 'h': 250},
      WidgetType.horizontalTank: {'w': 250, 'h': 120},
      WidgetType.temperature: {'w': 80, 'h': 220},
      WidgetType.pressure: {'w': 200, 'h': 200},
      WidgetType.led: {'w': 60, 'h': 60},
      WidgetType.ledDual: {'w': 70, 'h': 80},
      WidgetType.switchWidget: {'w': 100, 'h': 60},
      WidgetType.graph: {'w': 400, 'h': 250},
      WidgetType.chart: {'w': 400, 'h': 250},
      WidgetType.fan: {'w': 150, 'h': 150},
      WidgetType.motor: {'w': 160, 'h': 100},
      WidgetType.gateValve: {'w': 100, 'h': 100},
      WidgetType.controlValve: {'w': 100, 'h': 100},
      WidgetType.digitalDisplay: {'w': 200, 'h': 80},
      WidgetType.textDisplay: {'w': 200, 'h': 60},
      WidgetType.verticalBar: {'w': 60, 'h': 200},
      WidgetType.horizontalBar: {'w': 200, 'h': 60},
      WidgetType.relay: {'w': 80, 'h': 80},
      WidgetType.slider: {'w': 200, 'h': 60},
      WidgetType.statusIndicator: {'w': 120, 'h': 120},
      WidgetType.level: {'w': 80, 'h': 200},
      WidgetType.staticLabel: {'w': 160, 'h': 40},
      WidgetType.staticImage: {'w': 200, 'h': 150},
      WidgetType.staticShape: {'w': 100, 'h': 100},
      WidgetType.staticPipe: {'w': 200, 'h': 40},
      WidgetType.staticPanel: {'w': 300, 'h': 200},
      WidgetType.staticIcon: {'w': 60, 'h': 60},
      WidgetType.staticLine: {'w': 200, 'h': 10},
      WidgetType.staticArrow: {'w': 120, 'h': 40},
      WidgetType.calculated: {'w': 200, 'h': 100},
      WidgetType.trendChart: {'w': 350, 'h': 200},
      WidgetType.spcChart: {'w': 400, 'h': 250},
      WidgetType.animatedPath: {'w': 250, 'h': 50},
      WidgetType.dataTable: {'w': 400, 'h': 250},
    };

    final size = sizes[type]!;
    final unit = type == WidgetType.temperature ? '°C' : type == WidgetType.pressure ? 'kPa' : '';

    return ScadaWidget(
      id: id,
      type: type,
      label: type.label,
      x: x,
      y: y,
      width: size['w']!,
      height: size['h']!,
      unit: unit,
    );
  }

  void _copyWidget(WidgetRef ref) {
    final id = ref.read(selectedWidgetIdProvider);
    final page = ref.read(currentPageProvider);
    if (id == null || page == null) return;
    final original = page.widgets.firstWhere((w) => w.id == id);
    final newId = const Uuid().v4();
    final copy = original.copyWith(
      x: original.x + 30,
      y: original.y + 30,
      label: '${original.label} Copy',
    );
    // Need to change id
    final copied = ScadaWidget(
      id: newId,
      type: copy.type,
      label: copy.label,
      x: copy.x,
      y: copy.y,
      width: copy.width,
      height: copy.height,
      zero: copy.zero,
      span: copy.span,
      offset: copy.offset,
      multiplier: copy.multiplier,
      unit: copy.unit,
      value: copy.value,
      boolValue: copy.boolValue,
      currentState: copy.currentState,
      dataSource: copy.dataSource,
      alarm: copy.alarm,
      primaryColor: copy.primaryColor,
      secondaryColor: copy.secondaryColor,
      backgroundColor: copy.backgroundColor,
      textColor: copy.textColor,
      activeColor: copy.activeColor,
      inactiveColor: copy.inactiveColor,
      connectionStatus: copy.connectionStatus,
      animated: copy.animated,
    );
    copied.minValue = copy.minValue;
    copied.maxValue = copy.maxValue;

    ref.read(currentPageProvider.notifier).addWidget(copied);
    ref.read(selectedWidgetIdProvider.notifier).state = newId;
  }

  void _deleteWidget(WidgetRef ref) {
    final id = ref.read(selectedWidgetIdProvider);
    if (id == null) return;
    ref.read(currentPageProvider.notifier).removeWidget(id);
    ref.read(selectedWidgetIdProvider.notifier).state = null;
  }

  Future<void> _savePage(WidgetRef ref) async {
    await ref.read(currentPageProvider.notifier).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page saved successfully')),
      );
    }
  }

  void _navigateToPage(BuildContext context, WidgetRef ref, String pageId) async {
    try {
      await ref.read(currentPageProvider.notifier).loadPage(pageId);
      // صفحه جدید بارگذاری شد - بدون تغییر route
    } catch (_) {}
  }

  void _goBack(BuildContext context, WidgetRef ref) {
    _dataService.stop();
    // Refresh pages list
    final user = ref.read(authProvider).user!;
    if (user.role.canDesign) {
      ref.read(pagesProvider.notifier).loadPages();
    }
    ref.read(designModeProvider.notifier).state = false;
    ref.read(selectedWidgetIdProvider.notifier).state = null;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PagesScreen()),
    );
  }

  String _timeString(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class DragData {
  final String widgetId;
  final double offsetX;
  final double offsetY;
  DragData({required this.widgetId, required this.offsetX, required this.offsetY});
  DragData copyWith({double? offsetX, double? offsetY}) =>
      DragData(widgetId: widgetId, offsetX: offsetX ?? this.offsetX, offsetY: offsetY ?? this.offsetY);
}

class ResizeData {
  final String widgetId;
  final String handle;
  final double startX;
  final double startY;
  final double startW;
  final double startH;
  ResizeData({
    required this.widgetId,
    required this.handle,
    required this.startX,
    required this.startY,
    required this.startW,
    required this.startH,
  });
}

class _SmartGuidesPainter extends CustomPainter {
  final SmartGuideLines guides;
  _SmartGuidesPainter(this.guides);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = const Color(0xFFEF4444) // قرمز
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final centerPaint = Paint()
      ..color = const Color(0xFF22C55E) // سبز
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashEdge = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.4)
      ..strokeWidth = 0.5;

    final dashCenter = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.4)
      ..strokeWidth = 0.5;

    for (final x in guides.verticalLines) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), edgePaint);
      // tiny label
      _drawMiniLabel(canvas, x + 2, 10, '${x.toInt()}', const Color(0xFFEF4444));
    }
    for (final y in guides.horizontalLines) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), edgePaint);
      _drawMiniLabel(canvas, 4, y - 2, '${y.toInt()}', const Color(0xFFEF4444));
    }
    for (final x in guides.centerVertical) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), centerPaint);
      _drawMiniLabel(canvas, x + 2, 10, 'C', const Color(0xFF22C55E));
    }
    for (final y in guides.centerHorizontal) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), centerPaint);
      _drawMiniLabel(canvas, 4, y - 2, 'C', const Color(0xFF22C55E));
    }
  }

  void _drawMiniLabel(Canvas canvas, double x, double y, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 8, color: color.withOpacity(0.7))),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  final double gridSize;
  _GridPainter(this.gridSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
