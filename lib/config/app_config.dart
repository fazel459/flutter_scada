class AppConfig {
  // Backend API URL
  // For web: use 'http://localhost:3000/api'
  // For Android emulator: use 'http://10.0.2.2:3000/api'
  // For iOS simulator: use 'http://localhost:3000/api'
  // For physical device: use actual server IP like 'http://192.168.1.100:3000/api'
  //static const String apiBaseUrl = 'http://localhost:3000/api';
	static const String apiBaseUrl = 'https://scada-backend-br1t.onrender.com/api';
  // MQTT default config
  static const String defaultMqttBroker = 'ws://broker.hivemq.com:8000/mqtt';
  static const int defaultMqttPort = 8000;

  // Modbus default config
  static const String defaultModbusHost = '127.0.0.1';
  static const int defaultModbusPort = 502;

  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
