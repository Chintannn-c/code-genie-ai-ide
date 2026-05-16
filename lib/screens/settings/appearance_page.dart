import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';
import '../../widgets/settings/settings_slider.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  int _selectedTheme = 0;
  int _selectedAccent = 0;
  double _blurIntensity = 0.7;
  double _animationSpeed = 0.5;
  bool _particles = true;
  bool _reduceMotion = false;

  static const _themes = [
    _ThemeOption('Dark', Color(0xFF0B0B0C), Color(0xFF1E1E21), Icons.dark_mode_rounded),
    _ThemeOption('Midnight', Color(0xFF0A0E27), Color(0xFF131842), Icons.nightlight_round),
    _ThemeOption('Cyberpunk', Color(0xFF0D0208), Color(0xFF1A0A2E), Icons.electric_bolt_rounded),
    _ThemeOption('Glass Aurora', Color(0xFF0C1222), Color(0xFF162447), Icons.blur_on_rounded),
    _ThemeOption('Light', Color(0xFFF1F5F9), Color(0xFFFFFFFF), Icons.light_mode_rounded),
  ];

  static const _accents = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final tp = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Theme Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('THEME MODE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _themes.length,
                  itemBuilder: (context, index) {
                    final theme = _themes[index];
                    final isActive = _selectedTheme == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedTheme = index);
                        // Toggle between dark and light for the actual theme
                        if (index == 4 && isDark) tp.toggleTheme();
                        if (index != 4 && !isDark) tp.toggleTheme();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [theme.bg, theme.surface],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isActive
                                ? _accents[_selectedAccent].withValues(alpha: 0.6)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? [BoxShadow(color: _accents[_selectedAccent].withValues(alpha: 0.2), blurRadius: 16)]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(theme.icon, size: 28,
                              color: isActive ? _accents[_selectedAccent] : (index == 4 ? Colors.black54 : Colors.white54)),
                            const SizedBox(height: 8),
                            Text(
                              theme.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: isActive ? _accents[_selectedAccent] : (index == 4 ? Colors.black54 : Colors.white54),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(height: 4),
                              Container(width: 20, height: 3,
                                decoration: BoxDecoration(
                                  color: _accents[_selectedAccent],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Accent Color
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('ACCENT COLOR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_accents.length, (index) {
                      final isActive = _selectedAccent == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAccent = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: isActive ? 36 : 30,
                          height: isActive ? 36 : 30,
                          decoration: BoxDecoration(
                            color: _accents[index],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.transparent,
                              width: isActive ? 3 : 0,
                            ),
                            boxShadow: isActive
                                ? [BoxShadow(color: _accents[index].withValues(alpha: 0.5), blurRadius: 12)]
                                : [],
                          ),
                          child: isActive
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // Visual Effects
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('VISUAL EFFECTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    SettingsSlider(
                      label: 'Blur Intensity',
                      subtitle: 'Glassmorphism blur strength',
                      icon: Icons.blur_on_rounded,
                      value: _blurIntensity, min: 0, max: 1, divisions: 10,
                      onChanged: (v) => setState(() => _blurIntensity = v),
                      valueLabel: (v) => v <= 0.3 ? 'Subtle' : v >= 0.7 ? 'Heavy' : 'Medium',
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    SettingsSlider(
                      label: 'Animation Speed',
                      subtitle: 'Controls transition duration',
                      icon: Icons.speed_rounded,
                      value: _animationSpeed, min: 0, max: 1, divisions: 10,
                      onChanged: (v) => setState(() => _animationSpeed = v),
                      valueLabel: (v) => v <= 0.3 ? 'Slow' : v >= 0.7 ? 'Fast' : 'Normal',
                      accentColor: const Color(0xFFA855F7),
                    ),
                    SettingsToggle(
                      label: 'Particle Effects',
                      subtitle: 'Floating ambient particles in backgrounds',
                      icon: Icons.auto_awesome_rounded,
                      value: _particles,
                      onChanged: (v) => setState(() => _particles = v),
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    SettingsToggle(
                      label: 'Reduce Motion',
                      subtitle: 'Minimize animations for accessibility',
                      icon: Icons.accessibility_new_rounded,
                      value: _reduceMotion,
                      onChanged: (v) => setState(() => _reduceMotion = v),
                      accentColor: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 16),
          Text('Appearance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  final String name;
  final Color bg;
  final Color surface;
  final IconData icon;
  const _ThemeOption(this.name, this.bg, this.surface, this.icon);
}
