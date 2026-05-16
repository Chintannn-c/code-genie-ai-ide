import 'package:flutter/material.dart';

/// Animated glowing icon for settings navigation items.
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(13),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ]
            : [],
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
