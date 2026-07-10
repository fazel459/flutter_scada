import 'dart:async';
import 'dart:math' as math;
import '../models/widget_model.dart';
import '../models/enums.dart';

/// Service that simulates real-time data from various sources.
/// In a real app, this would connect to MQTT broker / Modbus TCP.
class DataSimulationService {
  Timer? _timer;
  final Map<String, double> _values = {};
  final Map<String, bool> _bools = {};
  final Map<String, String> _states = {};
  final void Function(ScadaWidget) _onUpdate;
  final void Function(ScadaWidget, String, double) _onAlarm;

  DataSimulationService(this._onUpdate, this._onAlarm);

  void start(List<ScadaWidget> widgets) {
    stop();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _tick(widgets));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(List<ScadaWidget> widgets) {
    for (final w in widgets) {
      switch (w.dataSource.protocol) {
        case ProtocolType.simulation:
        case ProtocolType.mqtt:
        case ProtocolType.modbusTcp:
          _simulate(w);
          break;
      }
    }
  }

  void _simulate(ScadaWidget w) {
    final boolTypes = <WidgetType>[
      WidgetType.led,
      WidgetType.switchWidget,
      WidgetType.fan,
      WidgetType.motor,
      WidgetType.relay,
    ];

    if (boolTypes.contains(w.type)) {
      _bools[w.id] = math.Random().nextDouble() > 0.3;
      final updated = w.copyWith(
        boolValue: _bools[w.id]!,
        connectionStatus: ConnectionStatus.connected,
        lastDataTime: DateTime.now(),
      );
      _checkAlarm(updated);
      _onUpdate(updated);
    } else if (w.states.isNotEmpty) {
      final states = <String>['open', 'closed', 'partial', 'unknown'];
      final newState = states[math.Random().nextInt(states.length)];
      _states[w.id] = newState;
      final updated = w.copyWith(
        currentState: newState,
        connectionStatus: ConnectionStatus.connected,
        lastDataTime: DateTime.now(),
      );
      _onUpdate(updated);
    } else {
      final current = _values[w.id] ?? w.minValue;
      final newVal = current + (math.Random().nextDouble() - 0.5) * 5;
      _values[w.id] = newVal.clamp(w.minValue, w.maxValue);
      final updated = w.copyWith(
        value: _values[w.id]!,
        connectionStatus: ConnectionStatus.connected,
        lastDataTime: DateTime.now(),
      );
      _checkAlarm(updated);
      _onUpdate(updated);
    }
  }

  void _checkAlarm(ScadaWidget w) {
    if (!w.alarm.enabled) return;
    if (w.isInAlarm) {
      final v = w.scaledValue;
      final threshold = w.alarmState == AlarmType.high ||
              w.alarmState == AlarmType.highHigh
          ? (w.alarmState == AlarmType.highHigh
              ? w.alarm.highHighThreshold
              : w.alarm.highThreshold)
          : (w.alarmState == AlarmType.lowLow
              ? w.alarm.lowLowThreshold
              : w.alarm.lowThreshold);
      _onAlarm(w, w.alarmState.name, v);
    }
  }

  void dispose() {
    stop();
  }
}
