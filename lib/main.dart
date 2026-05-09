import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

import 'services/notification_service.dart';
import 'providers/notification_provider.dart';
import 'providers/planning_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Notification Service (Hive + Local Notifications)
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlanningProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..setUserId(auth.user?.userId, auth.user?.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) {
            if (auth.status == AuthStatus.authenticated && auth.user != null) {
              NotificationService().connect(auth.user!.userId, auth.user!.token);
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        colorSchemeSeed: const Color(0xFF6366F1),
        scaffoldBackgroundColor: Colors.black,
        cardColor: const Color(0xFF111111),
      ),
      home: _getHome(authProvider),
    );
  }

  Widget _getHome(AuthProvider auth) {
    switch (auth.status) {
      case AuthStatus.authenticated:
        return const ChatScreen();
      case AuthStatus.authenticating:
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.uninitialized:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }
}
