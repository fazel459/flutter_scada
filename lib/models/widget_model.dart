import 'dart:convert';
import 'package:flutter/material.dart';
import 'enums.dart';

/// Data source binding config
class DataSourceBinding {
  final ProtocolType protocol;
  // MQTT
  final String? mqttBroker;
  final String? mqttTopic;
  final int mqttPort;
  // Modbus
  final String? modbusHost;
  final int modbusPort;
  final int modbusUnitId;
  final int modbusRegister;
  final ModbusRegisterType modbusRegisterType;
  // General
  final int pollInterval;

  const DataSourceBinding({
    this.protocol = ProtocolType.simulation,
    this.mqttBroker,
    this.mqttTopic,
    this.mqttPort = 1883,
    this.modbusHost,
    this.modbusPort = 502,
    this.modbusUnitId = 1,
    this.modbusRegister = 0,
    this.modbusRegisterType = ModbusRegisterType.holding,
    this.pollInterval = 2000,
  });

  Map<String, dynamic> toJson() => {
        'protocol': protocol.name,
        'mqttBroker': mqttBroker,
        'mqttTopic': mqttTopic,
        'mqttPort': mqttPort,
        'modbusHost': modbusHost,
        'modbusPort': modbusPort,
        'modbusUnitId': modbusUnitId,
        'modbusRegister': modbusRegister,
        'modbusRegisterType': modbusRegisterType.name,
        'pollInterval': pollInterval,
      };

  factory DataSourceBinding.fromJson(Map<String, dynamic> json) => DataSourceBinding(
        protocol: ProtocolType.values.firstWhere(
          (e) => e.name == json['protocol'],
          orElse: () => ProtocolType.simulation,
        ),
        mqttBroker: json['mqttBroker'],
        mqttTopic: json['mqttTopic'],
        mqttPort: json['mqttPort'] ?? 1883,
        modbusHost: json['modbusHost'],
        modbusPort: json['modbusPort'] ?? 502,
        modbusUnitId: json['modbusUnitId'] ?? 1,
        modbusRegister: json['modbusRegister'] ?? 0,
        modbusRegisterType: ModbusRegisterType.values.firstWhere(
          (e) => e.name == json['modbusRegisterType'],
          orElse: () => ModbusRegisterType.holding,
        ),
        pollInterval: json['pollInterval'] ?? 2000,
      );

  DataSourceBinding copyWith({
    ProtocolType? protocol,
    String? mqttBroker,
    String? mqttTopic,
    int? mqttPort,
    String? modbusHost,
    int? modbusPort,
    int? modbusUnitId,
    int? modbusRegister,
    ModbusRegisterType? modbusRegisterType,
    int? pollInterval,
  }) {
    return DataSourceBinding(
      protocol: protocol ?? this.protocol,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      mqttPort: mqttPort ?? this.mqttPort,
      modbusHost: modbusHost ?? this.modbusHost,
      modbusPort: modbusPort ?? this.modbusPort,
      modbusUnitId: modbusUnitId ?? this.modbusUnitId,
      modbusRegister: modbusRegister ?? this.modbusRegister,
      modbusRegisterType: modbusRegisterType ?? this.modbusRegisterType,
      pollInterval: pollInterval ?? this.pollInterval,
    );
  }
}

/// Alarm configuration
class AlarmConfig {
  final bool enabled;
  final double highThreshold;
  final double lowThreshold;
  final double highHighThreshold;
  final double lowLowThreshold;
  final String normalColor;
  final String warningColor;
  final String alarmColor;
  final bool blinkOnAlarm;  // چشمک زدن در حالت آلارم
  final double blinkSpeed;  // سرعت چشمک زدن (میلی‌ثانیه)

