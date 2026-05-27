import 'package:flutter/material.dart';

/// Simple icon container for settings navigation items. No glow.
class GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool isActive;

  const GlowIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 22,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF242424)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
