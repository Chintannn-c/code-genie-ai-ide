import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/orchestration_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/session_provider.dart';

import 'services/notification_service.dart';
import 'providers/notification_provider.dart';
import 'providers/planning_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint('🚀 Starting App Initialization...');
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Notification Service (Hive + Local Notifications)
    final notificationService = NotificationService();
    await notificationService.init();
    
    debugPrint('✅ All services initialized');
  } catch (e) {
    debugPrint('⚠️ Initialization issue (continuing anyway): $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlanningProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SessionProvider>(
          create: (_) => SessionProvider(),
          update: (_, auth, sessions) => sessions!..setToken(auth.user?.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!
            ..setUserId(auth.user?.userId, auth.user?.token)
            ..onSessionExpired(() {
              auth.triggerSessionExpiry();
            }),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrchestrationProvider>(
          create: (_) => OrchestrationProvider(),
          update: (_, auth, orch) {
            orch!.setToken(auth.user?.token);
            if (auth.status == AuthStatus.authenticated) {
              orch.startPolling();
            } else {
              orch.stopPolling();
            }
            return orch;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) {
            if (auth.status == AuthStatus.authenticated && auth.user != null) {
              NotificationService().connect(auth.user!.userId, auth.user!.token);
              notifications!.updateAuth(auth.user!.userId, auth.user!.token, auth);
            } else if (auth.status == AuthStatus.unauthenticated) {
              NotificationService().disconnect();
            }
            return notifications!;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _splashCompleted = false;

  @override
  void initState() {
    super.initState();
    _startSplashTimer();
  }

  void _startSplashTimer() {
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() {
          _splashCompleted = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Code Genie',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Inter',
        colorSchemeSeed: const Color(0xFF6366F1),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        colorSchemeSeed: const Color(0xFF818CF8),
        scaffoldBackgroundColor: const Color(0xFF020617), // Deep space black
        cardColor: const Color(0xFF0F172A), // Slate card
        canvasColor: const Color(0xFF020617),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _splashCompleted && authProvider.status != AuthStatus.uninitialized
            ? _getHome(authProvider)
            : const SplashScreen(key: ValueKey('splash')),
      ),
    );
  }

  Widget _getHome(AuthProvider auth) {
    switch (auth.status) {
      case AuthStatus.authenticated:
        return const ChatScreen(key: ValueKey('chat'));
      case AuthStatus.authenticating:
      case AuthStatus.unauthenticated:
        return const LoginScreen(key: ValueKey('login'));
      case AuthStatus.uninitialized:
        return const SplashScreen(key: ValueKey('splash_uninit'));
    }
  }
}
