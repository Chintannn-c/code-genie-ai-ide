import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final ap = context.watch<AuthProvider>();
    final user = ap.user;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0B0C) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Profile Card
          _buildProfileCard(user, isDark),
          
          const SizedBox(height: 24),
          
          _sectionTitle('SETTINGS'),
          
          _settingsItem(
            icon: Icons.person_outline_rounded,
            title: 'Account',
            subtitle: 'Profile, password, connected accounts',
            color: Colors.blueAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.smart_toy_outlined,
            title: 'AI Settings',
            subtitle: 'Model, temperature, response length',
            color: Colors.deepPurpleAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.code_rounded,
            title: 'Code Editor',
            subtitle: 'Font, theme, auto save, tab spacing',
            color: Colors.greenAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, accent color, animations',
            color: Colors.pinkAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Push, AI alerts, updates',
            color: Colors.orangeAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.storage_rounded,
            title: 'Storage & Cache',
            subtitle: 'Storage usage, clear cache',
            color: Colors.tealAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.link_rounded,
            title: 'API & Integrations',
            subtitle: 'API keys, GitHub, VS Code sync',
            color: Colors.indigoAccent,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.security_rounded,
            title: 'Privacy & Security',
            subtitle: 'Security, backup, delete account',
            color: Colors.green,
            isDark: isDark,
          ),
          _settingsItem(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version, terms, support',
            color: Colors.blue,
            isDark: isDark,
          ),
          
          const SizedBox(height: 40),
          
          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: () => ap.signOut(),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              label: Text(
                'Log out',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          const SizedBox(height: 100), // Space for bottom nav
        ],
      ),
      bottomNavigationBar: CodeGenieBottomNav(
        currentIndex: 4,
        onTap: (index) {
          if (index == 1) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildProfileCard(dynamic user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121214) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            backgroundImage: user?.pictureUrl != null ? NetworkImage(user!.pictureUrl!) : null,
            child: user?.pictureUrl == null 
              ? Text(user?.fullName?[0] ?? 'C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))) 
              : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Chintan Sharma',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  user?.email ?? 'chintan@example.com',
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
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        'Pro Developer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white24,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white10 : Colors.black12),
        onTap: () {},
      ),
    );
  }
}
