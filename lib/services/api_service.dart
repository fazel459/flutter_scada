import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/page_model.dart';
import '../models/alarm_model.dart';

class ApiService {
  // static const String baseUrl = 'https://scada-backend-br1t.onrender.com/api';
    static const String baseUrl = 'http://localhost:3000/api';
  // For emulator use 10.0.2.2, for web use localhost

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  String? _token;
  String? get token => _token;

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  // =================== AUTH ===================
  Future<AuthResponse> login(String username, String password) async {
    final res = await _dio.post('/auth/login',
        data: {'username': username, 'password': password});
    return AuthResponse.fromJson(res.data);
  }

  Future<AuthResponse> register(String username, String email, String password,
      String? displayName) async {
    final res = await _dio.post('/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        });
    return AuthResponse.fromJson(res.data);
  }

  Future<User> getMe() async {
    final res = await _dio.get('/auth/me');
    return User.fromJson(res.data['user']);
  }

  // =================== PAGES ===================
  Future<List<PageSummary>> getPages() async {
    final res = await _dio.get('/pages');
    final List<dynamic> pages = res.data['pages'];
    return pages.map((p) => PageSummary.fromJson(p)).toList();
  }

  Future<ScadaPage> getPage(String id) async {
    final res = await _dio.get('/pages/$id');
    return ScadaPage.fromJson(res.data['page']);
  }

  Future<String> createPage(Map<String, dynamic> data) async {
    final res = await _dio.post('/pages', data: data);
    return res.data['id'];
  }

  Future<void> updatePage(String id, Map<String, dynamic> data) async {
    await _dio.put('/pages/$id', data: data);
  }

  Future<void> deletePage(String id) async {
    await _dio.delete('/pages/$id');
  }

  // =================== ALARMS ===================
  Future<List<AlarmLog>> getAlarms({String? pageId, int limit = 100}) async {
    final query = <String, dynamic>{'limit': limit};
    if (pageId != null) query['pageId'] = pageId;
    final res = await _dio.get('/alarms', queryParameters: query);
    final List<dynamic> alarms = res.data['alarms'];
    return alarms.map((a) => AlarmLog.fromJson(a)).toList();
  }

  Future<void> createAlarm(Map<String, dynamic> data) async {
    await _dio.post('/alarms', data: data);
  }

  Future<void> acknowledgeAlarm(int alarmId) async {
    await _dio.post('/alarms/acknowledge', data: {'alarmId': alarmId});
  }

  // =================== DATA SOURCES ===================
  Future<List<Map<String, dynamic>>> getDataSources() async {
    final res = await _dio.get('/datasources');
    final List<dynamic> sources = res.data['sources'];
    return sources.map((s) => s as Map<String, dynamic>).toList();
  }

  Future<String> createDataSource(Map<String, dynamic> data) async {
    final res = await _dio.post('/datasources', data: data);
    return res.data['id'];
  }

  Future<void> deleteDataSource(String id) async {
    await _dio.delete('/datasources', data: {'id': id});
  }

  // =================== ADMIN ===================
  Future<List<User>> getUsers() async {
    final res = await _dio.get('/admin/users');
    final List<dynamic> users = res.data['users'];
    return users.map((u) => User.fromJson(u)).toList();
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _dio.put('/admin/users', data: {'userId': userId, ...data});
  }

  // =================== SIMULATED DATA ===================
  Future<Map<String, dynamic>> getSimulatedData(List<String> ids) async {
    final res = await _dio.get('/data/simulate', queryParameters: {'ids': ids.join(',')});
    return res.data;
  }

  // =================== GENERIC METHODS ===================
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get(path, queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    final res = await _dio.post(path, data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> data) async {
    final res = await _dio.put(path, data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> del(String path) async {
    final res = await _dio.delete(path);
    return res.data;
  }
}
