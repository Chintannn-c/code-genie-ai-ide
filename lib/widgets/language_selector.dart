import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Language selector dropdown widget.
class LanguageSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const LanguageSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 4),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E2430) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.5),
          ),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.black87,
          ),
          items: AppConstants.languages.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Text(lang),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
