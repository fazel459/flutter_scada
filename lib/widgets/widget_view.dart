import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/widget_model.dart';
import '../models/enums.dart';
import '../providers/providers.dart';
import 'painters.dart';

class ScadaWidgetView extends ConsumerStatefulWidget {
  final ScadaWidget widget;
  final bool designMode;
  final bool selected;
  final Function(ScadaWidget)? onUpdate;
  final Function(String handle)? onResizeStart;
  final Function(double dx, double dy)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onSelect;
  final ValueChanged<Offset>? onDrag;

  const ScadaWidgetView({
    super.key,
    required this.widget,
    this.designMode = false,
    this.selected = false,
    this.onUpdate,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onSelect,
    this.onDrag,
  });

  @override
  ConsumerState<ScadaWidgetView> createState() => _ScadaWidgetViewState();
}

class _ScadaWidgetViewState extends ConsumerState<ScadaWidgetView> with TickerProviderStateMixin {
  double _fanRotation = 0;
  double _flowPhase = 0;
  late AnimationController _controller;
  late AnimationController _blinkController;
  late AnimationController _flowController;
  double _blinkOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..addListener(() {
        if (widget.widget.type == WidgetType.fan &&
            (widget.widget.boolValue || widget.widget.value > 0)) {
          setState(() {
            _fanRotation += 0.2;
          });
        }
      });

    // Flow controller for animated path
    _flowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..addListener(() {
        if (widget.widget.type == WidgetType.animatedPath) {
          setState(() { _flowPhase = _flowController.value; });
        }
      });
    if (widget.widget.type == WidgetType.animatedPath) _flowController.repeat();

