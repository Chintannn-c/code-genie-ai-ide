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

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final sp = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08080A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Model Quota Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'MODEL STATUS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _modelCard(
                      'Gemini',
                      sp.geminiApiKey.isNotEmpty
                          ? 'Custom key'
                          : 'Server managed',
                      'Primary',
                      const Color(0xFF3B82F6),
                      sp.geminiApiKey.isNotEmpty ? 1.0 : 0.7,
                      isDark,
                      Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(width: 12),
                    _modelCard(
                      'Groq',
                      sp.groqApiKey.isNotEmpty
                          ? 'Custom key'
                          : 'Server managed',
                      'Fast fallback',
                      const Color(0xFFF59E0B),
                      sp.groqApiKey.isNotEmpty ? 1.0 : 0.7,
                      isDark,
                      Icons.bolt_rounded,
                    ),
                    const SizedBox(width: 12),
                    _modelCard(
                      'OpenRouter',
                      sp.openrouterApiKey.isNotEmpty
                          ? 'Custom key'
                          : 'Server managed',
                      'Free pool',
                      const Color(0xFF8B5CF6),
                      sp.openrouterApiKey.isNotEmpty ? 1.0 : 0.7,
                      isDark,
                      Icons.hub_rounded,
                    ),
                    const SizedBox(width: 12),
                    _modelCard(
                      'Mistral',
                      sp.mistralApiKey.isNotEmpty
                          ? 'Custom key'
                          : 'Server managed',
                      'Code specialist',
                      const Color(0xFFEF4444),
                      sp.mistralApiKey.isNotEmpty ? 1.0 : 0.7,
                      isDark,
                      Icons.code_rounded,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Orchestration Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text(
                  'ORCHESTRATION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SettingsToggle(
                      label: 'Streaming Responses',
                      subtitle: 'Stream AI output in real-time',
                      icon: Icons.stream_rounded,
                      value: sp.streaming,
                      onChanged: (v) => sp.updateAiSettings(streaming: v),
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsToggle(
                      label: 'Autonomous Mode',
                      subtitle:
                          'Allow AI to execute tasks without confirmation',
                      icon: Icons.rocket_launch_rounded,
                      value: sp.autonomousMode,
                      onChanged: (v) => sp.updateAiSettings(autonomousMode: v),
                      accentColor: const Color(0xFFEC4899),
                    ),
                    SettingsToggle(
                      label: 'AI Debate Mode',
                      subtitle: 'Multiple models argue for the best solution',
                      icon: Icons.forum_rounded,
                      value: sp.debateMode,
                      onChanged: (v) => sp.updateAiSettings(debateMode: v),
                      accentColor: const Color(0xFFA855F7),
                    ),
                    SettingsToggle(
                      label: 'RAG Context Injection',
                      subtitle: 'Inject file and codebase context into prompts',
                      icon: Icons.dataset_linked_rounded,
                      value: sp.ragContext,
                      onChanged: (v) => sp.updateAiSettings(ragContext: v),
                      accentColor: const Color(0xFF10B981),
                    ),
                    SettingsToggle(
                      label: 'Memory Persistence',
                      subtitle: 'AI remembers context across conversations',
                      icon: Icons.memory_rounded,
                      value: sp.memoryPersist,
                      onChanged: (v) => sp.updateAiSettings(memoryPersist: v),
                      accentColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // Tuning Sliders
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text(
                  'FINE TUNING',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 1.5,
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
                      label: 'Temperature',
                      subtitle: 'Higher = more creative, lower = more precise',
                      icon: Icons.thermostat_rounded,
                      value: sp.temperature,
                      min: 0,
                      max: 2,
                      divisions: 20,
                      onChanged: (v) => sp.updateAiSettings(temperature: v),
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    SettingsSlider(
                      label: 'Max Output Tokens',
                      subtitle: 'Maximum response length',
                      icon: Icons.token_rounded,
                      value: sp.maxTokens,
                      min: 256,
                      max: 8192,
                      divisions: 31,
                      onChanged: (v) => sp.updateAiSettings(maxTokens: v),
                      valueLabel: (v) => v.toInt().toString(),
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsSlider(
                      label: 'Creativity vs Accuracy',
                      subtitle: 'Balance between novel and factual responses',
                      icon: Icons.balance_rounded,
                      value: sp.creativity,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (v) => sp.updateAiSettings(creativity: v),
                      valueLabel: (v) => v <= 0.3
                          ? 'Precise'
                          : v >= 0.7
                          ? 'Creative'
                          : 'Balanced',
                      accentColor: const Color(0xFFEC4899),
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'AI Settings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 800.ms),
                const SizedBox(width: 6),
                Text(
                  'AI Active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelCard(
    String name,
    String status,
    String detail,
    Color color,
    double fill,
    bool isDark,
    IconData icon,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      glowColor: color,
      glowIntensity: 0.1,
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: fill > 0.3
                        ? const Color(0xFF10B981)
                        : Colors.orangeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (fill > 0.3
                                    ? const Color(0xFF10B981)
                                    : Colors.orangeAccent)
                                .withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fill,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  detail,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