  const AlarmConfig({
    this.enabled = false,
    this.highThreshold = 80,
    this.lowThreshold = 20,
    this.highHighThreshold = 95,
    this.lowLowThreshold = 5,
    this.normalColor = '#22C55E',
    this.warningColor = '#EAB308',
    this.alarmColor = '#EF4444',
    this.blinkOnAlarm = true,
    this.blinkSpeed = 500,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'highThreshold': highThreshold,
        'lowThreshold': lowThreshold,
        'highHighThreshold': highHighThreshold,
        'lowLowThreshold': lowLowThreshold,
        'normalColor': normalColor,
        'warningColor': warningColor,
        'alarmColor': alarmColor,
        'blinkOnAlarm': blinkOnAlarm,
        'blinkSpeed': blinkSpeed,
      };

  factory AlarmConfig.fromJson(Map<String, dynamic> json) => AlarmConfig(
        enabled: json['enabled'] ?? false,
        highThreshold: (json['highThreshold'] ?? 80).toDouble(),
        lowThreshold: (json['lowThreshold'] ?? 20).toDouble(),
        highHighThreshold: (json['highHighThreshold'] ?? 95).toDouble(),
        lowLowThreshold: (json['lowLowThreshold'] ?? 5).toDouble(),
        normalColor: json['normalColor'] ?? '#22C55E',
        warningColor: json['warningColor'] ?? '#EAB308',
        alarmColor: json['alarmColor'] ?? '#EF4444',
        blinkOnAlarm: json['blinkOnAlarm'] ?? true,
        blinkSpeed: (json['blinkSpeed'] ?? 500).toDouble(),
      );

  AlarmConfig copyWith({
    bool? enabled,
    double? highThreshold,
    double? lowThreshold,
    double? highHighThreshold,
    double? lowLowThreshold,
    String? normalColor,
    String? warningColor,
    String? alarmColor,
    bool? blinkOnAlarm,
    double? blinkSpeed,
  }) {
    return AlarmConfig(
      enabled: enabled ?? this.enabled,
      highThreshold: highThreshold ?? this.highThreshold,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      highHighThreshold: highHighThreshold ?? this.highHighThreshold,
      lowLowThreshold: lowLowThreshold ?? this.lowLowThreshold,
      normalColor: normalColor ?? this.normalColor,
      warningColor: warningColor ?? this.warningColor,
      alarmColor: alarmColor ?? this.alarmColor,
      blinkOnAlarm: blinkOnAlarm ?? this.blinkOnAlarm,
      blinkSpeed: blinkSpeed ?? this.blinkSpeed,
    );
  }
}

/// LED Dual configuration - دو ورودی برای LED دو حالته
class LedDualConfig {
  final bool input1;  // ورودی اول (حالت عادی)
  final bool input2;  // ورودی دوم (حالت آلارم/چشمک)
  final String input1Color;  // رنگ ورودی اول
  final String input2Color;  // رنگ ورودی دوم
  final bool blinkOnInput2;  // چشمک زدن در حالت ورودی دوم
  final double blinkSpeed;

  const LedDualConfig({
    this.input1 = false,
    this.input2 = false,
    this.input1Color = '#22C55E',
    this.input2Color = '#EF4444',
    this.blinkOnInput2 = true,
    this.blinkSpeed = 500,
  });

  Map<String, dynamic> toJson() => {
    'input1': input1,
    'input2': input2,
    'input1Color': input1Color,
    'input2Color': input2Color,
    'blinkOnInput2': blinkOnInput2,
    'blinkSpeed': blinkSpeed,
  };

  factory LedDualConfig.fromJson(Map<String, dynamic> json) => LedDualConfig(
    input1: json['input1'] ?? false,
    input2: json['input2'] ?? false,
    input1Color: json['input1Color'] ?? '#22C55E',
    input2Color: json['input2Color'] ?? '#EF4444',
    blinkOnInput2: json['blinkOnInput2'] ?? true,
    blinkSpeed: (json['blinkSpeed'] ?? 500).toDouble(),
  );

  LedDualConfig copyWith({
    bool? input1,
    bool? input2,
    String? input1Color,
    String? input2Color,
    bool? blinkOnInput2,
    double? blinkSpeed,
  }) {
    return LedDualConfig(
      input1: input1 ?? this.input1,
      input2: input2 ?? this.input2,
      input1Color: input1Color ?? this.input1Color,
      input2Color: input2Color ?? this.input2Color,
      blinkOnInput2: blinkOnInput2 ?? this.blinkOnInput2,
      blinkSpeed: blinkSpeed ?? this.blinkSpeed,
    );
  }
}

/// Multi-state config for widgets like gate valve
class StateConfig {
  final String label;
  final String color;

  const StateConfig({required this.label, required this.color});

