import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _push = true;
  bool _aiAlerts = true;
  bool _securityAlerts = true;
  bool _modelFailure = true;
  bool _deployment = false;
  bool _collaboration = true;
  bool _email = false;
  bool _sound = true;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF08080A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // Live Event Feed
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'RECENT EVENTS',
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
                child: GlassCard(
                  child: Column(
                    children: [
                      _eventTile(
                        'AI Completed Task',
                        '2 min ago',
                        Icons.check_circle_rounded,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                      _divider(isDark),
                      _eventTile(
                        'Model Failover: Gemini → Groq',
                        '15 min ago',
                        Icons.swap_horiz_rounded,
                        const Color(0xFFF59E0B),
                        isDark,
                      ),
                      _divider(isDark),
                      _eventTile(
                        'New Login from Chrome',
                        '1 hour ago',
                        Icons.login_rounded,
                        const Color(0xFF3B82F6),
                        isDark,
                      ),
                      _divider(isDark),
                      _eventTile(
                        'Deployment Succeeded',
                        '3 hours ago',
                        Icons.rocket_launch_rounded,
                        const Color(0xFF8B5CF6),
                        isDark,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Notification Controls
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'NOTIFICATION CHANNELS',
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
                    SettingsToggle(
                      label: 'Push Notifications',
                      subtitle: 'Browser and mobile alerts',
                      icon: Icons.notifications_active_rounded,
                      value: _push,
                      onChanged: (v) => setState(() => _push = v),
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsToggle(
                      label: 'AI Workflow Alerts',
                      subtitle: 'Plan completion, agent updates',
                      icon: Icons.smart_toy_rounded,
                      value: _aiAlerts,
                      onChanged: (v) => setState(() => _aiAlerts = v),
                      accentColor: const Color(0xFF8B5CF6),
                    ),
                    SettingsToggle(
                      label: 'Security Alerts',
                      subtitle: 'Login attempts, suspicious activity',
                      icon: Icons.shield_rounded,
                      value: _securityAlerts,
                      onChanged: (v) => setState(() => _securityAlerts = v),
                      accentColor: const Color(0xFF22C55E),
                    ),
                    SettingsToggle(
                      label: 'Model Failure Alerts',
                      subtitle: 'Provider outages, rate limits',
                      icon: Icons.error_outline_rounded,
                      value: _modelFailure,
                      onChanged: (v) => setState(() => _modelFailure = v),
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    SettingsToggle(
                      label: 'Deployment Notifications',
                      subtitle: 'Build status, Railway updates',
                      icon: Icons.cloud_upload_rounded,
                      value: _deployment,
                      onChanged: (v) => setState(() => _deployment = v),
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    SettingsToggle(
                      label: 'Collaboration',
                      subtitle: 'Team activity, shared workspaces',
                      icon: Icons.group_rounded,
                      value: _collaboration,
                      onChanged: (v) => setState(() => _collaboration = v),
                      accentColor: const Color(0xFFEC4899),
                    ),
                    SettingsToggle(
                      label: 'Email Notifications',
                      subtitle: 'Daily digest and weekly summary',
                      icon: Icons.email_rounded,
                      value: _email,
                      onChanged: (v) => setState(() => _email = v),
                      accentColor: const Color(0xFF64748B),
                    ),
                    SettingsToggle(
                      label: 'Sound Effects',
                      subtitle: 'Notification sounds and haptics',
                      icon: Icons.volume_up_rounded,
                      value: _sound,
                      onChanged: (v) => setState(() => _sound = v),
                      accentColor: const Color(0xFFA855F7),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
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
          Text(
            'Notifications',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTile(
    String title,
    String time,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white30 : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05),
      height: 1,
    );
  }
}
