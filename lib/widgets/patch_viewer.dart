import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatchViewer extends StatelessWidget {
  final String patch;
  final String? fileName;
  final bool isDark;

  const PatchViewer({
    super.key,
    required this.patch,
    this.fileName,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final lines = patch.split('\n');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          if (fileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Patch: $fileName',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

          // Diff Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((line) => _buildDiffLine(line)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffLine(String line) {
    Color? bgColor;
    Color? textColor;
    IconData? icon;

    if (line.startsWith('+') && !line.startsWith('+++')) {
      bgColor = Colors.green.withValues(alpha: isDark ? 0.2 : 0.1);
      textColor = isDark ? Colors.greenAccent : Colors.green[800];
      icon = Icons.add;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      bgColor = Colors.red.withValues(alpha: isDark ? 0.2 : 0.1);
      textColor = isDark ? Colors.redAccent : Colors.red[800];
      icon = Icons.remove;
    } else if (line.startsWith('@@')) {
      bgColor = Colors.blue.withValues(alpha: isDark ? 0.1 : 0.05);
      textColor = isDark ? Colors.blueAccent : Colors.blue[800];
    } else {
      textColor = isDark ? Colors.white70 : Colors.black87;
    }

    return Container(
      width: 800, // Fixed width for horizontal scrolling
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          // Gutter / Icon
          SizedBox(
            width: 20,
            child: icon != null 
              ? Icon(icon, size: 12, color: textColor?.withValues(alpha: 0.5))
              : null,
          ),
          const SizedBox(width: 8),
          // Code
          Expanded(
            child: Text(
              line,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
