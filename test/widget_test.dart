// This is a unit test suite for the ThemeProvider, validating theme switching logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_coding/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider Tests', () {
    test('Initial mode should be dark', () async {
      final provider = ThemeProvider();
      // Initially, before SharedPreferences load finishes, it defaults to ThemeMode.dark
      expect(provider.isDark, isTrue);
    });

    test('toggleTheme switches theme mode', () async {
      final provider = ThemeProvider();
      
      // Toggle to light theme
      await provider.toggleTheme();
      expect(provider.isDark, isFalse);

      // Toggle back to dark theme
      await provider.toggleTheme();
      expect(provider.isDark, isTrue);
    });
  });
}
