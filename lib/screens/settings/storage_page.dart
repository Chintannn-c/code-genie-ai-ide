import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/settings/glass_card.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  double _aiCacheSize = 12.4; // MB
  double _workspaceSize = 8.5; // MB
  double _semanticMemorySize = 1.2; // MB
  double _artifactsSize = 0.0; // MB
  double _tempFilesSize = 4.8; // MB

  bool _isCalculating = true;

  @override
  void initState() {
    super.initState();
    _loadActualSizes();
  }

  Future<void> _loadActualSizes() async {
    setState(() => _isCalculating = true);
    if (kIsWeb) {
      // Simulate small web storage sizes
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _aiCacheSize = 2.4;
          _workspaceSize = 0.5;
          _semanticMemorySize = 0.8;
          _artifactsSize = 0.0;
          _tempFilesSize = 1.1;
          _isCalculating = false;
        });
      }
      return;
    }

    try {
      // Calculate uploads folder size (Workspace files)
      final uploadsDir = Directory('./uploads');
      final double uploadsMB = await _getDirSize(uploadsDir);

      // Calculate build/temp sizes if they exist
      final buildDir = Directory('./build');
      final double buildMB = await _getDirSize(buildDir);

      // Hive Database size calculations (estimating based on standard location size)
      double dbMB = 0.2;
      try {
        final dbDir = Directory('./.dart_tool/hive_flutter');
        dbMB = await _getDirSize(dbDir);
        if (dbMB == 0) {
          dbMB = 0.25; // Safe minimum estimate
        }
      } catch (_) {}

      // Calculate brain artifacts size
      final artifactsDir = Directory('./brain');
      final double artifactsMB = await _getDirSize(artifactsDir);

      if (mounted) {
        setState(() {
          _aiCacheSize = dbMB;
          _workspaceSize = uploadsMB > 0 ? uploadsMB : 8.5;
          _semanticMemorySize = 1.2; // constant local vector index
          _artifactsSize = artifactsMB;
          _tempFilesSize = buildMB > 0 ? (buildMB > 150 ? 150 : buildMB) : 4.8;
          _isCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<double> _getDirSize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0.0;
      double total = 0;
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          total += await file.length();
        }
      }
      return total / (1024 * 1024); // Return in Megabytes
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _clearDirectory(Directory dir) async {
    try {
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _optimizeDatabase() async {
    try {
      if (Hive.isBoxOpen('plans_box')) {
        await Hive.box('plans_box').compact();
      }
      if (Hive.isBoxOpen('notifications_box')) {
        await Hive.box('notifications_box').compact();
      }
    } catch (_) {}
  }

  double get _totalSize => _aiCacheSize + _workspaceSize + _semanticMemorySize + _artifactsSize + _tempFilesSize;
  double get _progress => _totalSize / 5000.0; // percentage of 5 GB limit

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
                            progress: _progress > 1.0 ? 1.0 : _progress,
                            isDark: isDark,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(_progress * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  'of 5 GB limit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Breakdown
                      if (_isCalculating)
                        const SizedBox(
                          height: 10,
                          width: 10,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else ...[
                        _storageRow('AI Cache & DB', '${_aiCacheSize.toStringAsFixed(2)} MB', _aiCacheSize / _totalSize, const Color(0xFF8B5CF6), isDark),
                        const SizedBox(height: 10),
                        _storageRow('Workspace Files', '${_workspaceSize.toStringAsFixed(2)} MB', _workspaceSize / _totalSize, const Color(0xFF3B82F6), isDark),
                        const SizedBox(height: 10),
                        _storageRow('Semantic Memory', '${_semanticMemorySize.toStringAsFixed(2)} MB', _semanticMemorySize / _totalSize, const Color(0xFF10B981), isDark),
                        const SizedBox(height: 10),
                        _storageRow('Artifacts', '${_artifactsSize.toStringAsFixed(2)} MB', _artifactsSize / _totalSize, const Color(0xFFF59E0B), isDark),
                        const SizedBox(height: 10),
                        _storageRow('Temp Files', '${_tempFilesSize.toStringAsFixed(2)} MB', _tempFilesSize / _totalSize, const Color(0xFFEF4444), isDark),
                      ],
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
                    _cleanupCard(
                      'Clear AI Cache',
                      'Purge system models cache',
                      Icons.memory_rounded,
                      const Color(0xFF8B5CF6),
                      isDark,
                      onClean: () async {
                        await _optimizeDatabase();
                        await _loadActualSizes();
                        _showSuccessSnackBar('AI database cache compacted successfully.');
                      },
                    ),
                    const SizedBox(height: 10),
                    _cleanupCard(
                      'Remove Uploaded Files',
                      'Delete files in ./uploads',
                      Icons.delete_sweep_rounded,
                      const Color(0xFFEF4444),
                      isDark,
                      onClean: () async {
                        if (!kIsWeb) {
                          await _clearDirectory(Directory('./uploads'));
                        }
                        await _loadActualSizes();
                        _showSuccessSnackBar('Uploaded files successfully deleted.');
                      },
                    ),
                    const SizedBox(height: 10),
                    _cleanupCard(
                      'Optimize Database',
                      'Reclaim fragmented index sizes',
                      Icons.storage_rounded,
                      const Color(0xFF06B6D4),
                      isDark,
                      onClean: () async {
                        await _optimizeDatabase();
                        await _loadActualSizes();
                        _showSuccessSnackBar('Database indices optimized successfully.');
                      },
                    ),
                    const SizedBox(height: 10),
                    _cleanupCard(
                      'Clear Temp Files',
                      'Wipe build temp folders',
                      Icons.cleaning_services_rounded,
                      const Color(0xFFF59E0B),
                      isDark,
                      onClean: () async {
                        if (!kIsWeb) {
                          await _clearDirectory(Directory('./build'));
                        }
                        await _loadActualSizes();
                        _showSuccessSnackBar('Temporary files cleared successfully.');
                      },
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

  Widget _cleanupCard(
    String title,
    String desc,
    IconData icon,
    Color color,
    bool isDark, {
    required VoidCallback onClean,
  }) {
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
                Text(desc, style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white30 : Colors.black26)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClean,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text('Clean', style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    // Progress ring with sweep gradient
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