  Map<String, dynamic> toJson() => {'label': label, 'color': color};
  factory StateConfig.fromJson(Map<String, dynamic> json) =>
      StateConfig(label: json['label'], color: json['color']);
}

/// Main widget model
class ScadaWidget {
  final String id;
  final WidgetType type;
  String label;
  double x;
  double y;
  double width;
  double height;

  // Value scaling
  double zero;
  double span;
  double offset;
  double multiplier;
  String unit;

  // Current values
  double value;
  bool boolValue;
  String? currentState;

  // Data source
  DataSourceBinding dataSource;

  // Alarm
  AlarmConfig alarm;

  // LED Dual config
  LedDualConfig ledDualConfig;

  // State definitions for multi-state widgets
  Map<String, StateConfig> states;

  // Colors
  String primaryColor;
  String secondaryColor;
  String backgroundColor;
  String textColor;
  String activeColor;
  String inactiveColor;

  // Background & Frame
  double bgOpacity;       // 0.0 - 1.0
  bool bgTransparent;     // پس‌زمینه کاملاً شفاف
  bool frameless;         // بدون فریم/سایه/گوشه گرد

  // Status
  ConnectionStatus connectionStatus;
  DateTime? lastDataTime;

  bool animated;
  bool locked;           // قفل ویجت - جلوگیری از جابجایی
  int zOrder;            // ترتیب لایه (بالاتر = جلوتر)
  String? linkedPageId;  // لینک به صفحه دیگر - کلیک → ناوبری
  String? boundTagId;    // تگ متصل شده از Tag Management

  // ====== Calculated widget properties ======
  String calcFormula;             // فرمول مثلاً "({TT-101} + {TT-102}) / 2"
  List<String> calcInputTags;    // لیست ID تگ‌های ورودی
  String calcDisplayAs;           // gauge, digital, bar, text, led, switch, status
  int calcRefreshMs;              // فاصله محاسبه مجدد
  bool calcIsDigital;             // آیا خروجی دیجیتال (0/1) است
  String calcTrueLabel;           // لیبل حالت 1 (مثلاً "باز", "روشن", "فعال")
  String calcFalseLabel;          // لیبل حالت 0 (مثلاً "بسته", "خاموش", "غیرفعال")
  String calcTrueColor;           // رنگ حالت 1
  String calcFalseColor;          // رنگ حالت 0
  bool calcBlinkOnTrue;           // چشمک زدن در حالت 1
  double calcActiveSeconds;       // مدت زمان فعال بودن (ثانیه) - تایمر

  // ====== Data Table properties ======
  int tableRows;
  int tableCols;
  List<Map<String, dynamic>> tableCells; // [{row,col,rowSpan,colSpan,tagId,tagName,tagDesc,value,unit,alarmColor,showQualityIcon}]
  String tableHeaderColor;
  String tableBorderColor;
  bool tableShowHeader;
  bool tableAlarmColoring;   // رنگ‌بندی سلول بر اساس آلارم
  bool tableShowQualityIcon; // نمایش آیکون کیفیت سیگنال

  // ====== Animated Path properties ======
  String pathDirection;      // horizontal, vertical, elbow_right, elbow_down...
  String pathFlowColor;      // رنگ ذرات متحرک
  double pathSpeed;          // سرعت انیمیشن
  double pathWidth;          // ضخامت مسیر
  bool pathFlowing;          // آیا جریان فعال است
  bool pathReverse;          // جهت جریان معکوس
  int pathLanes;             // تعداد ردیف ذرات
  String pathDisplayText;    // متن نمایش روی مسیر

  // ====== SPC Chart properties ======
  double spcUcl;    // Upper Control Limit
  double spcLcl;    // Lower Control Limit
  double spcTarget; // Target/Center Line
  int trendPoints;  // تعداد نقاط تاریخچه

