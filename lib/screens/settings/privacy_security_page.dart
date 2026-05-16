import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _promptInjection = true;
  bool _sandboxExec = true;
  bool _encryption = true;
  bool _auditLog = true;

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

            // Security Score
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GlassCard(
                  glowColor: const Color(0xFF22C55E),
                  glowIntensity: 0.12,
                  child: Row(
                    children: [
                      // Score circle
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.3), blurRadius: 20),
                          ],
                        ),
                        child: Center(
                          child: Text('A+', style: GoogleFonts.plusJakartaSans(
                            fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Security Score', style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 4),
                            Text('Your account is well protected. All critical security features are enabled.', style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black38, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
            ),

            // Active Sessions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('ACTIVE SESSIONS', style: GoogleFonts.plusJakartaSans(
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
                      _sessionTile('Chrome — Windows', 'Current session', Icons.laptop_rounded, true, isDark),
                      _divider(isDark),
                      _sessionTile('Safari — macOS', 'Last active: 2 days ago', Icons.phone_iphone_rounded, false, isDark),
                      _divider(isDark),
                      _sessionTile('Flutter App — Android', 'Last active: 5 hours ago', Icons.phone_android_rounded, false, isDark),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // Security Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('SECURITY CONTROLS', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    SettingsToggle(label: 'Prompt Injection Protection', subtitle: 'Block malicious prompt attacks',
                      icon: Icons.shield_rounded, value: _promptInjection,
                      onChanged: (v) => setState(() => _promptInjection = v), accentColor: const Color(0xFF22C55E)),
                    SettingsToggle(label: 'Sandboxed Execution', subtitle: 'Run code in isolated Docker containers',
                      icon: Icons.view_in_ar_rounded, value: _sandboxExec,
                      onChanged: (v) => setState(() => _sandboxExec = v), accentColor: const Color(0xFF06B6D4)),
                    SettingsToggle(label: 'End-to-End Encryption', subtitle: 'Encrypt all data in transit and at rest',
                      icon: Icons.lock_rounded, value: _encryption,
                      onChanged: (v) => setState(() => _encryption = v), accentColor: const Color(0xFF3B82F6)),
                    SettingsToggle(label: 'Audit Trail Logging', subtitle: 'Log all API access and agent actions',
                      icon: Icons.history_rounded, value: _auditLog,
                      onChanged: (v) => setState(() => _auditLog = v), accentColor: const Color(0xFF8B5CF6)),
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
          Text('Privacy & Security', style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _sessionTile(String device, String status, IconData icon, bool current, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: current ? const Color(0xFF22C55E) : (isDark ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device, style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                Text(status, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: current ? const Color(0xFF22C55E) : (isDark ? Colors.white30 : Colors.black26))),
              ],
            ),
          ),
          if (!current)
            GestureDetector(
              child: Text('Revoke', style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent)),
            ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}
