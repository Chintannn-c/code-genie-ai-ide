import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key});

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

            // Storage Overview
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: GlassCard(
                  glowColor: const Color(0xFF06B6D4),
                  glowIntensity: 0.1,
                  child: Column(
                    children: [
                      // Circular usage gauge
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CustomPaint(
                          painter: _StorageRingPainter(
                            progress: 0.42,
                            isDark: isDark,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('42%', style: GoogleFonts.plusJakartaSans(
                                  fontSize: 32, fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black)),
                                Text('of 5 GB', style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white38 : Colors.black38)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Breakdown
                      _storageRow('AI Cache', '680 MB', 0.32, const Color(0xFF8B5CF6), isDark),
                      const SizedBox(height: 10),
                      _storageRow('Workspace Files', '520 MB', 0.25, const Color(0xFF3B82F6), isDark),
                      const SizedBox(height: 10),
                      _storageRow('Semantic Memory', '340 MB', 0.16, const Color(0xFF10B981), isDark),
                      const SizedBox(height: 10),
                      _storageRow('Artifacts', '210 MB', 0.1, const Color(0xFFF59E0B), isDark),
                      const SizedBox(height: 10),
                      _storageRow('Temp Files', '150 MB', 0.07, const Color(0xFFEF4444), isDark),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
            ),

            // Cleanup Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text('CLEANUP ACTIONS', style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white24 : Colors.black26, letterSpacing: 1.5)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    _cleanupCard('Clear AI Cache', '680 MB', Icons.memory_rounded, const Color(0xFF8B5CF6), isDark),
                    const SizedBox(height: 10),
                    _cleanupCard('Remove Temp Files', '150 MB', Icons.delete_sweep_rounded, const Color(0xFFEF4444), isDark),
                    const SizedBox(height: 10),
                    _cleanupCard('Optimize Database', 'Reclaim ~120 MB', Icons.storage_rounded, const Color(0xFF06B6D4), isDark),
                    const SizedBox(height: 10),
                    _cleanupCard('Clear All Data', '2.1 GB', Icons.cleaning_services_rounded, const Color(0xFFF59E0B), isDark),
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
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 16),
          Text('Storage & Cache', style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _storageRow(String label, String size, double fill, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
        ),
        Text(size, style: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _cleanupCard(String title, String size, IconData icon, Color color, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      glowColor: color,
      glowIntensity: 0.05,
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
                Text(title, style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                Text(size, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black26)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text('Clean', style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _StorageRingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _StorageRingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring with gradient
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: const [Color(0xFF06B6D4), Color(0xFF8B5CF6), Color(0xFFEC4899)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
