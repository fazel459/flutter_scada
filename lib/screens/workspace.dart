// ignore_for_file: unused_element, deprecated_member_use, unused_field, unused_local_variable

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/models/alarm_model.dart';
import 'package:flutter_scada/models/page_model.dart';
import 'package:flutter_scada/models/user_model.dart';
import 'package:uuid/uuid.dart';
import '../providers/providers.dart';
import '../models/widget_model.dart';
import '../models/enums.dart';
import '../services/data_service.dart';
import '../services/formula_engine.dart';
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
  bool _simulationRunning = false;
  String? _simulationPageId;

  DragData? _dragData;
  ResizeData? _resizeData;

  // ✅ State درگ فوری
  String? _draggingWidgetId;
  Offset? _pointerStartGlobal;
  double _widgetStartX = 0;
  double _widgetStartY = 0;

  // ✅ فلگ برای جلوگیری از درگ هنگام resize
  bool _isResizing = false;

  // ✅ موقعیت شروع pointer هنگام resize
  Offset? _resizePointerStart;

  @override
  void initState() {
    super.initState();
    _dataService = DataSimulationService(
      (updated) {
        if (!ref.read(designModeProvider)) {
          _handleLiveUpdate(updated);
        }
      },
      (w, type, value) {
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
          ? (type == 'highHigh'
              ? w.alarm.highHighThreshold
              : w.alarm.highThreshold)
          : (type == 'lowLow' ? w.alarm.lowLowThreshold : w.alarm.lowThreshold),
      message: '${w.label} $type alarm: ${value.toStringAsFixed(1)}',
      createdAt: DateTime.now(),
    );
  }

  void _handleLiveUpdate(ScadaWidget updated) {
    // 1) update widget runtime only for changed widget
    ref.read(widgetRuntimeMapProvider.notifier).updateLive(updated);

    // 2) update tag value map (by boundTagId or label fallback)
    final tagName =
        (updated.boundTagId != null && updated.boundTagId!.isNotEmpty)
            ? updated.boundTagId!
            : updated.label;
    ref
        .read(liveTagValuesProvider.notifier)
        .setTagValue(tagName, updated.scaledValue);

    // 3) update per-widget history only for affected history widgets
    if (updated.type == WidgetType.graph || updated.type == WidgetType.chart) {
      final pct = ((updated.scaledValue - updated.minValue) /
              (updated.maxValue - updated.minValue == 0
                  ? 1
                  : (updated.maxValue - updated.minValue)))
          .clamp(0.0, 1.0);
      ref
          .read(widgetHistoryMapProvider.notifier)
          .append(updated.id, pct, maxPoints: 20);
    }

    // 4) update dependent widgets only (calculated / trend / spc / data table / animated path)
    _updateDependentWidgets(updated, tagName);
  }

  void _recomputeAllDerivedWidgets() {
    final page = ref.read(currentPageProvider);
    if (page == null) return;
    final runtimeMap = ref.read(widgetRuntimeMapProvider);

    // seed tag map from all source widgets
    final tagValues = <String, double>{};
    for (final w in page.widgets) {
      final rw = runtimeMap[w.id] ?? w;
      final tagName = (rw.boundTagId != null && rw.boundTagId!.isNotEmpty)
          ? rw.boundTagId!
          : rw.label;
      tagValues[tagName] = rw.scaledValue;
      ref
          .read(liveTagValuesProvider.notifier)
          .setTagValue(tagName, rw.scaledValue);
    }

    for (final w in page.widgets) {
      if (w.type == WidgetType.calculated) {
        final val = FormulaEngine.evaluate(w.calcFormula, tagValues);
        if (val.isNaN || val.isInfinite) continue;
        final prevRuntime = runtimeMap[w.id] ?? w;
        ref
            .read(widgetRuntimeMapProvider.notifier)
            .updateLive(prevRuntime.copyWith(
              value: val,
              boolValue: val != 0,
              connectionStatus: ConnectionStatus.connected,
              lastDataTime: DateTime.now(),
            ));
      }
      if ((w.type == WidgetType.trendChart || w.type == WidgetType.spcChart) &&
          w.boundTagId != null &&
          tagValues.containsKey(w.boundTagId!)) {
        final prevRuntime = runtimeMap[w.id] ?? w;
        final val = tagValues[w.boundTagId!]!;
        ref.read(widgetRuntimeMapProvider.notifier).updateLive(
            prevRuntime.copyWith(
                value: val,
                lastDataTime: DateTime.now(),
                connectionStatus: ConnectionStatus.connected));
        ref
            .read(widgetHistoryMapProvider.notifier)
            .append(w.id, val, maxPoints: w.trendPoints);
      }
      if (w.type == WidgetType.dataTable && w.tableCells.isNotEmpty) {
        final updatedCells = w.tableCells.map((cell) {
          final tag = cell['tagId'] ?? cell['tagName'];
          if (tag != null && tagValues.containsKey(tag.toString())) {
            return {...cell, 'value': tagValues[tag.toString()]};
          }
          return cell;
        }).toList();
        final prevRuntime = runtimeMap[w.id] ?? w;
        ref.read(widgetRuntimeMapProvider.notifier).updateLive(prevRuntime
            .copyWith(tableCells: updatedCells, lastDataTime: DateTime.now()));
      }
      if (w.type == WidgetType.animatedPath &&
          w.boundTagId != null &&
          tagValues.containsKey(w.boundTagId!)) {
        final prevRuntime = runtimeMap[w.id] ?? w;
        final val = tagValues[w.boundTagId!]!;
        ref.read(widgetRuntimeMapProvider.notifier).updateLive(
            prevRuntime.copyWith(
                value: val,
                boolValue: val > 0,
                lastDataTime: DateTime.now(),
                connectionStatus: ConnectionStatus.connected));
      }
    }
  }

  void _updateDependentWidgets(ScadaWidget source, String sourceTagName) {
    final page = ref.read(currentPageProvider);
    if (page == null) return;
    final runtimeMap = ref.read(widgetRuntimeMapProvider);
    final tagValues = {...ref.read(liveTagValuesProvider)};

    for (final w in page.widgets) {
      // Calculated widgets: only if formula depends on changed tag
      if (w.type == WidgetType.calculated) {
        final used = FormulaEngine.extractTags(w.calcFormula);
        final depends = used.contains(sourceTagName) ||
            w.calcInputTags.contains(sourceTagName) ||
            w.calcInputTags.contains(source.id) ||
            (w.boundTagId == sourceTagName);
        if (!depends) continue;

        final val = FormulaEngine.evaluate(w.calcFormula, tagValues);
        if (val.isNaN || val.isInfinite) continue;

        final prevRuntime = runtimeMap[w.id] ?? w;
        final now = DateTime.now();
        final nextSeconds = (prevRuntime.calcIsDigital && val != 0)
            ? (prevRuntime.calcActiveSeconds +
                (prevRuntime.lastDataTime != null
                    ? now.difference(prevRuntime.lastDataTime!).inMilliseconds /
                        1000.0
                    : 1.0))
            : 0.0;

        ref
            .read(widgetRuntimeMapProvider.notifier)
            .updateLive(prevRuntime.copyWith(
              value: val,
              boolValue: val != 0,
              calcActiveSeconds: nextSeconds,
              connectionStatus: ConnectionStatus.connected,
              lastDataTime: now,
            ));
      }

      // Trend/SPC widgets: only if boundTag matches changed tag
      if ((w.type == WidgetType.trendChart || w.type == WidgetType.spcChart) &&
          ((w.boundTagId != null && w.boundTagId == sourceTagName) ||
              w.label == sourceTagName)) {
        final prevRuntime = runtimeMap[w.id] ?? w;
        ref
            .read(widgetRuntimeMapProvider.notifier)
            .updateLive(prevRuntime.copyWith(
              value: source.scaledValue,
              connectionStatus: ConnectionStatus.connected,
              lastDataTime: DateTime.now(),
            ));
        ref
            .read(widgetHistoryMapProvider.notifier)
            .append(w.id, source.scaledValue, maxPoints: w.trendPoints);
      }

      // Data table widgets: update only matching cells
      if (w.type == WidgetType.dataTable && w.tableCells.isNotEmpty) {
        bool changed = false;
        final updatedCells = w.tableCells.map((cell) {
          if ((cell['tagId'] == sourceTagName) ||
              (cell['tagName'] == sourceTagName)) {
            changed = true;
            return {
              ...cell,
              'value': source.scaledValue,
              'unit': source.unit,
              'quality': source.connectionStatus == ConnectionStatus.connected
                  ? 'good'
                  : 'bad',
              'alarmColor': source.isInAlarm ? source.alarm.alarmColor : null,
            };
          }
          return cell;
        }).toList();
        if (changed) {
          final prevRuntime = runtimeMap[w.id] ?? w;
          ref
              .read(widgetRuntimeMapProvider.notifier)
              .updateLive(prevRuntime.copyWith(
                tableCells: updatedCells,
                connectionStatus: ConnectionStatus.connected,
                lastDataTime: DateTime.now(),
              ));
        }
      }

      // Animated path widgets: if boundTag matches source, update value/bool only
      if (w.type == WidgetType.animatedPath &&
          ((w.boundTagId != null && w.boundTagId == sourceTagName) ||
              w.label == sourceTagName)) {
        final prevRuntime = runtimeMap[w.id] ?? w;
        ref
            .read(widgetRuntimeMapProvider.notifier)
            .updateLive(prevRuntime.copyWith(
              value: source.scaledValue,
              boolValue: source.boolValue || source.scaledValue > 0,
              connectionStatus: source.connectionStatus,
              lastDataTime: DateTime.now(),
            ));
      }
    }
  }

  void _startDataSimulation() {
    final page = ref.read(currentPageProvider);
    if (page != null && !ref.read(designModeProvider)) {
      if (_simulationRunning && _simulationPageId == page.id) return;
      _dataService.start(page.widgets);
      _simulationRunning = true;
      _simulationPageId = page.id;
      _recomputeAllDerivedWidgets();
    }
  }

  void _stopDataSimulation() {
    if (_simulationRunning) {
      _dataService.stop();
      _simulationRunning = false;
      _simulationPageId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(currentPageProvider);
    final designMode = ref.watch(designModeProvider);
    final user = ref.watch(authProvider).user!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (page != null && !designMode) {
        _startDataSimulation();
      } else {
        _stopDataSimulation();
      }
    });
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
            _buildToolbar(context, ref, page, designMode, user,
                alarmState.unacknowledged, serverTime, isMobile),

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
                      height: isMobile
                          ? MediaQuery.of(context).size.height * 0.55
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: isMobile
                              ? const BorderRadius.only(
                                  bottomRight: Radius.circular(12))
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8),
                          ],
                        ),
                        child: const WidgetPalette(),
                      ),
                    ),

                  // Property panel - در موبایل overlay
                  if (designMode &&
                      panels['propertyPanel'] == true &&
                      ref.watch(selectedWidgetProvider) != null)
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

  Widget _buildToolbar(
      BuildContext context,
      WidgetRef ref,
      ScadaPage page,
      bool designMode,
      User user,
      int unacknowledged,
      DateTime serverTime,
      bool isMobile) {
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),

          // Design/View toggle
          if (user.role.canDesign)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: isMobile
                  ? IconButton(
                      onPressed: () => ref
                          .read(designModeProvider.notifier)
                          .state = !designMode,
                      icon: Icon(designMode ? Icons.visibility : Icons.build,
                          size: 18,
                          color: designMode ? Colors.orange : Colors.white70),
                      tooltip: designMode ? 'View' : 'Design',
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    )
                  : ElevatedButton.icon(
                      onPressed: () => ref
                          .read(designModeProvider.notifier)
                          .state = !designMode,
                      icon: Icon(designMode ? Icons.visibility : Icons.build,
                          size: 14),
                      label: Text(designMode ? 'View' : 'Design',
                          style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            designMode ? Colors.orange : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !designMode ? Colors.green : Colors.amber,
                    )),
                const SizedBox(width: 4),
                Text(_timeString(serverTime),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'monospace')),
              ],
            ),

          // Reports
          _toolbarIcon(Icons.analytics, 'Reports', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportScreen(pageId: page.id)));
          }, isMobile: isMobile),

          // Undo/Redo
          if (designMode) ...[
            _toolbarIcon(Icons.undo, 'Undo', () {
              final data = ref.read(undoRedoProvider.notifier).undo();
              if (data != null) {
                final widgets =
                    data.map((j) => ScadaWidget.fromJson(j)).toList();
                final p = ref.read(currentPageProvider);
                if (p != null) {
                  ref
                      .read(currentPageProvider.notifier)
                      .updatePage(p.copyWith(widgets: widgets));
                }
              }
            }, isMobile: isMobile),
            _toolbarIcon(Icons.redo, 'Redo', () {
              final data = ref.read(undoRedoProvider.notifier).redo();
              if (data != null) {
                final widgets =
                    data.map((j) => ScadaWidget.fromJson(j)).toList();
                final p = ref.read(currentPageProvider);
                if (p != null) {
                  ref
                      .read(currentPageProvider.notifier)
                      .updatePage(p.copyWith(widgets: widgets));
                }
              }
            }, isMobile: isMobile),
          ],

          // Grid toggle
          if (designMode)
            _toolbarIcon(
              ref.watch(gridEnabledProvider) ? Icons.grid_on : Icons.grid_off,
              'Grid',
              () => ref.read(gridEnabledProvider.notifier).state =
                  !ref.read(gridEnabledProvider),
              isMobile: isMobile,
            ),

          // Smart Guides toggle
          if (designMode)
            _toolbarIcon(
              Icons.straighten,
              ref.watch(smartGuidesEnabledProvider)
                  ? 'Guides ON'
                  : 'Guides OFF',
              () => ref.read(smartGuidesEnabledProvider.notifier).state =
                  !ref.read(smartGuidesEnabledProvider),
              color:
                  ref.watch(smartGuidesEnabledProvider) ? Colors.green : null,
              isMobile: isMobile,
            ),

          // Save
          if (designMode)
            _toolbarIcon(Icons.save, 'Save', () => _savePage(ref),
                color: Colors.green, isMobile: isMobile),

          // Alarm toggle
          _toolbarIcon(
            Icons.notifications,
            'Alarms',
            () => ref.read(panelsVisibleProvider.notifier).update(
                (s) => {...s, 'alarmPanel': !(s['alarmPanel'] ?? false)}),
            badge: unacknowledged,
            isMobile: isMobile,
          ),

          // Panels toggle
          if (designMode)
            _toolbarIcon(
                Icons.widgets,
                'Widgets',
                () => ref.read(panelsVisibleProvider.notifier).update((s) =>
                    {...s, 'widgetPalette': !(s['widgetPalette'] ?? false)}),
                isMobile: isMobile),
          if (designMode)
            _toolbarIcon(
                Icons.tune,
                'Props',
                () => ref.read(panelsVisibleProvider.notifier).update((s) =>
                    {...s, 'propertyPanel': !(s['propertyPanel'] ?? false)}),
                isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _toolbarIcon(IconData icon, String tooltip, VoidCallback onPressed,
      {Color? color, int? badge, bool isMobile = false}) {
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
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text('$badge',
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                    textAlign: TextAlign.center),
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

  SmartGuideLines _computeSmartGuides(
      WidgetRef ref, ScadaWidget dragging, double newX, double newY) {
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
    if ((dragCx - canvasW / 2).abs() < _guideSnapThreshold) {
      cvLines.add(canvasW / 2);
    }
    if ((dragCy - canvasH / 2).abs() < _guideSnapThreshold) {
      chLines.add(canvasH / 2);
    }

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

  (double, double) _snapToGuides(
      SmartGuideLines guides, ScadaWidget w, double x, double y) {
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

  Widget _buildCanvas(BuildContext context, WidgetRef ref, ScadaPage page,
      bool designMode, Map<String, bool> panels) {
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
                    final renderBox = _canvasKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final local =
                          renderBox.globalToLocal(details.globalPosition);
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
                    final renderBox = _canvasKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final local = renderBox.globalToLocal(details.offset);
                      _addWidget(ref, type, local.dx, local.dy);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      key: _canvasKey,
                      width: math.max(
                          page.width, MediaQuery.of(context).size.width),
                      height: math.max(
                          page.height, MediaQuery.of(context).size.height),
                      decoration: BoxDecoration(
                        border: designMode
                            ? Border.all(
                                color: selectedPaletteType != null
                                    ? Colors.blue.withValues(alpha: 0.4)
                                    : Colors.blue.withValues(alpha: 0.2),
                                width: selectedPaletteType != null ? 2 : 1,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: (List.from(page.widgets)
                              ..sort((a, b) => (a.zOrder).compareTo(b.zOrder)))
                            .map((widget) {
                          return _buildWidget(
                              widget as ScadaWidget, ref, designMode);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.push_pin, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to place: ${selectedPaletteType.label}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref
                            .read(selectedPaletteTypeProvider.notifier)
                            .state = null,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
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
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 16),
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

    // فضای اضافی برای دستگیره‌ها
    const double handleOverflow = 22.0;
    // ارتفاع نوار اکشن
    const double actionBarH = 44.0;

    return Positioned(
      // موقعیت شامل فضای دستگیره
      left: widget.x - handleOverflow,
      top: widget.y - handleOverflow,
      width: widget.width + handleOverflow * 2,
      height: widget.height +
          handleOverflow * 2 +
          (designMode && isSelected ? actionBarH : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── لایه 1: محتوای ویجت + درگ ───
          Positioned(
            left: handleOverflow,
            top: handleOverflow,
            width: widget.width,
            height: widget.height,
            child: Listener(  //response to common pointer events
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (!designMode || selectedPaletteType != null) return;
                if (_isResizing) return;

                // Multi-select
                if (multiMode) {
                  final ids =
                      Set<String>.from(ref.read(multiSelectedIdsProvider));
                  if (ids.contains(widget.id)) {
                    ids.remove(widget.id);
                  } else {
                    ids.add(widget.id);
                  }
                  ref.read(multiSelectedIdsProvider.notifier).state = ids;
                  return;
                }

                // انتخاب ویجت
                ref.read(selectedWidgetIdProvider.notifier).state = widget.id;

                if (widget.locked) return;

                // شروع درگ
                setState(() {
                  _draggingWidgetId = widget.id;
                  _pointerStartGlobal = event.position;
                  _widgetStartX = widget.x;
                  _widgetStartY = widget.y;
                });
              },
              onPointerMove: (event) {
                if (_draggingWidgetId != widget.id ||
                    _pointerStartGlobal == null ||
                    _isResizing) {
                  return;
                }

                final delta = event.position - _pointerStartGlobal!;
                var newX = _widgetStartX + delta.dx;
                var newY = _widgetStartY + delta.dy;

                // Snap to grid
                if (ref.read(snapToGridProvider) &&
                    ref.read(gridEnabledProvider)) {
                  final grid = ref.read(gridSizeProvider);
                  newX = (newX / grid).round() * grid.toDouble();
                  newY = (newY / grid).round() * grid.toDouble();
                }

                newX = math.max(0.0, newX);
                newY = math.max(0.0, newY);

                // ✅ Smart Guides حین درگ
                if (ref.read(smartGuidesEnabledProvider)) {
                  final tempWidget = widget.copyWith(x: newX, y: newY);
                  final guides =
                      _computeSmartGuides(ref, tempWidget, newX, newY);
                  final (sx, sy) =
                      _snapToGuides(guides, tempWidget, newX, newY);
                  newX = sx;
                  newY = sy;
                  ref.read(activeGuidesProvider.notifier).state = guides;
                }

                ref
                    .read(currentPageProvider.notifier)
                    .updateWidget(widget.copyWith(x: newX, y: newY));
              },
              onPointerUp: (event) {
                if (_draggingWidgetId != widget.id) return;

                // پاک کردن guides
                ref.read(activeGuidesProvider.notifier).state =
                    const SmartGuideLines();

                // Undo
                final p = ref.read(currentPageProvider);
                if (p != null) {
                  ref
                      .read(undoRedoProvider.notifier)
                      .pushState(p.widgets.map((w) => w.toJson()).toList());
                }

                setState(() {
                  _draggingWidgetId = null;
                  _pointerStartGlobal = null;
                });
              },
              onPointerCancel: (_) {
                if (_draggingWidgetId == widget.id) {
                  ref.read(activeGuidesProvider.notifier).state =
                      const SmartGuideLines();
                  setState(() {
                    _draggingWidgetId = null;
                    _pointerStartGlobal = null;
                  });
                }
              },
              child: GestureDetector(
                onTap: () {
                  if (selectedPaletteType != null) return;
                  if (!designMode &&
                      widget.linkedPageId != null &&
                      widget.linkedPageId!.isNotEmpty) {
                    _navigateToPage(context, ref, widget.linkedPageId!);
                  }
                },
                child: Container(
                  decoration: isMultiSelected
                      ? BoxDecoration(
                          border: Border.all(color: Colors.orange, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                      //ساخت ویجت
                  child: ScadaWidgetView(
                    widget: widget,
                    designMode: designMode,
                    selected: isSelected,
                  ),
                ),
              ),
            ),
          ),

          // ─── لایه 2: دستگیره‌های Resize ───
          if (designMode && isSelected && !widget.locked)
            ..._buildResizeHandles(widget, ref, handleOverflow),

          // ─── لایه 3: نوار اکشن ───
          if (designMode && isSelected)
            Positioned(
              left: handleOverflow,
              top: handleOverflow + widget.height + 4,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF475569)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(Icons.copy, Colors.blue, 'Copy',
                        () => _copyWidget(ref)),
                    _actionButton(Icons.delete, Colors.red, 'Delete',
                        () => _deleteWidget(ref)),
                    _actionButton(Icons.tune, Colors.white70, 'Props', () {
                      ref
                          .read(panelsVisibleProvider.notifier)
                          .update((s) => {...s, 'propertyPanel': true});
                    }),
                    _actionButton(
                      widget.locked ? Icons.lock : Icons.lock_open,
                      widget.locked ? Colors.orange : Colors.white54,
                      widget.locked ? 'Unlock' : 'Lock',
                      () => ref.read(currentPageProvider.notifier).updateWidget(
                          widget.copyWith(locked: !widget.locked)),
                    ),
                    _actionButton(Icons.arrow_upward, Colors.white54, 'Forward',
                        () {
                      ref.read(currentPageProvider.notifier).updateWidget(
                          widget.copyWith(zOrder: widget.zOrder + 1));
                    }),
                    _actionButton(Icons.arrow_downward, Colors.white54, 'Back',
                        () {
                      ref.read(currentPageProvider.notifier).updateWidget(widget
                          .copyWith(zOrder: math.max(0, widget.zOrder - 1)));
                    }),
                    const SizedBox(width: 4),
                    Text('${widget.width.toInt()}×${widget.height.toInt()}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 10)),
                    if (widget.locked)
                      const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child:
                              Icon(Icons.lock, size: 10, color: Colors.orange)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildResizeHandles(
      ScadaWidget widget, WidgetRef ref, double offset) {
    const double visualSize = 20.0;
    const double touchSize = 40.0;

    final double w = widget.width;
    final double h = widget.height;

    Widget handle(String id, double cx, double cy) {
      return Positioned(
        left: offset + cx - touchSize / 2,
        top: offset + cy - touchSize / 2,
        child: MouseRegion(
          cursor: _resizeCursor(id),
          child: Listener(
            behavior: HitTestBehavior.opaque,

            onPointerDown: (event) {
              // ✅ فلگ resize → درگ غیرفعال
              setState(() => _isResizing = true);

              // ✅ ذخیره ابعاد اولیه ویجت
              _resizeData = ResizeData(
                widgetId: widget.id,
                handle: id,
                startX: widget.x,
                startY: widget.y,
                startW: widget.width,
                startH: widget.height,
              );

              // ✅ ذخیره موقعیت شروع pointer
              _resizePointerStart = event.position;
            },

            onPointerMove: (event) {
              if (_resizeData == null ||
                  _resizeData!.widgetId != widget.id ||
                  _resizePointerStart == null) {
                return;
              }

              // ✅ محاسبه مجموع تغییر از ابتدا (نه فقط یک فریم)
              final totalDx =
                  event.position.dx - _resizePointerStart!.dx;
              final totalDy =
                  event.position.dy - _resizePointerStart!.dy;

              // ✅ ارسال مجموع تغییر به _applyResize
              _applyResize(
                  ref, widget, _resizeData!, totalDx, totalDy);
            },

            onPointerUp: (_) {
              _resizeData = null;
              _resizePointerStart = null;
              setState(() => _isResizing = false);

              // Undo
              final p = ref.read(currentPageProvider);
              if (p != null) {
                ref.read(undoRedoProvider.notifier).pushState(
                    p.widgets.map((w) => w.toJson()).toList());
              }
            },

            onPointerCancel: (_) {
              _resizeData = null;
              _resizePointerStart = null;
              setState(() => _isResizing = false);
            },

            child: Container(
              width: touchSize,
              height: touchSize,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  _handleIcon(id),
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return [
      handle('nw', 0, 0),
      handle('ne', w, 0),
      handle('sw', 0, h),
      handle('se', w, h),
      handle('n', w / 2, 0),
      handle('s', w / 2, h),
      handle('e', w, h / 2),
      handle('w', 0, h / 2),
    ];
  }

 MouseCursor _resizeCursor(String id) {
    switch (id) {
      case 'nw':
      case 'se':
        return SystemMouseCursors.resizeUpLeftDownRight;
      case 'ne':
      case 'sw':
        return SystemMouseCursors.resizeUpRightDownLeft;
      case 'n':
      case 's':
        return SystemMouseCursors.resizeUpDown;
      case 'e':
      case 'w':
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.precise;
    }
  }

  IconData _handleIcon(String id) {
    switch (id) {
      case 'nw':
        return Icons.north_west;
      case 'ne':
        return Icons.north_east;
      case 'sw':
        return Icons.south_west;
      case 'se':
        return Icons.south_east;
      case 'n':
        return Icons.expand_less;
      case 's':
        return Icons.expand_more;
      case 'e':
        return Icons.chevron_right;
      case 'w':
        return Icons.chevron_left;
      default:
        return Icons.open_with;
    }
  }


  Widget _actionButton(
      IconData icon, Color color, String tooltip, VoidCallback onTap) {
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

  final double _resizeStartScale = 1.0;

  double _getScale(WidgetRef ref) => 1.0;

  void _applyResize(WidgetRef ref, ScadaWidget widget, ResizeData data,
      double dx, double dy) {
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
      ref
          .read(undoRedoProvider.notifier)
          .pushState(page.widgets.map((w) => w.toJson()).toList());
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
  final unit = type == WidgetType.temperature
      ? '°C'
      : type == WidgetType.pressure
          ? 'kPa'
          : '';
  // ✅ مقدار اولیه برای پیش‌نمایش در حالت طراحی
  final double initialValue = _getPreviewValue(type);
  final bool initialBool = _getPreviewBool(type);
  return ScadaWidget(
    id: id,
    type: type,
    label: type.label,
    x: x,
    y: y,
    width: size['w']!,
    height: size['h']!,
    unit: unit,
    value: initialValue,     // ✅ مقدار اولیه ≠ 0
    boolValue: initialBool,  // ✅ حالت اولیه
  );
}

double _getPreviewValue(WidgetType type) {
  switch (type) {
    // Gauges & displays: 50% مقدار
    case WidgetType.gauge:
    case WidgetType.pressure:
    case WidgetType.digitalDisplay:
    case WidgetType.slider:
    case WidgetType.statusIndicator:
    case WidgetType.calculated:
      return 50;
    // Tanks & bars: 65%
    case WidgetType.verticalTank:
    case WidgetType.horizontalTank:
    case WidgetType.verticalBar:
    case WidgetType.horizontalBar:
    case WidgetType.level:
      return 65;
    // Temperature: مقدار واقعی
    case WidgetType.temperature:
      return 45;
    // Fan/Motor: RPM
    case WidgetType.fan:
      return 1500;
    case WidgetType.motor:
      return 1;
    // Valves: باز
    case WidgetType.gateValve:
    case WidgetType.controlValve:
      return 100;
    // Switches/LEDs/Relays: روشن
    case WidgetType.switchWidget:
    case WidgetType.led:
    case WidgetType.ledDual:
    case WidgetType.relay:
      return 1;
    // Text displays
    case WidgetType.textDisplay:
      return 42;
    // Charts: dummy
    case WidgetType.graph:
    case WidgetType.chart:
    case WidgetType.trendChart:
    case WidgetType.spcChart:
      return 50;
    // Animated path
    case WidgetType.animatedPath:
      return 1;
    // Static widgets: بدون مقدار
    default:
      return 0;
  }
}
// ✅ تابع جدید — حالت bool اولیه
bool _getPreviewBool(WidgetType type) {
  switch (type) {
    case WidgetType.switchWidget:
    case WidgetType.led:
    case WidgetType.ledDual:
    case WidgetType.relay:
    case WidgetType.motor:
    case WidgetType.fan:
    case WidgetType.animatedPath:
      return true;
    default:
      return false;
  }
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
    _pushUndo(ref);
  }

  void _deleteWidget(WidgetRef ref) {
    final id = ref.read(selectedWidgetIdProvider);
    if (id == null) return;
    ref.read(currentPageProvider.notifier).removeWidget(id);
    ref.read(selectedWidgetIdProvider.notifier).state = null;
    _pushUndo(ref);
  }

  void _pushUndo(WidgetRef ref) {
    final p = ref.read(currentPageProvider);
    if (p != null) {
      ref
          .read(undoRedoProvider.notifier)
          .pushState(p.widgets.map((w) => w.toJson()).toList());
    }
  }

  Future<void> _savePage(WidgetRef ref) async {
    await ref.read(currentPageProvider.notifier).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Page saved successfully')),
      );
    }
  }

  void _navigateToPage(
      BuildContext context, WidgetRef ref, String pageId) async {
    try {
      await ref.read(currentPageProvider.notifier).loadPage(pageId);
      // صفحه جدید بارگذاری شد - بدون تغییر route
    } catch (_) {}
  }

  void _goBack(BuildContext context, WidgetRef ref) {
    _dataService.stop();
    ref.read(pagesProvider.notifier).loadPages();
    ref.read(designModeProvider.notifier).state = false;
    ref.read(selectedWidgetIdProvider.notifier).state = null;

    // ✅ فقط pop — برگشت به MainShell
    Navigator.pop(context);
  }

  String _timeString(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class DragData {
  final String widgetId;
  final double offsetX;
  final double offsetY;
  DragData(
      {required this.widgetId, required this.offsetX, required this.offsetY});
  DragData copyWith({double? offsetX, double? offsetY}) => DragData(
      widgetId: widgetId,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY);
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
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    final dashCenter = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    for (final x in guides.verticalLines) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), edgePaint);
      // tiny label
      _drawMiniLabel(
          canvas, x + 2, 10, '${x.toInt()}', const Color(0xFFEF4444));
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

  void _drawMiniLabel(
      Canvas canvas, double x, double y, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.7))),
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
      ..color = Colors.white.withValues(alpha: 0.06)
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

