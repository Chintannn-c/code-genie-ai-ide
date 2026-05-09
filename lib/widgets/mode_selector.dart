import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Mode selector for Generate / Debug / Explain toggle.
class ModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const ModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = MediaQuery.of(context).size.width < 600;

      if (isSmall) {
        return _buildCompact(context);
      }

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: AppConstants.modes.map((mode) {
            final isSelected = mode['key'] == selected;
            return GestureDetector(
              onTap: () => onChanged(mode['key']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildCompact(BuildContext context) {
    final activeMode = AppConstants.modes.firstWhere((m) => m['key'] == selected);

    return PopupMenuButton<String>(
      initialValue: selected,
      tooltip: 'Select Mode',
      onSelected: onChanged,
      offset: const Offset(0, 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(activeMode['icon'] as IconData, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              activeMode['label'] as String,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.white),
          ],
        ),
      ),
      itemBuilder: (context) => AppConstants.modes.map((mode) {
        return PopupMenuItem<String>(
          value: mode['key'] as String,
          child: Row(
            children: [
              Icon(mode['icon'] as IconData, size: 18, color: const Color(0xFF6366F1)),
              const SizedBox(width: 12),
              Text(mode['label'] as String),
            ],
          ),
        );
      }).toList(),
    );
  }
}
