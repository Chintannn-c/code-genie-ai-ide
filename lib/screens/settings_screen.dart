import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/settings/glass_card.dart';
import '../widgets/settings/glow_icon.dart';
import 'settings/account_page.dart';
import 'settings/ai_settings_page.dart';
import 'settings/appearance_page.dart';
import 'settings/editor_page.dart';
import 'settings/notifications_page.dart';
import 'settings/storage_page.dart';
import 'settings/api_integrations_page.dart';
import 'settings/privacy_security_page.dart';
import 'settings/about_page.dart';

/// The Cockpit Dashboard — main settings hub with cinematic glassmorphic UI.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  static final List<_SettingsSection> _sections = [
    _SettingsSection('Account', 'Profile, identity, connections', Icons.person_rounded, const Color(0xFF3B82F6)),
    _SettingsSection('AI Settings', 'Models, orchestration, agents', Icons.smart_toy_rounded, const Color(0xFF8B5CF6)),
    _SettingsSection('Code Editor', 'Font, theme, keybindings', Icons.code_rounded, const Color(0xFF10B981)),
    _SettingsSection('Appearance', 'Themes, effects, animations', Icons.palette_rounded, const Color(0xFFEC4899)),
    _SettingsSection('Notifications', 'Alerts, events, quiet hours', Icons.notifications_rounded, const Color(0xFFF59E0B)),
    _SettingsSection('Storage & Cache', 'Usage, cleanup, optimization', Icons.storage_rounded, const Color(0xFF06B6D4)),
    _SettingsSection('API & Integrations', 'Keys, providers, webhooks', Icons.hub_rounded, const Color(0xFF6366F1)),
    _SettingsSection('Privacy & Security', 'Sessions, encryption, audit', Icons.shield_rounded, const Color(0xFF22C55E)),
    _SettingsSection('About', 'Version, credits, support', Icons.info_rounded, const Color(0xFF64748B)),
  ];

  void _navigateToPage(BuildContext context, int index) {
    final pages = [
      const AccountPage(),
      const AiSettingsPage(),
      const EditorPage(),
      const AppearancePage(),
      const NotificationsPage(),
      const StoragePage(),
      const ApiIntegrationsPage(),
      const PrivacySecurityPage(),
      const AboutPage(),
    ];
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => pages[index],
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final ap = context.watch<AuthProvider>();
    final user = ap.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      -0.5 + _bgController.value * 1.0,
                      -0.8 + _bgController.value * 0.5,
                    ),
                    radius: 1.8,
                    colors: isDark
                        ? [
                            const Color(0xFF6366F1).withValues(alpha: 0.08),
                            const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                            Colors.transparent,
                          ]
                        : [
                            const Color(0xFF6366F1).withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                  ),
                ),
              );
            },
          ),
          // Main content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 40 : 20, 16, isWide ? 40 : 20, 0),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'System Settings',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'Configure your AI engineering environment',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // System status dot
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Online',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
                ),

                // Profile Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 40 : 20, 24, isWide ? 40 : 20, 0),
                    child: GlassCard(
                      glowColor: const Color(0xFF6366F1),
                      glowIntensity: 0.12,
                      onTap: () => _navigateToPage(context, 0),
                      child: Row(
                        children: [
                          // Animated avatar with glow ring
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
                              backgroundImage: user?.pictureUrl != null
                                  ? NetworkImage(user!.pictureUrl!)
                                  : null,
                              child: user?.pictureUrl == null
                                  ? Text(
                                      user?.fullName?[0] ?? 'C',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Code Genie User',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.email ?? 'user@codegenie.ai',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF6366F1).withValues(alpha: 0.2),
                                        const Color(0xFFA855F7).withValues(alpha: 0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFA855F7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PRO ENGINEER',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFA855F7),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.03, end: 0),
                ),

                // Section Label
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 44 : 24, 28, 0, 12),
                    child: Text(
                      'CONFIGURATION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                // Settings Grid
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isWide ? 2.0 : 1.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final section = _sections[index];
                        return GlassCard(
                          padding: const EdgeInsets.all(16),
                          glowColor: section.color,
                          glowIntensity: 0.06,
                          borderRadius: 18,
                          onTap: () => _navigateToPage(context, index),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GlowIcon(icon: section.icon, color: section.color),
                              const Spacer(),
                              Text(
                                section.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                section.subtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white30 : Colors.black38,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(
                              delay: (100 + index * 60).ms,
                              duration: 400.ms,
                            ).slideY(begin: 0.05, end: 0);
                      },
                      childCount: _sections.length,
                    ),
                  ),
                ),

                // Sign Out
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(isWide ? 40 : 20, 32, isWide ? 40 : 20, 40),
                    child: GlassCard(
                      glowColor: Colors.redAccent,
                      glowIntensity: 0.05,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      onTap: () => ap.signOut(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _SettingsSection(this.title, this.subtitle, this.icon, this.color);
}
