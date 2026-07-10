/// پروتکل‌های ارتباطی
enum TagProtocol { mqtt, modbusTcp, modbusRtu, opcua, simulation }

extension TagProtocolExt on TagProtocol {
  String get label {
    switch (this) {
      case TagProtocol.mqtt: return 'MQTT';
      case TagProtocol.modbusTcp: return 'Modbus TCP';
      case TagProtocol.modbusRtu: return 'Modbus RTU';
      case TagProtocol.opcua: return 'OPC UA';
      case TagProtocol.simulation: return 'Simulation';
    }
  }
}

/// نوع داده تگ
enum TagDataType { analog, digital, string_ }

extension TagDataTypeExt on TagDataType {
  String get label {
    switch (this) {
      case TagDataType.analog: return 'Analog';
      case TagDataType.digital: return 'Digital';
      case TagDataType.string_: return 'String';
    }
  }
}

/// کیفیت سیگنال
enum SignalQuality { good, bad, uncertain, unknown }

/// مدل اصلی تگ
class Tag {
  final String id;
  String name;
  String description;
  String group;
  String unit;
  TagDataType dataType;

  // محدوده مهندسی
  double minValue;
  double maxValue;

  // مقیاس (Raw → Engineering)
  double rawMin;
  double rawMax;
  double engMin;
  double engMax;

  // منبع داده
  TagProtocol protocol;
  Map<String, dynamic> protocolConfig;
  int pollInterval; // ms

  // آلارم
  bool alarmEnabled;
  double highAlarm;
  double lowAlarm;
  double highHighAlarm;
  double lowLowAlarm;

  // وضعیت
  bool isActive;
  double? lastValue;
  DateTime? lastUpdate;
  SignalQuality quality;

  // متا
  final String? createdBy;
  final DateTime? createdAt;

  Tag({
    required this.id,
    required this.name,
    this.description = '',
    this.group = 'Default',
    this.unit = '',
    this.dataType = TagDataType.analog,
    this.minValue = 0,
    this.maxValue = 100,
    this.rawMin = 0,
    this.rawMax = 65535,
    this.engMin = 0,
    this.engMax = 100,
    this.protocol = TagProtocol.simulation,
    Map<String, dynamic>? protocolConfig,
    this.pollInterval = 1000,
    this.alarmEnabled = false,
    this.highAlarm = 80,
    this.lowAlarm = 20,
    this.highHighAlarm = 95,
    this.lowLowAlarm = 5,
    this.isActive = true,
    this.lastValue,
    this.lastUpdate,
    this.quality = SignalQuality.unknown,
    this.createdBy,
    this.createdAt,
  }) : protocolConfig = protocolConfig ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'group': group,
    'unit': unit,
    'dataType': dataType.name,
    'minValue': minValue,
    'maxValue': maxValue,
    'rawMin': rawMin,
    'rawMax': rawMax,
    'engMin': engMin,
    'engMax': engMax,
    'protocol': protocol.name,
    'protocolConfig': protocolConfig,
    'pollInterval': pollInterval,
    'alarmEnabled': alarmEnabled,
    'highAlarm': highAlarm,
    'lowAlarm': lowAlarm,
    'highHighAlarm': highHighAlarm,
    'lowLowAlarm': lowLowAlarm,
    'isActive': isActive,
    'lastValue': lastValue,
    'lastUpdate': lastUpdate?.toIso8601String(),
    'quality': quality.name,
    'createdBy': createdBy,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id'],
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    group: json['group'] ?? 'Default',
    unit: json['unit'] ?? '',
    dataType: TagDataType.values.firstWhere((e) => e.name == json['dataType'], orElse: () => TagDataType.analog),
    minValue: (json['minValue'] ?? 0).toDouble(),
    maxValue: (json['maxValue'] ?? 100).toDouble(),
    rawMin: (json['rawMin'] ?? 0).toDouble(),
    rawMax: (json['rawMax'] ?? 65535).toDouble(),
    engMin: (json['engMin'] ?? 0).toDouble(),
    engMax: (json['engMax'] ?? 100).toDouble(),
    protocol: TagProtocol.values.firstWhere((e) => e.name == json['protocol'], orElse: () => TagProtocol.simulation),
    protocolConfig: json['protocolConfig'] != null ? Map<String, dynamic>.from(json['protocolConfig']) : {},
    pollInterval: json['pollInterval'] ?? 1000,
    alarmEnabled: json['alarmEnabled'] ?? false,
    highAlarm: (json['highAlarm'] ?? 80).toDouble(),
    lowAlarm: (json['lowAlarm'] ?? 20).toDouble(),
    highHighAlarm: (json['highHighAlarm'] ?? 95).toDouble(),
    lowLowAlarm: (json['lowLowAlarm'] ?? 5).toDouble(),
    isActive: json['isActive'] ?? true,
    lastValue: json['lastValue']?.toDouble(),
    lastUpdate: json['lastUpdate'] != null ? DateTime.tryParse(json['lastUpdate']) : null,
    quality: SignalQuality.values.firstWhere((e) => e.name == json['quality'], orElse: () => SignalQuality.unknown),
    createdBy: json['createdBy'],
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
  );

  /// تنظیمات پیش‌فرض هر پروتکل
  static Map<String, dynamic> defaultConfig(TagProtocol protocol) {
    switch (protocol) {
      case TagProtocol.mqtt:
        return {'broker': 'mqtt://localhost:1883', 'topic': '', 'qos': 0, 'username': '', 'password': '', 'useTls': false};
      case TagProtocol.modbusTcp:
        return {'host': '192.168.1.1', 'port': 502, 'unitId': 1, 'register': 0, 'registerType': 'holding', 'dataFormat': 'int16', 'byteOrder': 'AB'};
      case TagProtocol.modbusRtu:
        return {'serialPort': 'COM1', 'baudRate': 9600, 'parity': 'none', 'stopBits': 1, 'unitId': 1, 'register': 0, 'registerType': 'holding', 'dataFormat': 'int16'};
      case TagProtocol.opcua:
        return {'endpointUrl': 'opc.tcp://localhost:4840', 'nodeId': 'ns=2;s=Tag1', 'namespaceIndex': 2, 'securityMode': 'none', 'securityPolicy': 'none', 'username': '', 'password': ''};
      case TagProtocol.simulation:
        return {'pattern': 'random', 'min': 0, 'max': 100, 'period': 5000, 'noise': 5};
    }
  }
}

/// گروه تگ
class TagGroup {
  final String name;
  int count;
  TagGroup({required this.name, this.count = 0});
}
