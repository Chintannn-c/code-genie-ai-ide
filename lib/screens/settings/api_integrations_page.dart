import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/settings/glass_card.dart';

class ApiIntegrationsPage extends StatelessWidget {
  const ApiIntegrationsPage({super.key});

  void _showKeyEditDialog(BuildContext context, String provider, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F1219).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          title: Text(
            'Configure $provider API Key',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your custom credentials to override default system limits.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste $provider key here...',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black87   ,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text(
                      '$provider API Key saved successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Save Key',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _maskValue(String key) {
    if (key.isEmpty) return 'Not configured';
    if (key.length <= 8) return '••••••••';
    return '••••••••${key.substring(key.length - 4)}';
  }

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

            // Provider Health Dashboard
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('PROVIDER CONFIGURATION', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _providerCard('Gemini AI', 'gemma-4-31b-it', sp.geminiApiKey.isNotEmpty ? 'custom' : 'server', sp.geminiApiKey.isNotEmpty, Icons.auto_awesome_rounded, const Color(0xFF3B82F6), isDark),
                    const SizedBox(height: 10),
                    _providerCard('Groq', 'llama-3.3-70b', sp.groqApiKey.isNotEmpty ? 'custom' : 'server', sp.groqApiKey.isNotEmpty, Icons.bolt_rounded, const Color(0xFFF59E0B), isDark),
                    const SizedBox(height: 10),
                    _providerCard('OpenRouter', 'qwen-2.5-coder', sp.openrouterApiKey.isNotEmpty ? 'custom' : 'server', sp.openrouterApiKey.isNotEmpty, Icons.hub_rounded, const Color(0xFF8B5CF6), isDark),
                    const SizedBox(height: 10),
                    _providerCard('Mistral AI', 'codestral-latest', sp.mistralApiKey.isNotEmpty ? 'custom' : 'server', sp.mistralApiKey.isNotEmpty, Icons.code_rounded, const Color(0xFFEF4444), isDark),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),

            // Integrations
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('INTEGRATIONS', style: GoogleFonts.plusJakartaSans(
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
                      _integrationTile('GitHub', 'Source control, repos', Icons.code_rounded, const Color(0xFFF0F0F0), sp.githubApiKey.isNotEmpty, isDark),
                      _divider(isDark),
                      _integrationTile('Railway', 'Deployment pipeline', Icons.train_rounded, const Color(0xFF8B5CF6), true, isDark),
                      _divider(isDark),
                      _integrationTile('Docker', 'Container sandbox', Icons.view_in_ar_rounded, const Color(0xFF06B6D4), true, isDark),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),

            // API Keys
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('API KEY VAULT', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: GlassCard(
                  glowColor: const Color(0xFF22C55E),
                  glowIntensity: 0.06,
                  child: Column(
                    children: [
                      _keyRow(
                        'GEMINI_API_KEY',
                        _maskValue(sp.geminiApiKey),
                        sp.geminiApiKey.isNotEmpty,
                        isDark,
                        onTap: () => _showKeyEditDialog(context, 'Gemini', sp.geminiApiKey, (v) => sp.updateApiKey('gemini', v)),
                      ),
                      _divider(isDark),
                      _keyRow(
                        'GROQ_API_KEY',
                        _maskValue(sp.groqApiKey),
                        sp.groqApiKey.isNotEmpty,
                        isDark,
                        onTap: () => _showKeyEditDialog(context, 'Groq', sp.groqApiKey, (v) => sp.updateApiKey('groq', v)),
                      ),
                      _divider(isDark),
                      _keyRow(
                        'OPENROUTER_KEY',
                        _maskValue(sp.openrouterApiKey),
                        sp.openrouterApiKey.isNotEmpty,
                        isDark,
                        onTap: () => _showKeyEditDialog(context, 'OpenRouter', sp.openrouterApiKey, (v) => sp.updateApiKey('openrouter', v)),
                      ),
                      _divider(isDark),
                      _keyRow(
                        'MISTRAL_API_KEY',
                        _maskValue(sp.mistralApiKey),
                        sp.mistralApiKey.isNotEmpty,
                        isDark,
                        onTap: () => _showKeyEditDialog(context, 'Mistral', sp.mistralApiKey, (v) => sp.updateApiKey('mistral', v)),
                      ),
                      _divider(isDark),
                      _keyRow(
                        'GITHUB_TOKEN',
                        _maskValue(sp.githubApiKey),
                        sp.githubApiKey.isNotEmpty,
                        isDark,
                        onTap: () => _showKeyEditDialog(context, 'GitHub Token', sp.githubApiKey, (v) => sp.updateApiKey('github', v)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: const Color(0xFF22C55E).withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text('Keys are stored in secure local storage', style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF22C55E).withValues(alpha: 0.6))),
                        ],
                      ),
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
          Text('API & Integrations', style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _providerCard(String name, String model, String source, bool configured, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      glowColor: color,
      glowIntensity: configured ? 0.06 : 0.02,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                Text(model, style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black26)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (configured ? const Color(0xFF10B981) : const Color(0xFF64748B)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: configured ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(configured ? 'Custom' : 'Server', style: GoogleFonts.plusJakartaSans(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: configured ? const Color(0xFF10B981) : const Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(source, style: GoogleFonts.jetBrainsMono(
                fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _integrationTile(String name, String desc, IconData icon, Color color, bool active, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black26)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8)),
            child: Text(active ? 'Active' : 'Setup', style: GoogleFonts.plusJakartaSans(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: active ? const Color(0xFF10B981) : (isDark ? Colors.white38 : Colors.black38))),
          ),
        ],
      ),
    );
  }

  Widget _keyRow(String label, String value, bool configured, bool isDark, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(configured ? Icons.vpn_key_rounded : Icons.key_off_rounded, size: 16,
              color: configured ? const Color(0xFF22C55E) : Colors.white24),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: GoogleFonts.jetBrainsMono(
              fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54))),
            Text(value, style: GoogleFonts.jetBrainsMono(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: configured ? (isDark ? Colors.white38 : Colors.black38) : Colors.redAccent.withValues(alpha: 0.6))),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}
