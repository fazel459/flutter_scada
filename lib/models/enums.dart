// Enums for widget types, protocols, data sources, etc.

enum WidgetType {
  gauge,
  level,
  temperature,
  pressure,
  led,
  ledDual,
  switchWidget,
  graph,
  chart,
  verticalTank,
  horizontalTank,
  fan,
  motor,
  gateValve,
  controlValve,
  digitalDisplay,
  textDisplay,
  verticalBar,
  horizontalBar,
  relay,
  slider,
  statusIndicator,
  // ====== ویجت‌های گرافیکی (نمایشی - بدون داده) ======
  staticLabel,        // برچسب متنی
  staticImage,        // تصویر
  staticShape,        // شکل هندسی (مستطیل/دایره/خط)
  staticPipe,         // لوله (افقی/عمودی/زانویی)
  staticPanel,        // پنل/قاب گروه‌بندی
  staticIcon,         // آیکون نمایشی
  staticLine,         // خط اتصال
  staticArrow,        // فلش جهت‌دار
  // ====== ویجت محاسباتی ======
  calculated,         // ویجت محاسباتی با فرمول
  // ====== ویجت‌های فاز ۴ ======
  trendChart,         // نمودار تاریخچه (mini trend)
  spcChart,           // نمودار کنترل کیفیت آماری
  animatedPath,       // مسیر متحرک (جریان مایع/گاز در لوله)
  dataTable,          // جدول داده با اتصال تگ
}

enum ProtocolType {
  simulation,
  mqtt,
  modbusTcp,
}

enum ModbusRegisterType {
  holding,
  input,
  coil,
  discrete,
}

enum UserRole {
  viewer,
  designer,
  admin,
}

enum ConnectionStatus {
  connected,
  disconnected,
  unknown,
}

enum AlarmType {
  none,
  high,
  low,
  highHigh,
  lowLow,
  critical,
}

extension WidgetTypeExtension on WidgetType {
  String get label {
    switch (this) {
      case WidgetType.gauge:
        return 'Gauge';
      case WidgetType.level:
        return 'Level';
      case WidgetType.temperature:
        return 'Temperature';
      case WidgetType.pressure:
        return 'Pressure';
      case WidgetType.led:
        return 'LED';
      case WidgetType.ledDual:
        return 'LED Dual';
      case WidgetType.switchWidget:
        return 'Switch';
      case WidgetType.graph:
        return 'Graph';
      case WidgetType.chart:
        return 'Chart';
      case WidgetType.verticalTank:
        return 'Vertical Tank';
      case WidgetType.horizontalTank:
        return 'Horizontal Tank';
      case WidgetType.fan:
        return 'Fan';
      case WidgetType.motor:
        return 'Motor';
      case WidgetType.gateValve:
        return 'Gate Valve';
      case WidgetType.controlValve:
        return 'Control Valve';
      case WidgetType.digitalDisplay:
        return 'Digital Display';
      case WidgetType.textDisplay:
        return 'Text Display';
      case WidgetType.verticalBar:
        return 'Vertical Bar';
      case WidgetType.horizontalBar:
        return 'Horizontal Bar';
      case WidgetType.relay:
        return 'Relay Output';
      case WidgetType.slider:
        return 'Slider';
      case WidgetType.statusIndicator:
        return 'Status';
      case WidgetType.staticLabel:
        return 'Label';
      case WidgetType.staticImage:
        return 'Image';
      case WidgetType.staticShape:
        return 'Shape';
      case WidgetType.staticPipe:
        return 'Pipe';
      case WidgetType.staticPanel:
        return 'Panel';
      case WidgetType.staticIcon:
        return 'Icon';
      case WidgetType.staticLine:
        return 'Line';
      case WidgetType.staticArrow:
        return 'Arrow';
      case WidgetType.calculated:
        return 'Calculated';
      case WidgetType.trendChart:
        return 'Trend';
      case WidgetType.spcChart:
        return 'SPC Chart';
      case WidgetType.animatedPath:
        return 'Flow Path';
      case WidgetType.dataTable:
        return 'Data Table';
    }
  }

  /// آیا این ویجت داده‌ای از سرور دریافت می‌کند
  bool get isDataWidget {
    switch (this) {
      case WidgetType.staticLabel:
      case WidgetType.staticImage:
      case WidgetType.staticShape:
      case WidgetType.staticPipe:
      case WidgetType.staticPanel:
      case WidgetType.staticIcon:
      case WidgetType.staticLine:
      case WidgetType.staticArrow:
        return false;
      default:
        return true;
    }
  }

  bool get isCalculated => this == WidgetType.calculated;

  String get icon {
    switch (this) {
      case WidgetType.gauge:
        return '🔘';
      case WidgetType.level:
        return '📊';
      case WidgetType.temperature:
        return '🌡️';
      case WidgetType.pressure:
        return '⏲️';
      case WidgetType.led:
        return '💡';
      case WidgetType.ledDual:
        return '🚨';
      case WidgetType.switchWidget:
        return '🔲';
      case WidgetType.graph:
        return '📈';
      case WidgetType.chart:
        return '📉';
      case WidgetType.verticalTank:
        return '🛢️';
      case WidgetType.horizontalTank:
        return '🛢️';
      case WidgetType.fan:
        return '🌀';
      case WidgetType.motor:
        return '⚡';
      case WidgetType.gateValve:
        return '🔧';
      case WidgetType.controlValve:
        return '🎛️';
      case WidgetType.digitalDisplay:
        return '🔢';
      case WidgetType.textDisplay:
        return '📝';
      case WidgetType.verticalBar:
        return '📊';
      case WidgetType.horizontalBar:
        return '📊';
      case WidgetType.relay:
        return '🔌';
      case WidgetType.slider:
        return '🎚️';
      case WidgetType.statusIndicator:
        return '🚦';
      case WidgetType.staticLabel:
        return '🏷️';
      case WidgetType.staticImage:
        return '🖼️';
      case WidgetType.staticShape:
        return '⬜';
      case WidgetType.staticPipe:
        return '🔗';
      case WidgetType.staticPanel:
        return '🪟';
      case WidgetType.staticIcon:
        return '⭐';
      case WidgetType.staticLine:
        return '➖';
      case WidgetType.staticArrow:
        return '➡️';
      case WidgetType.calculated:
        return '🔣';
      case WidgetType.trendChart:
        return '📉';
      case WidgetType.spcChart:
        return '📐';
      case WidgetType.animatedPath:
        return '〰️';
      case WidgetType.dataTable:
        return '📋';
    }
  }
}

extension ProtocolTypeExtension on ProtocolType {
  String get label {
    switch (this) {
      case ProtocolType.simulation:
        return 'Simulation';
      case ProtocolType.mqtt:
        return 'MQTT';
      case ProtocolType.modbusTcp:
        return 'Modbus TCP';
    }
  }
}

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.viewer:
        return 'Viewer';
      case UserRole.designer:
        return 'Designer';
      case UserRole.admin:
        return 'Admin';
    }
  }

  bool get canDesign =>
      this == UserRole.designer || this == UserRole.admin;
  bool get isAdmin => this == UserRole.admin;
}
