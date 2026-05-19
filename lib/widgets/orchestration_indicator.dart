import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OrchestrationIndicator extends StatelessWidget {
  final bool isActive;
  final String label;
  final List<String> models;

  const OrchestrationIndicator({
    super.key,
    required this.isActive,
    this.label = 'AI working',
    this.models = const ['Qwen', 'Gemini', 'Mistral', 'Llama'],
  });

  Color _getModelColor(String model) {
    final m = model.toLowerCase();
    if (m.contains('gemini')) return const Color(0xFF4285F4);
    if (m.contains('qwen')) return const Color(0xFF00F2FF);
    if (m.contains('mistral')) return const Color(0xFFFF4B4B);
    if (m.contains('llama') || m.contains('groq'))
      return const Color(0xFF00FF88);
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111827).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                _HolographicRing(color: const Color(0xFF6366F1)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ...models
                    .take(2)
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _ModelNode(model: m, color: _getModelColor(m)),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms);
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
        )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          duration: 1500.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          curve: Curves.easeInOut,
        )
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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
            model.toUpperCase().replaceAll('_', ' '),
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