  // ====== Static/Graphic widget properties ======
  String staticText;          // متن برای Label
  double staticFontSize;      // اندازه فونت
  String staticFontColor;     // رنگ فونت
  bool staticBold;            // بولد
  String staticImageUrl;      // آدرس تصویر
  String staticShapeType;     // rectangle, circle, ellipse, diamond
  String staticShapeColor;    // رنگ شکل
  double staticShapeBorder;   // ضخامت حاشیه
  String staticBorderColor;   // رنگ حاشیه
  bool staticFilled;          // پر شده یا فقط حاشیه
  String staticPipeDirection; // horizontal, vertical, elbow_right, elbow_left, elbow_down, elbow_up, tee_right, tee_down, cross
  String staticPipeColor;     // رنگ لوله
  double staticPipeWidth;     // ضخامت لوله
  String staticIconName;      // نام آیکون
  double staticRotation;      // زاویه چرخش (درجه)
  String staticArrowDir;      // right, left, up, down
  String staticPanelTitle;    // عنوان پنل

  ScadaWidget({
    required this.id,
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zero = 0,
    this.span = 100,
    this.offset = 0,
    this.multiplier = 1,
    this.unit = '',
    this.value = 0,
    this.boolValue = false,
    this.currentState,
    this.dataSource = const DataSourceBinding(),
    this.alarm = const AlarmConfig(),
    this.ledDualConfig = const LedDualConfig(),
    Map<String, StateConfig>? states,
    this.primaryColor = '#3B82F6',
    this.secondaryColor = '#64748B',
    this.backgroundColor = '#1E293B',
    this.textColor = '#E2E8F0',
    this.activeColor = '#22C55E',
    this.inactiveColor = '#EF4444',
    this.bgOpacity = 1.0,
    this.bgTransparent = false,
    this.frameless = false,
    this.connectionStatus = ConnectionStatus.unknown,
    this.lastDataTime,
    this.animated = false,
    this.locked = false,
    this.zOrder = 0,
    this.linkedPageId,
    this.boundTagId,
    this.calcFormula = '',
    List<String>? calcInputTags,
    this.calcDisplayAs = 'digital',
    this.calcRefreshMs = 1000,
    this.calcIsDigital = false,
    this.calcTrueLabel = 'ON',
    this.calcFalseLabel = 'OFF',
    this.calcTrueColor = '#22C55E',
    this.calcFalseColor = '#EF4444',
    this.calcBlinkOnTrue = false,
    this.calcActiveSeconds = 0,
    this.tableRows = 3,
    this.tableCols = 3,
    List<Map<String, dynamic>>? tableCells,
    this.tableHeaderColor = '#334155',
    this.tableBorderColor = '#475569',
    this.tableShowHeader = true,
    this.tableAlarmColoring = true,
    this.tableShowQualityIcon = true,
    this.pathDirection = 'horizontal',
    this.pathFlowColor = '#3B82F6',
    this.pathSpeed = 2.0,
    this.pathWidth = 10,
    this.pathFlowing = true,
    this.pathReverse = false,
    this.pathLanes = 1,
    this.pathDisplayText = '',
    this.spcUcl = 80,
    this.spcLcl = 20,
    this.spcTarget = 50,
    this.trendPoints = 30,
    this.staticText = '',
    this.staticFontSize = 16,
    this.staticFontColor = '#FFFFFF',
    this.staticBold = false,
    this.staticImageUrl = '',
    this.staticShapeType = 'rectangle',
    this.staticShapeColor = '#3B82F6',
    this.staticShapeBorder = 2,
    this.staticBorderColor = '#64748B',
    this.staticFilled = true,
    this.staticPipeDirection = 'horizontal',
    this.staticPipeColor = '#64748B',
    this.staticPipeWidth = 8,
    this.staticIconName = 'star',
    this.staticRotation = 0,
    this.staticArrowDir = 'right',
    this.staticPanelTitle = 'Panel',
  }) : tableCells = tableCells ?? [],
       calcInputTags = calcInputTags ?? [],
       states = states ??
            (ScadaWidget._stateWidgetTypes.contains(type)
                ? {
                    'open': const StateConfig(label: 'Open', color: '#22C55E'),
                    'closed': const StateConfig(label: 'Closed', color: '#EF4444'),
                    'partial': const StateConfig(label: 'Partial', color: '#EAB308'),
                    'unknown': const StateConfig(label: 'Unknown', color: '#94A3B8'),
                  }
                : {});

  static const List<WidgetType> _stateWidgetTypes = [
    WidgetType.gateValve,
    WidgetType.controlValve,
    WidgetType.statusIndicator,
  ];

