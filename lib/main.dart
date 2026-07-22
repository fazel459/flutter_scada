import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_scada/screens/main_shell.dart';
import 'package:flutter_scada/utils/persian-datetime-picker/lib/persian_datetime_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/providers.dart';
import 'screens/auth_screen.dart';
import 'models/user_model.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('scada_token');
  final userJson = prefs.getString('scada_user');

  String? initialToken;
  User? initialUser;

  //برای ویندوز
  // await windowManager.waitUntilReadyToShow(
  //   const WindowOptions(
  //     size: Size(1400, 850),
  //     minimumSize: Size(1100, 700),
  //     title: 'سیستم SCADA',
  //   ),
  //   () async {
  //     await windowManager.show();
  //     await windowManager.focus();
  //   },
  // );
  if (token != null && userJson != null) {
    try {
      initialToken = token;
      initialUser = User.fromJson(jsonDecode(userJson));
    } catch (_) {
      // Invalid stored session
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (initialToken != null && initialUser != null)
          _sessionOverride.overrideWith(
              (ref) => SessionData(token: initialToken!, user: initialUser!)),
      ],
      child: const MyApp(),
    ),
  );
}

class SessionData {
  final String token;
  final User user;
  const SessionData({required this.token, required this.user});
}

final _sessionOverride = Provider<SessionData?>((ref) => null);

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = ref.read(_sessionOverride);
    if (session != null) {
      ref.read(authProvider.notifier).setSession(session.user, session.token);
      // Verify token validity
      await ref.read(authProvider.notifier).checkAuth();
      if (ref.read(authProvider).user != null) {
        await ref.read(pagesProvider.notifier).loadPages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'SCADA System',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale("fa", "IR"),
        Locale("en", "US"),
      ],
      localizationsDelegates: const [
        PersianMaterialLocalizations.delegate,
        PersianCupertinoLocalizations.delegate,
      ],
      // theme: AppTheme.darkTheme,
      // builder: (context, child) {
      //   return Directionality(
      //     textDirection: TextDirection.rtl,
      //     child: child!,
      //   );
      // },
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
      ),
      // home :const ReportScreen(),
      home: !authState.isAuthenticated ? const AuthScreen() : const MainShell(),
    );
  }
}