    // Blink controller
    _blinkController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.widget.alarm.blinkSpeed.toInt()),
    )..addListener(() {
      setState(() {
        _blinkOpacity = (math.sin(_blinkController.value * math.pi * 2) + 1) / 2;
      });
    });

    if (widget.widget.type == WidgetType.fan &&
        (widget.widget.boolValue || widget.widget.value > 0)) {
      _controller.repeat();
    }

    _updateBlinkState(widget.widget);


  }

  void _updateBlinkState(ScadaWidget w) {
    bool shouldBlink = false;

    // چک کردن آلارم برای چشمک زدن
    if (w.alarm.enabled && w.alarm.blinkOnAlarm && w.isInAlarm) {
      shouldBlink = true;
    }

    // چک کردن LED Dual
    if (w.type == WidgetType.ledDual && 
        w.ledDualConfig.blinkOnInput2 && 
        (w.ledDualConfig.input2 || w.boolValue)) {
      shouldBlink = true;
    }

    // چک کردن Calculated Digital blink
    if (w.type == WidgetType.calculated && w.calcIsDigital && w.calcBlinkOnTrue && w.value != 0) {
      shouldBlink = true;
    }

    if (shouldBlink && !_blinkController.isAnimating) {
      _blinkController.repeat();
    } else if (!shouldBlink && _blinkController.isAnimating) {
      _blinkController.stop();
      _blinkOpacity = 1.0;
    }
  }

  @override
  void didUpdateWidget(ScadaWidgetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update blink state
    _updateBlinkState(widget.widget);
    
    // Update blink speed if changed
    if (oldWidget.widget.alarm.blinkSpeed != widget.widget.alarm.blinkSpeed) {
      _blinkController.duration = Duration(milliseconds: widget.widget.alarm.blinkSpeed.toInt());
    }
    

  }

  @override
  Widget build(BuildContext context) {
    final liveWidget = ref.watch(widgetRuntimeByIdProvider(widget.widget.id)) ?? widget.widget;
    final history = ref.watch(widgetHistoryByIdProvider(widget.widget.id));

    // update blink based on live data without rebuilding parent page
    _updateBlinkState(liveWidget);

    return RepaintBoundary(
      child: Container(
        width: liveWidget.width,
        height: liveWidget.height,
        decoration: widget.selected
            ? BoxDecoration(border: Border.all(color: Colors.blue, width: 2))
            : (widget.designMode
                ? BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  )
                : null),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _getPainter(liveWidget, history),
                size: Size(liveWidget.width, liveWidget.height),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connectionColor(liveWidget),
                ),
              ),
            ),
            if (widget.designMode && widget.selected) ..._buildResizeHandles(),
          ],
        ),
      ),
    );
  }

  Color _connectionColor(ScadaWidget w) {
    switch (w.connectionStatus) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  CustomPainter _getPainter(ScadaWidget w, List<double> history) {
    switch (w.type) {
      case WidgetType.gauge:
        return GaugePainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.verticalTank:
        return VerticalTankPainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.horizontalTank:
        return HorizontalTankPainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.temperature:
        return TemperaturePainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.pressure:
        return GaugePainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.led:
        return LedPainter(w, blinkOpacity: w.isInAlarm && w.alarm.blinkOnAlarm ? _blinkOpacity : 1.0);
      case WidgetType.ledDual:
        return LedDualPainter(w, blinkOpacity: _blinkOpacity);
      case WidgetType.switchWidget:
        return SwitchPainter(w);
      case WidgetType.digitalDisplay:
        return DigitalDisplayPainter(w);
      case WidgetType.textDisplay:
        return TextDisplayPainter(w);
      case WidgetType.verticalBar:
        return VerticalBarPainter(w);
      case WidgetType.horizontalBar:
        return HorizontalBarPainter(w);
      case WidgetType.fan:
        return FanPainter(w, _fanRotation);
      case WidgetType.motor:
        return MotorPainter(w);
      case WidgetType.gateValve:
        return GateValvePainter(w);
      case WidgetType.controlValve:
        return ControlValvePainter(w);
      case WidgetType.relay:
        return RelayPainter(w);
      case WidgetType.slider:
        return SliderPainter(w);
      case WidgetType.statusIndicator:
        return StatusIndicatorPainter(w);
      case WidgetType.graph:
        return GraphPainter(w, history);
      case WidgetType.chart:
        return ChartPainter(w, history);
      case WidgetType.level:
        return VerticalBarPainter(w);
      case WidgetType.staticLabel:
        return StaticLabelPainter(w);
      case WidgetType.staticImage:
        return StaticImagePainter(w);
      case WidgetType.staticShape:
        return StaticShapePainter(w);
      case WidgetType.staticPipe:
        return StaticPipePainter(w);
      case WidgetType.staticPanel:
        return StaticPanelPainter(w);
      case WidgetType.staticIcon:
        return StaticIconPainter(w);
      case WidgetType.staticLine:
        return StaticLinePainter(w);
      case WidgetType.staticArrow:
        return StaticArrowPainter(w);
      case WidgetType.calculated:
        final calcBlink = w.calcIsDigital && w.calcBlinkOnTrue && w.value != 0;
        return CalculatedPainter(w, blinkOpacity: calcBlink ? _blinkOpacity : 1.0);
      case WidgetType.trendChart:
        return TrendChartPainter(w, history);
      case WidgetType.spcChart:
        return SpcChartPainter(w, history);
      case WidgetType.animatedPath:
        return AnimatedPathPainter(w, _flowPhase);
      case WidgetType.dataTable:
        return DataTablePainter(w);
    }
  }

  List<Widget> _buildResizeHandles() {
    // سایز بزرگ‌تر برای لمس راحت‌تر در موبایل
    const size = 22.0;
    const half = size / 2;
    final w = widget.widget.width;
    final h = widget.widget.height;
    const color = Colors.blue;

    Widget handle(String id, double left, double top) {
      Offset startPoint = Offset.zero;
      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            startPoint = details.localPosition;
            widget.onResizeStart?.call(id);
          },
          onPanUpdate: (details) {
            final dx = details.localPosition.dx - startPoint.dx;
            final dy = details.localPosition.dy - startPoint.dy;
            startPoint = details.localPosition;
            widget.onResizeUpdate?.call(dx, dy);
          },
          onPanEnd: (_) => widget.onResizeEnd?.call(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }

    return [
      handle('nw', -half, -half),
      handle('ne', w - half, -half),
      handle('sw', -half, h - half),
      handle('se', w - half, h - half),
      handle('n', w / 2 - half, -half),
      handle('s', w / 2 - half, h - half),
      handle('e', w - half, h / 2 - half),
      handle('w', -half, h / 2 - half),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkController.dispose();
    _flowController.dispose();
    super.dispose();
  }
}

double _clamp(double v) => v.clamp(0.0, 1.0);