  /// Scaled value using zero/span/offset/multiplier
  double get scaledValue {
    final raw = value * multiplier + offset;
    final range = span - zero;
    if (range == 0) return 0;
    return ((raw - zero) / range) * (maxValue - minValue) + minValue;
  }

  double minValue = 0;
  double maxValue = 100;

  /// Check if value is in alarm condition
  AlarmType get alarmState {
    if (!alarm.enabled) return AlarmType.none;
    final v = scaledValue;
    if (v >= alarm.highHighThreshold) return AlarmType.highHigh;
    if (v <= alarm.lowLowThreshold) return AlarmType.lowLow;
    if (v >= alarm.highThreshold) return AlarmType.high;
    if (v <= alarm.lowThreshold) return AlarmType.low;
    return AlarmType.none;
  }

  bool get isInAlarm => alarmState != AlarmType.none;

  ScadaWidget copyWith({
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    double? zero,
    double? span,
    double? offset,
    double? multiplier,
    String? unit,
    double? value,
    bool? boolValue,
    String? currentState,
    DataSourceBinding? dataSource,
    AlarmConfig? alarm,
    LedDualConfig? ledDualConfig,
    String? primaryColor,
    String? secondaryColor,
    String? backgroundColor,
    String? textColor,
    String? activeColor,
    String? inactiveColor,
    double? bgOpacity,
    bool? bgTransparent,
    bool? frameless,
    ConnectionStatus? connectionStatus,
    DateTime? lastDataTime,
    bool? animated,
    bool? locked,
    int? zOrder,
    String? linkedPageId,
    String? boundTagId,
    double? minValue,
    double? maxValue,
    String? calcFormula,
    List<String>? calcInputTags,
    String? calcDisplayAs,
    int? calcRefreshMs,
    bool? calcIsDigital,
    String? calcTrueLabel,
    String? calcFalseLabel,
    String? calcTrueColor,
    String? calcFalseColor,
    bool? calcBlinkOnTrue,
    double? calcActiveSeconds,
    int? tableRows,
    int? tableCols,
    List<Map<String, dynamic>>? tableCells,
    String? tableHeaderColor,
    String? tableBorderColor,
    bool? tableShowHeader,
    bool? tableAlarmColoring,
    bool? tableShowQualityIcon,
    String? pathDirection,
    String? pathFlowColor,
    double? pathSpeed,
    double? pathWidth,
    bool? pathFlowing,
    bool? pathReverse,
    int? pathLanes,
    String? pathDisplayText,
    double? spcUcl,
    double? spcLcl,
    double? spcTarget,
    int? trendPoints,
    String? staticText,
    double? staticFontSize,
    String? staticFontColor,
    bool? staticBold,
    String? staticImageUrl,
    String? staticShapeType,
    String? staticShapeColor,
    double? staticShapeBorder,
    String? staticBorderColor,
    bool? staticFilled,
    String? staticPipeDirection,
    String? staticPipeColor,
    double? staticPipeWidth,
    String? staticIconName,
    double? staticRotation,
    String? staticArrowDir,
    String? staticPanelTitle,
  }) {
    final copy = ScadaWidget(
      id: id,
      type: type,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      zero: zero ?? this.zero,
      span: span ?? this.span,
      offset: offset ?? this.offset,
      multiplier: multiplier ?? this.multiplier,
      unit: unit ?? this.unit,
      value: value ?? this.value,
      boolValue: boolValue ?? this.boolValue,
      currentState: currentState ?? this.currentState,
      dataSource: dataSource ?? this.dataSource,
      alarm: alarm ?? this.alarm,
      ledDualConfig: ledDualConfig ?? this.ledDualConfig,
      states: Map.from(states),
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      bgOpacity: bgOpacity ?? this.bgOpacity,
      bgTransparent: bgTransparent ?? this.bgTransparent,
      frameless: frameless ?? this.frameless,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastDataTime: lastDataTime ?? this.lastDataTime,
      animated: animated ?? this.animated,
      locked: locked ?? this.locked,
      zOrder: zOrder ?? this.zOrder,
      linkedPageId: linkedPageId ?? this.linkedPageId,
      boundTagId: boundTagId ?? this.boundTagId,
      calcFormula: calcFormula ?? this.calcFormula,
      calcInputTags: calcInputTags ?? List.from(this.calcInputTags),
      calcDisplayAs: calcDisplayAs ?? this.calcDisplayAs,
      calcRefreshMs: calcRefreshMs ?? this.calcRefreshMs,
      calcIsDigital: calcIsDigital ?? this.calcIsDigital,
      calcTrueLabel: calcTrueLabel ?? this.calcTrueLabel,
      calcFalseLabel: calcFalseLabel ?? this.calcFalseLabel,
      calcTrueColor: calcTrueColor ?? this.calcTrueColor,
      calcFalseColor: calcFalseColor ?? this.calcFalseColor,
      calcBlinkOnTrue: calcBlinkOnTrue ?? this.calcBlinkOnTrue,
      calcActiveSeconds: calcActiveSeconds ?? this.calcActiveSeconds,
      tableRows: tableRows ?? this.tableRows,
      tableCols: tableCols ?? this.tableCols,
      tableCells: tableCells ?? List.from(this.tableCells),
      tableHeaderColor: tableHeaderColor ?? this.tableHeaderColor,
      tableBorderColor: tableBorderColor ?? this.tableBorderColor,
      tableShowHeader: tableShowHeader ?? this.tableShowHeader,
      tableAlarmColoring: tableAlarmColoring ?? this.tableAlarmColoring,
      tableShowQualityIcon: tableShowQualityIcon ?? this.tableShowQualityIcon,
      pathDirection: pathDirection ?? this.pathDirection,
      pathFlowColor: pathFlowColor ?? this.pathFlowColor,
      pathSpeed: pathSpeed ?? this.pathSpeed,
      pathWidth: pathWidth ?? this.pathWidth,
      pathFlowing: pathFlowing ?? this.pathFlowing,
      pathReverse: pathReverse ?? this.pathReverse,
      pathLanes: pathLanes ?? this.pathLanes,
      pathDisplayText: pathDisplayText ?? this.pathDisplayText,
      spcUcl: spcUcl ?? this.spcUcl,
      spcLcl: spcLcl ?? this.spcLcl,
      spcTarget: spcTarget ?? this.spcTarget,
      trendPoints: trendPoints ?? this.trendPoints,
      staticText: staticText ?? this.staticText,
      staticFontSize: staticFontSize ?? this.staticFontSize,
      staticFontColor: staticFontColor ?? this.staticFontColor,
      staticBold: staticBold ?? this.staticBold,
      staticImageUrl: staticImageUrl ?? this.staticImageUrl,
      staticShapeType: staticShapeType ?? this.staticShapeType,
      staticShapeColor: staticShapeColor ?? this.staticShapeColor,
      staticShapeBorder: staticShapeBorder ?? this.staticShapeBorder,
      staticBorderColor: staticBorderColor ?? this.staticBorderColor,
      staticFilled: staticFilled ?? this.staticFilled,
      staticPipeDirection: staticPipeDirection ?? this.staticPipeDirection,
      staticPipeColor: staticPipeColor ?? this.staticPipeColor,
      staticPipeWidth: staticPipeWidth ?? this.staticPipeWidth,
      staticIconName: staticIconName ?? this.staticIconName,
      staticRotation: staticRotation ?? this.staticRotation,
      staticArrowDir: staticArrowDir ?? this.staticArrowDir,
      staticPanelTitle: staticPanelTitle ?? this.staticPanelTitle,
    );
    copy.minValue = minValue ?? this.minValue;
    copy.maxValue = maxValue ?? this.maxValue;
    return copy;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'zero': zero,
        'span': span,
        'offset': offset,
        'multiplier': multiplier,
        'unit': unit,
        'value': value,
        'boolValue': boolValue,
        'currentState': currentState,
        'dataSource': dataSource.toJson(),
        'alarm': alarm.toJson(),
        'ledDualConfig': ledDualConfig.toJson(),
        'states': states.map((k, v) => MapEntry(k, v.toJson())),
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'activeColor': activeColor,
        'inactiveColor': inactiveColor,
        'bgOpacity': bgOpacity,
        'bgTransparent': bgTransparent,
        'frameless': frameless,
        'connectionStatus': connectionStatus.name,
        'lastDataTime': lastDataTime?.toIso8601String(),
        'animated': animated,
        'locked': locked,
        'zOrder': zOrder,
        'linkedPageId': linkedPageId,
        'boundTagId': boundTagId,
        'minValue': minValue,
        'maxValue': maxValue,
        'calcFormula': calcFormula,
        'calcInputTags': calcInputTags,
        'calcDisplayAs': calcDisplayAs,
        'calcRefreshMs': calcRefreshMs,
        'calcIsDigital': calcIsDigital,
        'calcTrueLabel': calcTrueLabel,
        'calcFalseLabel': calcFalseLabel,
        'calcTrueColor': calcTrueColor,
        'calcFalseColor': calcFalseColor,
        'calcBlinkOnTrue': calcBlinkOnTrue,
        'calcActiveSeconds': calcActiveSeconds,
        'tableRows': tableRows,
        'tableCols': tableCols,
        'tableCells': tableCells,
        'tableHeaderColor': tableHeaderColor,
        'tableBorderColor': tableBorderColor,
        'tableShowHeader': tableShowHeader,
        'tableAlarmColoring': tableAlarmColoring,
        'tableShowQualityIcon': tableShowQualityIcon,
        'pathDirection': pathDirection,
        'pathFlowColor': pathFlowColor,
        'pathSpeed': pathSpeed,
        'pathWidth': pathWidth,
        'pathFlowing': pathFlowing,
        'pathReverse': pathReverse,
        'pathLanes': pathLanes,
        'pathDisplayText': pathDisplayText,
        'spcUcl': spcUcl,
        'spcLcl': spcLcl,
        'spcTarget': spcTarget,
        'trendPoints': trendPoints,
        'staticText': staticText,
        'staticFontSize': staticFontSize,
        'staticFontColor': staticFontColor,
        'staticBold': staticBold,
        'staticImageUrl': staticImageUrl,
        'staticShapeType': staticShapeType,
        'staticShapeColor': staticShapeColor,
        'staticShapeBorder': staticShapeBorder,
        'staticBorderColor': staticBorderColor,
        'staticFilled': staticFilled,
        'staticPipeDirection': staticPipeDirection,
        'staticPipeColor': staticPipeColor,
        'staticPipeWidth': staticPipeWidth,
        'staticIconName': staticIconName,
        'staticRotation': staticRotation,
        'staticArrowDir': staticArrowDir,
        'staticPanelTitle': staticPanelTitle,
      };

