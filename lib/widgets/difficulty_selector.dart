import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Difficulty level selector widget.
class DifficultySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const DifficultySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption('beginner', '🟢'),
          _buildOption('intermediate', '🟡'),
          _buildOption('advanced', '🔴'),
        ],
      ),
    );
  }

  Widget _buildOption(String value, String emoji) {
    final isSelected = selected == value;
    
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                value.substring(0, 1).toUpperCase() + value.substring(1),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
