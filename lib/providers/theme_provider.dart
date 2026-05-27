import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme provider for dark/light mode toggle and multiple style skins.
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _skinKey = 'appearance_setting_selected_theme';

  static const primaryColor = Color(0xFF8B8BF5); // Muted indigo accent
  static const accentColor = Color(0xFF8B8BF5);  // Same muted indigo
  static const darkBg = Color(0xFF0D0D0D);      // Flat dark canvas
  static const darkSurface = Color(0xFF141414); // Flat dark surface
  static const darkText = Color(0xFFF5F5F5);    // Clean white text

  ThemeMode _themeMode = ThemeMode.dark;
  int _selectedTheme = 0;

  ThemeMode get themeMode => _themeMode;
  int get selectedTheme => _selectedTheme;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeData get currentTheme {
    switch (_selectedTheme) {
      case 1:
        return midnightTheme;
      case 2:
        return cyberpunkTheme;
      case 3:
        return glassAuroraTheme;
      case 4:
        return lightTheme;
      default:
        return darkTheme;
    }
  }

  ThemeProvider() {
    _loadTheme();
  }

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: darkSurface,
      onSurface: darkText,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
    ),
  );

  ThemeData get midnightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0A0D1A),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF5865F2),
      secondary: Color(0xFF5865F2),
      surface: Color(0xFF12162B),
      onSurface: Color(0xFFF0F4FF),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0D1A),
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5865F2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
    ),
  );

  ThemeData get cyberpunkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F0A15),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFEC4899),
      surface: Color(0xFF171120),
      onSurface: Color(0xFFFAD4FF),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0A15),
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEC4899),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
    ),
  );

  ThemeData get glassAuroraTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0C101B),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF06B6D4),
      secondary: Color(0xFF06B6D4),
      surface: Color(0xFF141A29),
      onSurface: Color(0xFFE2E8F0),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0C101B),
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
    ),
  );

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF6366F1),
      surface: Colors.white,
      onSurface: Color(0xFF0A0A0A),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
  );

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTheme = prefs.getInt(_skinKey) ?? 0;
    final isDark = prefs.getBool(_themeKey) ?? (_selectedTheme != 4);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setThemeIndex(int index) async {
    _selectedTheme = index;
    _themeMode = (index == 4) ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skinKey, index);
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    _selectedTheme = isDark ? 0 : 4;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    await prefs.setInt(_skinKey, _selectedTheme);
    notifyListeners();
  }
}
