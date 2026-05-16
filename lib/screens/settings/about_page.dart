import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // App Identity Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GlassCard(
                  glowColor: const Color(0xFF6366F1),
                  glowIntensity: 0.12,
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.4), blurRadius: 24),
                          ],
                        ),
                        child: Image.asset('assets/icon/app_icon.png', width: 48, height: 48, fit: BoxFit.contain),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 4000.ms, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 20),
                      Text('Code Genie', style: GoogleFonts.plusJakartaSans(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black, letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('AI Engineering Platform', style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38)),
                      const SizedBox(height: 16),
                      // Version badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _versionBadge('v3.1.0', const Color(0xFF6366F1), isDark),
                          const SizedBox(width: 8),
                          _versionBadge('Build 2026.05.16', const Color(0xFF64748B), isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
            ),

            // System Status
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('SYSTEM STATUS', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  child: Column(
                    children: [
                      _statusRow('AI Orchestration Engine', 'v2.4.0', const Color(0xFF8B5CF6), true, isDark),
                      _divider(isDark),
                      _statusRow('Backend API', 'FastAPI 0.115', const Color(0xFF10B981), true, isDark),
                      _divider(isDark),
                      _statusRow('Database', 'MongoDB Atlas', const Color(0xFF3B82F6), true, isDark),
                      _divider(isDark),
                      _statusRow('Deployment', 'Railway (US East)', const Color(0xFFF59E0B), true, isDark),
                      _divider(isDark),
                      _statusRow('Uptime', '99.7% (30d)', const Color(0xFF22C55E), true, isDark),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // Links
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('RESOURCES', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: GlassCard(
                  child: Column(
                    children: [
                      _linkTile('Changelog', Icons.history_rounded, const Color(0xFF6366F1), isDark),
                      _divider(isDark),
                      _linkTile('Terms of Service', Icons.description_rounded, const Color(0xFF64748B), isDark),
                      _divider(isDark),
                      _linkTile('Privacy Policy', Icons.privacy_tip_rounded, const Color(0xFF06B6D4), isDark),
                      _divider(isDark),
                      _linkTile('Open Source Libraries', Icons.library_books_rounded, const Color(0xFF10B981), isDark),
                      _divider(isDark),
                      _linkTile('Support Center', Icons.support_agent_rounded, const Color(0xFFF59E0B), isDark),
                      _divider(isDark),
                      _linkTile('GitHub Repository', Icons.code_rounded, const Color(0xFFF0F0F0), isDark),
                    ],
                  ),
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
          Text('About', style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _versionBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: GoogleFonts.jetBrainsMono(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _statusRow(String label, String value, Color color, bool online, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: (online ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.4), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))),
          Text(value, style: GoogleFonts.jetBrainsMono(
            fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _linkTile(String title, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
          Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white12 : Colors.black12),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}
