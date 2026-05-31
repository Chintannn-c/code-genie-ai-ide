import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  StreamSubscription? _rawMessageSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().fetchSessions();
    });

    // Automatically reload active sessions list in real-time when a session is revoked on another device
    _rawMessageSub = NotificationService().rawMessageStream.listen((event) {
      if (event['type'] == 'session_revoked_event' || event['type'] == 'all_sessions_revoked_event') {
        if (mounted) {
          context.read<SessionProvider>().fetchSessions();
        }
      }
    });
  }

  @override
  void dispose() {
    _rawMessageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final sp = context.watch<SettingsProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final sessions = sessionProvider.sessions;

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
                  child: Builder(
                    builder: (context) {
                      if (sessionProvider.isLoading && sessions.isEmpty) {
                        return Column(
                          children: [
                            _buildSkeletonTile(isDark),
                            _divider(isDark),
                            _buildSkeletonTile(isDark),
                          ],
                        );
                      }
                      
                      if (sessionProvider.error != null && sessions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 24),
                              const SizedBox(height: 12),
                              Text(
                                sessionProvider.error!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => sessionProvider.fetchSessions(),
                                child: Text('Retry', style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF6366F1)
                                )),
                              )
                            ],
                          ),
                        );
                      }

                      if (sessions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No active sessions found.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white30 : Colors.black38,
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          ...List.generate(sessions.length * 2 - 1, (index) {
                            if (index.isOdd) return _divider(isDark);
                            final sessionIndex = index ~/ 2;
                            final session = sessions[sessionIndex];
                            return _sessionTile(session, isDark);
                          }),
                          if (sessions.any((s) => !s.isCurrent)) ...[
                            _divider(isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: TextButton.icon(
                                onPressed: () async {
                                  final success = await context.read<SessionProvider>().revokeAllOtherSessions();
                                  if (success && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Successfully revoked all other sessions.'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.phonelink_erase_rounded, size: 16, color: Colors.redAccent),
                                label: Text(
                                  'Revoke all other sessions',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ]
                        ],
                      );
                    }
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
                    SettingsToggle(
                      label: 'Prompt Injection Protection',
                      subtitle: 'Block malicious prompt attacks',
                      icon: Icons.shield_rounded,
                      value: sp.promptInjectionProtection,
                      onChanged: (v) => sp.updateSecuritySettings(promptInjectionProtection: v),
                      accentColor: const Color(0xFF22C55E),
                    ),
                    SettingsToggle(
                      label: 'Sandboxed Execution',
                      subtitle: 'Run code in isolated Docker containers',
                      icon: Icons.view_in_ar_rounded,
                      value: sp.sandboxedExecution,
                      onChanged: (v) => sp.updateSecuritySettings(sandboxedExecution: v),
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    SettingsToggle(
                      label: 'End-to-End Encryption',
                      subtitle: 'Encrypt all data in transit and at rest',
                      icon: Icons.lock_rounded,
                      value: sp.endToEndEncryption,
                      onChanged: (v) => sp.updateSecuritySettings(endToEndEncryption: v),
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    SettingsToggle(
                      label: 'Audit Trail Logging',
                      subtitle: 'Log all API access and agent actions',
                      icon: Icons.history_rounded,
                      value: sp.auditTrailLogging,
                      onChanged: (v) => sp.updateSecuritySettings(auditTrailLogging: v),
                      accentColor: const Color(0xFF8B5CF6),
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
          Text('Privacy & Security', style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _sessionTile(UserSession session, bool isDark) {
    final statusString = session.isCurrent 
        ? "Current session" 
        : "Last active: ${_formatDateTime(session.lastSeen)} • IP: ${session.ipAddress}";
        
    final icon = _getPlatformIcon(session.platform);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: session.isCurrent 
                  ? const Color(0xFF22C55E).withValues(alpha: 0.08) 
                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              size: 18, 
              color: session.isCurrent 
                  ? const Color(0xFF22C55E) 
                  : (isDark ? Colors.white54 : Colors.black54)
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "${session.deviceName} — ${session.browser}", 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, 
                          fontWeight: FontWeight.w700, 
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Active Now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF22C55E),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  statusString, 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, 
                    fontWeight: FontWeight.w500,
                    color: session.isCurrent 
                        ? const Color(0xFF22C55E).withValues(alpha: 0.8) 
                        : (isDark ? Colors.white30 : Colors.black38),
                  ),
                ),
              ],
            ),
          ),
          if (!session.isCurrent)
            GestureDetector(
              onTap: () async {
                final success = await context.read<SessionProvider>().revokeSession(session.id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Revoked session for ${session.deviceName} successfully.'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Revoke',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'desktop':
        return Icons.computer_rounded;
      default:
        return Icons.language_rounded;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) {
      return "just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else {
      return "${diff.inDays}d ago";
    }
  }

  Widget _buildSkeletonTile(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140, height: 12,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 90, height: 8,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(4),
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
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}