  factory ScadaWidget.fromJson(Map<String, dynamic> json) {
    final type = WidgetType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => WidgetType.gauge,
    );

    final w = ScadaWidget(
      id: json['id'],
      type: type,
      label: json['label'] ?? type.label,
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 100).toDouble(),
      height: (json['height'] ?? 100).toDouble(),
      zero: (json['zero'] ?? 0).toDouble(),
      span: (json['span'] ?? 100).toDouble(),
      offset: (json['offset'] ?? 0).toDouble(),
      multiplier: (json['multiplier'] ?? 1).toDouble(),
      unit: json['unit'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      boolValue: json['boolValue'] ?? false,
      currentState: json['currentState'],
      dataSource: json['dataSource'] != null
          ? DataSourceBinding.fromJson(json['dataSource'])
          : const DataSourceBinding(),
      alarm: json['alarm'] != null
          ? AlarmConfig.fromJson(json['alarm'])
          : const AlarmConfig(),
      ledDualConfig: json['ledDualConfig'] != null
          ? LedDualConfig.fromJson(json['ledDualConfig'])
          : const LedDualConfig(),
      states: json['states'] != null
          ? (json['states'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, StateConfig.fromJson(v)))
          : null,
      primaryColor: json['primaryColor'] ?? '#3B82F6',
      secondaryColor: json['secondaryColor'] ?? '#64748B',
      backgroundColor: json['backgroundColor'] ?? '#1E293B',
      textColor: json['textColor'] ?? '#E2E8F0',
      activeColor: json['activeColor'] ?? '#22C55E',
      inactiveColor: json['inactiveColor'] ?? '#EF4444',
      bgOpacity: (json['bgOpacity'] ?? 1.0).toDouble(),
      bgTransparent: json['bgTransparent'] ?? false,
      frameless: json['frameless'] ?? false,
      connectionStatus: ConnectionStatus.values.firstWhere(
        (e) => e.name == json['connectionStatus'],
        orElse: () => ConnectionStatus.unknown,
      ),
      lastDataTime: json['lastDataTime'] != null
          ? DateTime.parse(json['lastDataTime'])
          : null,
      animated: json['animated'] ?? false,
      locked: json['locked'] ?? false,
      zOrder: json['zOrder'] ?? 0,
      linkedPageId: json['linkedPageId'],
      boundTagId: json['boundTagId'],
      calcFormula: json['calcFormula'] ?? '',
      calcInputTags: json['calcInputTags'] != null ? List<String>.from(json['calcInputTags']) : null,
      calcDisplayAs: json['calcDisplayAs'] ?? 'digital',
      calcRefreshMs: json['calcRefreshMs'] ?? 1000,
      calcIsDigital: json['calcIsDigital'] ?? false,
      calcTrueLabel: json['calcTrueLabel'] ?? 'ON',
      calcFalseLabel: json['calcFalseLabel'] ?? 'OFF',
      calcTrueColor: json['calcTrueColor'] ?? '#22C55E',
      calcFalseColor: json['calcFalseColor'] ?? '#EF4444',
      calcBlinkOnTrue: json['calcBlinkOnTrue'] ?? false,
      calcActiveSeconds: (json['calcActiveSeconds'] ?? 0).toDouble(),
      tableRows: json['tableRows'] ?? 3,
      tableCols: json['tableCols'] ?? 3,
      tableCells: json['tableCells'] != null ? List<Map<String, dynamic>>.from((json['tableCells'] as List).map((c) => Map<String, dynamic>.from(c))) : null,
      tableHeaderColor: json['tableHeaderColor'] ?? '#334155',
      tableBorderColor: json['tableBorderColor'] ?? '#475569',
      tableShowHeader: json['tableShowHeader'] ?? true,
      tableAlarmColoring: json['tableAlarmColoring'] ?? true,
      tableShowQualityIcon: json['tableShowQualityIcon'] ?? true,
      pathDirection: json['pathDirection'] ?? 'horizontal',
      pathFlowColor: json['pathFlowColor'] ?? '#3B82F6',
      pathSpeed: (json['pathSpeed'] ?? 2.0).toDouble(),
      pathWidth: (json['pathWidth'] ?? 10).toDouble(),
      pathFlowing: json['pathFlowing'] ?? true,
      pathReverse: json['pathReverse'] ?? false,
      pathLanes: json['pathLanes'] ?? 1,
      pathDisplayText: json['pathDisplayText'] ?? '',
      spcUcl: (json['spcUcl'] ?? 80).toDouble(),
      spcLcl: (json['spcLcl'] ?? 20).toDouble(),
      spcTarget: (json['spcTarget'] ?? 50).toDouble(),
      trendPoints: json['trendPoints'] ?? 30,
      staticText: json['staticText'] ?? '',
      staticFontSize: (json['staticFontSize'] ?? 16).toDouble(),
      staticFontColor: json['staticFontColor'] ?? '#FFFFFF',
      staticBold: json['staticBold'] ?? false,
      staticImageUrl: json['staticImageUrl'] ?? '',
      staticShapeType: json['staticShapeType'] ?? 'rectangle',
      staticShapeColor: json['staticShapeColor'] ?? '#3B82F6',
      staticShapeBorder: (json['staticShapeBorder'] ?? 2).toDouble(),
      staticBorderColor: json['staticBorderColor'] ?? '#64748B',
      staticFilled: json['staticFilled'] ?? true,
      staticPipeDirection: json['staticPipeDirection'] ?? 'horizontal',
      staticPipeColor: json['staticPipeColor'] ?? '#64748B',
      staticPipeWidth: (json['staticPipeWidth'] ?? 8).toDouble(),
      staticIconName: json['staticIconName'] ?? 'star',
      staticRotation: (json['staticRotation'] ?? 0).toDouble(),
      staticArrowDir: json['staticArrowDir'] ?? 'right',
      staticPanelTitle: json['staticPanelTitle'] ?? 'Panel',
    );
    w.minValue = (json['minValue'] ?? 0).toDouble();
    w.maxValue = (json['maxValue'] ?? 100).toDouble();
    return w;
  }
}
