import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';
import '../../widgets/settings/settings_slider.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static const _fonts = ['JetBrains Mono', 'Fira Code', 'Cascadia Code', 'SF Mono', 'Source Code Pro'];
  static const _codePreview = '''
void main() {
  final genie = CodeGenie();
  genie.initialize();
  
  print('Hello, Engineer! 🚀');
  
  for (var i = 0; i < 10; i++) {
    genie.generate(prompt: i);
  }
}''';

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final sp = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Live Code Preview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GlassCard(
                  glowColor: const Color(0xFF10B981),
                  glowIntensity: 0.08,
                  padding: const EdgeInsets.all(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.7), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.7), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.7), shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Text('main.dart', style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black38,
                            )),
                            const Spacer(),
                            Text('LIVE PREVIEW', style: GoogleFonts.plusJakartaSans(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981), letterSpacing: 1,
                            )),
                          ],
                        ),
                      ),
                      // Code area
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _codePreview,
                          style: GoogleFonts.getFont(
                            _fonts[sp.selectedFont],
                            fontSize: sp.fontSize,
                            height: 1.6,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Font Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('FONT FAMILY',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _fonts.length,
                  itemBuilder: (context, index) {
                    final isActive = sp.selectedFont == index;
                    return GestureDetector(
                      onTap: () => sp.updateEditorSettings(selectedFont: index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
                          ),
                        ),
                        child: Text(
                          _fonts[index],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: isActive ? const Color(0xFF10B981) : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            ),

            // Editor Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('EDITOR CONTROLS',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    SettingsSlider(
                      label: 'Font Size', icon: Icons.format_size_rounded,
                      value: sp.fontSize, min: 10, max: 24, divisions: 14,
                      onChanged: (v) => sp.updateEditorSettings(fontSize: v),
                      valueLabel: (v) => '${v.toInt()}px',
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsSlider(
                      label: 'Tab Size', icon: Icons.space_bar_rounded,
                      value: sp.tabSize.toDouble(), min: 2, max: 8, divisions: 3,
                      onChanged: (v) => sp.updateEditorSettings(tabSize: v.toInt()),
                      valueLabel: (v) => '${v.toInt()} spaces',
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsToggle(label: 'Auto Save', subtitle: 'Save files automatically',
                      icon: Icons.save_rounded, value: sp.autoSave,
                      onChanged: (v) => sp.updateEditorSettings(autoSave: v), accentColor: const Color(0xFF10B981)),
                    SettingsToggle(label: 'Word Wrap', subtitle: 'Wrap long lines',
                      icon: Icons.wrap_text_rounded, value: sp.wordWrap,
                      onChanged: (v) => sp.updateEditorSettings(wordWrap: v), accentColor: const Color(0xFF06B6D4)),
                    SettingsToggle(label: 'Minimap', subtitle: 'Show code minimap sidebar',
                      icon: Icons.map_rounded, value: sp.minimap,
                      onChanged: (v) => sp.updateEditorSettings(minimap: v), accentColor: const Color(0xFFF59E0B)),
                    SettingsToggle(label: 'Vim Mode', subtitle: 'Enable vim keybindings',
                      icon: Icons.terminal_rounded, value: sp.vimMode,
                      onChanged: (v) => sp.updateEditorSettings(vimMode: v), accentColor: const Color(0xFFEF4444)),
                    SettingsToggle(label: 'AI Inline Suggestions', subtitle: 'Copilot-style completions',
                      icon: Icons.auto_fix_high_rounded, value: sp.aiSuggestions,
                      onChanged: (v) => sp.updateEditorSettings(aiSuggestions: v), accentColor: const Color(0xFF8B5CF6)),
                    SettingsToggle(label: 'Live Linting', subtitle: 'Real-time error detection',
                      icon: Icons.bug_report_rounded, value: sp.linting,
                      onChanged: (v) => sp.updateEditorSettings(linting: v), accentColor: const Color(0xFFEC4899)),
                    SettingsToggle(label: 'Format on Save', subtitle: 'Auto-format code when saving',
                      icon: Icons.auto_fix_normal_rounded, value: sp.formatOnSave,
                      onChanged: (v) => sp.updateEditorSettings(formatOnSave: v), accentColor: const Color(0xFF10B981)),
                  ],
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
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
          Text('Code Editor',
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
