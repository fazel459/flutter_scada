import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/page_model.dart';
import '../models/alarm_model.dart';
import '../models/widget_model.dart';
import '../models/template_model.dart';
import '../models/tag_model.dart';
import '../models/enums.dart';
import '../services/api_service.dart';

const String _tokenKey = 'scada_token';
const String _userKey = 'scada_user';

// =================== API SERVICE ===================
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// =================== AUTH ===================
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.token, this.isLoading = false, this.error});

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null && token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;

  AuthNotifier(this._api) : super(const AuthState());

  Future<void> _persistSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.login(username, password);
      _api.setToken(res.token);
      await _persistSession(res.token, res.user);
      state = state.copyWith(user: res.user, token: res.token, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register(String username, String email, String password, String? displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.register(username, email, password, displayName);
      _api.setToken(res.token);
      await _persistSession(res.token, res.user);
      state = state.copyWith(user: res.user, token: res.token, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> checkAuth() async {
    if (state.token == null) return;
    try {
      final user = await _api.getMe();
      state = state.copyWith(user: user);
    } catch (e) {
      _api.setToken(null);
      state = const AuthState();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _api.setToken(null);
    state = const AuthState();
  }

  void setSession(User user, String token) {
    _api.setToken(token);
    state = state.copyWith(user: user, token: token);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AuthNotifier(api);
});

// =================== PAGES ===================
class PagesState {
  final List<PageSummary> pages;
  final bool isLoading;
  final String? error;

  const PagesState({this.pages = const [], this.isLoading = false, this.error});

  PagesState copyWith({List<PageSummary>? pages, bool? isLoading, String? error}) {
    return PagesState(
      pages: pages ?? this.pages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PagesNotifier extends StateNotifier<PagesState> {
  final ApiService _api;

  PagesNotifier(this._api) : super(const PagesState());

  Future<void> loadPages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pages = await _api.getPages();
      state = state.copyWith(pages: pages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<String> createPage(String title) async {
    final id = await _api.createPage({'title': title});
    await loadPages();
    return id;
  }

  Future<void> deletePage(String id) async {
    await _api.deletePage(id);
    await loadPages();
  }
}

final pagesProvider = StateNotifierProvider<PagesNotifier, PagesState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return PagesNotifier(api);
});

// =================== CURRENT PAGE (DESIGNER/VIEWER) ===================
class CurrentPageNotifier extends StateNotifier<ScadaPage?> {
  final ApiService _api;

  CurrentPageNotifier(this._api) : super(null);

  Future<void> loadPage(String id) async {
    final page = await _api.getPage(id);
    state = page;
  }

  void setPage(ScadaPage page) {
    state = page;
  }

  void addWidget(ScadaWidget widget) {
    if (state == null) return;
    state = state!.copyWith(widgets: [...state!.widgets, widget]);
  }

  void updateWidget(ScadaWidget updated) {
    if (state == null) return;
    state = state!.copyWith(
      widgets: state!.widgets.map((w) => w.id == updated.id ? updated : w).toList(),
    );
  }

  void removeWidget(String id) {
    if (state == null) return;
    state = state!.copyWith(
      widgets: state!.widgets.where((w) => w.id != id).toList(),
    );
  }

  void updatePage(ScadaPage page) {
    state = page;
  }

  Future<void> save() async {
    if (state == null) return;
    await _api.updatePage(state!.id, state!.toSaveJson());
  }
}

final currentPageProvider = StateNotifierProvider<CurrentPageNotifier, ScadaPage?>((ref) {
  final api = ref.watch(apiServiceProvider);
  return CurrentPageNotifier(api);
});

// =================== WIDGET SELECTION ===================
final selectedWidgetIdProvider = StateProvider<String?>((ref) => null);

final selectedWidgetProvider = Provider<ScadaWidget?>((ref) {
  final page = ref.watch(currentPageProvider);
  final id = ref.watch(selectedWidgetIdProvider);
  if (page == null || id == null) return null;
  try {
    return page.widgets.firstWhere((w) => w.id == id);
  } catch (_) {
    return null;
  }
});

// =================== DESIGN MODE ===================
final designModeProvider = StateProvider<bool>((ref) => false);

// =================== SELECTED PALETTE WIDGET (tap-to-place) ===================
final selectedPaletteTypeProvider = StateProvider<WidgetType?>((ref) => null);

// =================== PANELS VISIBILITY ===================
final panelsVisibleProvider = StateProvider<Map<String, bool>>((ref) => {
  'widgetPalette': true,
  'propertyPanel': true,
  'alarmPanel': false,
  'adminPanel': false,
});

// =================== THEME ===================
final currentThemeProvider = StateProvider<String>((ref) => 'dark');

// =================== ALARMS ===================
class AlarmState {
  final List<AlarmLog> alarms;
  final bool isLoading;

  const AlarmState({this.alarms = const [], this.isLoading = false});

  AlarmState copyWith({List<AlarmLog>? alarms, bool? isLoading}) {
    return AlarmState(
      alarms: alarms ?? this.alarms,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get unacknowledged => alarms.where((a) => !a.acknowledged).length;
}

class AlarmNotifier extends StateNotifier<AlarmState> {
  final ApiService _api;
  final List<AlarmLog> _localAlarms = [];

  AlarmNotifier(this._api) : super(const AlarmState());

  Future<void> loadAlarms({String? pageId}) async {
    state = state.copyWith(isLoading: true);
    try {
      final alarms = await _api.getAlarms(pageId: pageId);
      state = state.copyWith(alarms: [..._localAlarms, ...alarms], isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void addLocalAlarm(AlarmLog alarm) {
    _localAlarms.insert(0, alarm);
    state = state.copyWith(alarms: [..._localAlarms, ...state.alarms]);
  }

  Future<void> acknowledgeAlarm(int alarmId) async {
    // Find in local alarms
    final localIdx = _localAlarms.indexWhere((a) => a.id == alarmId);
    if (localIdx != -1) {
      _localAlarms[localIdx] = _localAlarms[localIdx].copyWith(acknowledged: true);
      state = state.copyWith(alarms: [..._localAlarms, ...state.alarms.where((a) => a.id != alarmId)]);
      return;
    }

    try {
      await _api.acknowledgeAlarm(alarmId);
      state = state.copyWith(
        alarms: state.alarms.map((a) => a.id == alarmId ? a.copyWith(acknowledged: true) : a).toList(),
      );
    } catch (_) {}
  }
}

final alarmProvider = StateNotifierProvider<AlarmNotifier, AlarmState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AlarmNotifier(api);
});

// =================== ADMIN USERS ===================
class AdminUsersState {
  final List<User> users;
  final bool isLoading;

  const AdminUsersState({this.users = const [], this.isLoading = false});

  AdminUsersState copyWith({List<User>? users, bool? isLoading}) {
    return AdminUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AdminUsersNotifier extends StateNotifier<AdminUsersState> {
  final ApiService _api;

  AdminUsersNotifier(this._api) : super(const AdminUsersState());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _api.getUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _api.updateUser(userId, data);
      await loadUsers();
    } catch (_) {}
  }
}

final adminUsersProvider = StateNotifierProvider<AdminUsersNotifier, AdminUsersState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AdminUsersNotifier(api);
});

// =================== SERVER TIME ===================
final serverTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

// =================== WIDGET TEMPLATES ===================
class TemplateNotifier extends StateNotifier<List<WidgetTemplate>> {
  TemplateNotifier() : super([]);

  void addTemplate(WidgetTemplate template) {
    state = [...state, template];
  }

  void removeTemplate(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void loadTemplates(List<WidgetTemplate> templates) {
    state = templates;
  }
}

final templateProvider = StateNotifierProvider<TemplateNotifier, List<WidgetTemplate>>((ref) {
  return TemplateNotifier();
});

// =================== MULTI-SELECT (برای ساخت تمپلت) ===================
final multiSelectModeProvider = StateProvider<bool>((ref) => false);
final multiSelectedIdsProvider = StateProvider<Set<String>>((ref) => {});

// =================== GRID / SNAP ===================
final gridEnabledProvider = StateProvider<bool>((ref) => false);
final gridSizeProvider = StateProvider<double>((ref) => 20);
final snapToGridProvider = StateProvider<bool>((ref) => true);

// =================== SMART GUIDES ===================
final smartGuidesEnabledProvider = StateProvider<bool>((ref) => true);

class SmartGuideLines {
  final List<double> verticalLines;  // خطوط عمودی (x)
  final List<double> horizontalLines; // خطوط افقی (y)
  final List<double> centerVertical;  // خطوط مرکزی عمودی
  final List<double> centerHorizontal; // خطوط مرکزی افقی

  const SmartGuideLines({
    this.verticalLines = const [],
    this.horizontalLines = const [],
    this.centerVertical = const [],
    this.centerHorizontal = const [],
  });

  bool get hasAny => verticalLines.isNotEmpty || horizontalLines.isNotEmpty || centerVertical.isNotEmpty || centerHorizontal.isNotEmpty;
}

final activeGuidesProvider = StateProvider<SmartGuideLines>((ref) => const SmartGuideLines());

// =================== UNDO / REDO ===================
class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  UndoRedoNotifier() : super(UndoRedoState());

  void pushState(List<Map<String, dynamic>> widgetsJson) {
    state = state.push(widgetsJson);
  }

  List<Map<String, dynamic>>? undo() {
    final result = state.undo();
    if (result != null) state = result.state;
    return result?.data;
  }

  List<Map<String, dynamic>>? redo() {
    final result = state.redo();
    if (result != null) state = result.state;
    return result?.data;
  }

  bool get canUndo => state.canUndo;
  bool get canRedo => state.canRedo;
}

class UndoRedoState {
  final List<List<Map<String, dynamic>>> history;
  final int index;

  UndoRedoState({this.history = const [], this.index = -1});

  bool get canUndo => index > 0;
  bool get canRedo => index < history.length - 1;

  UndoRedoState push(List<Map<String, dynamic>> data) {
    final newHistory = history.sublist(0, index + 1)..add(data);
    // حداکثر 50 مرحله
    if (newHistory.length > 50) newHistory.removeAt(0);
    return UndoRedoState(history: newHistory, index: newHistory.length - 1);
  }

  _UndoResult? undo() {
    if (!canUndo) return null;
    final newState = UndoRedoState(history: history, index: index - 1);
    return _UndoResult(state: newState, data: history[index - 1]);
  }

  _UndoResult? redo() {
    if (!canRedo) return null;
    final newState = UndoRedoState(history: history, index: index + 1);
    return _UndoResult(state: newState, data: history[index + 1]);
  }
}

class _UndoResult {
  final UndoRedoState state;
  final List<Map<String, dynamic>> data;
  _UndoResult({required this.state, required this.data});
}

final undoRedoProvider = StateNotifierProvider<UndoRedoNotifier, UndoRedoState>((ref) {
  return UndoRedoNotifier();
});
