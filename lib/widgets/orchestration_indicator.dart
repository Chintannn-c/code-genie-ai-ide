import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OrchestrationIndicator extends StatelessWidget {
  final bool isActive;
  final List<String> models;

  const OrchestrationIndicator({
    super.key,
    required this.isActive,
    this.models = const ['Qwen', 'Gemini', 'Mistral', 'Llama'],
  });

  Color _getModelColor(String model) {
    final m = model.toLowerCase();
    if (m.contains('gemini')) return const Color(0xFF4285F4);
    if (m.contains('qwen')) return const Color(0xFF00F2FF);
    if (m.contains('mistral')) return const Color(0xFFFF4B4B);
    if (m.contains('llama') || m.contains('groq')) return const Color(0xFF00FF88);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark 
                  ? const Color(0xFF1E1E21).withValues(alpha: 0.6) 
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HolographicRing(color: const Color(0xFF6366F1)),
                    const SizedBox(width: 16),
                    Text(
                      'AI ORCHESTRATION ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 2.0,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: models.map((m) => _ModelNode(model: m, color: _getModelColor(m))).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }
}

class _HolographicRing extends StatelessWidget {
  final Color color;
  const _HolographicRing({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    ).animate(onPlay: (c) => c.repeat())
      .scale(duration: 1500.ms, begin: const Offset(1, 1), end: const Offset(1.3, 1.3), curve: Curves.easeInOut)
      .fadeOut();
  }
}

class _ModelNode extends StatelessWidget {
  final String model;
  final Color color;
  const _ModelNode({required this.model, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            model.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.1);
  }
}
