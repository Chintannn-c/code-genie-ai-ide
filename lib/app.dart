import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/chat_screen.dart';

/// Root application widget.
class CodeAssistApp extends StatelessWidget {
  const CodeAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'CodeAssist AI',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const ChatScreen(),
        );
      },
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF06B6D4),
        surface: Color(0xFF161B22),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2430),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAFBFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6366F1),
        secondary: Color(0xFF06B6D4),
        surface: Color(0xFFF6F8FA),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
