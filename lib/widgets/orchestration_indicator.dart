import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrchestrationIndicator extends StatefulWidget {
  final bool isActive;
  final List<String> models;

  const OrchestrationIndicator({
    super.key,
    required this.isActive,
    this.models = const ['Llama', 'Gemini'],
  });

  @override
  State<OrchestrationIndicator> createState() => _OrchestrationIndicatorState();
}

class _OrchestrationIndicatorState extends State<OrchestrationIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulse Dots
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),

            Text(
              '${widget.models.length} Models Orchestrating',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(width: 12),
            const VerticalDivider(width: 1, indent: 4, endIndent: 4),
            const SizedBox(width: 12),

            // Model Badges
            ...widget.models.map(
              (m) => Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
