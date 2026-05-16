import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _twoFactor = false;
  bool _biometric = true;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final ap = context.watch<AuthProvider>();
    final user = ap.user;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),
            // Profile Hero
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: GlassCard(
                  glowColor: const Color(0xFF6366F1),
                  glowIntensity: 0.15,
                  child: Column(
                    children: [
                      // Avatar with animated glow ring
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
                          backgroundImage: user?.pictureUrl != null
                              ? NetworkImage(user!.pictureUrl!)
                              : null,
                          child: user?.pictureUrl == null
                              ? Text(
                                  user?.fullName?[0] ?? 'C',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 36, fontWeight: FontWeight.w800,
                                    color: const Color(0xFF6366F1),
                                  ),
                                )
                              : null,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 3000.ms, color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
                      const SizedBox(height: 16),
                      Text(
                        user?.fullName ?? 'Code Genie User',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'user@codegenie.ai',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status badges
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badge('PRO', const Color(0xFFA855F7), isDark),
                          const SizedBox(width: 8),
                          _badge('VERIFIED', const Color(0xFF10B981), isDark),
                          const SizedBox(width: 8),
                          _badge('2FA', _twoFactor ? const Color(0xFF10B981) : const Color(0xFF64748B), isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Connected Accounts
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'CONNECTED ACCOUNTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white24 : Colors.black26,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassCard(
                  child: Column(
                    children: [
                      _connectionTile('Google', Icons.g_mobiledata_rounded, const Color(0xFF4285F4), true, isDark),
                      _divider(isDark),
                      _connectionTile('GitHub', Icons.code_rounded, const Color(0xFFF0F0F0), false, isDark),
                      _divider(isDark),
                      _connectionTile('OpenRouter', Icons.hub_rounded, const Color(0xFF8B5CF6), true, isDark),
                      _divider(isDark),
                      _connectionTile('Groq', Icons.bolt_rounded, const Color(0xFFF59E0B), true, isDark),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // Security
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'SECURITY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w800,
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
                      label: 'Two-Factor Authentication',
                      subtitle: 'Extra layer of security',
                      icon: Icons.security_rounded,
                      value: _twoFactor,
                      onChanged: (v) => setState(() => _twoFactor = v),
                      accentColor: const Color(0xFF22C55E),
                    ),
                    SettingsToggle(
                      label: 'Biometric Login',
                      subtitle: 'Use fingerprint or face ID',
                      icon: Icons.fingerprint_rounded,
                      value: _biometric,
                      onChanged: (v) => setState(() => _biometric = v),
                      accentColor: const Color(0xFF3B82F6),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ),

            // Danger Zone
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: GlassCard(
                  glowColor: Colors.redAccent,
                  glowIntensity: 0.08,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Danger Zone',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Permanently delete your account and all associated data. This action cannot be undone.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Delete Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
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
          Text(
            'Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _connectionTile(String name, IconData icon, Color color, bool connected, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name, style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              connected ? 'Connected' : 'Connect',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: connected ? const Color(0xFF10B981) : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}
