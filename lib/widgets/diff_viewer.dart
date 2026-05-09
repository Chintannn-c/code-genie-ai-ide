import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DiffViewer extends StatelessWidget {
  final String diff;
  final bool isDark;

  const DiffViewer({
    super.key,
    required this.diff,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final lines = diff.split('\n');
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 64,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) => _buildLine(line)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(String line) {
    Color? bgColor;
    Color? textColor;
    
    if (line.startsWith('+') && !line.startsWith('+++')) {
      bgColor = Colors.green.withValues(alpha: isDark ? 0.15 : 0.1);
      textColor = isDark ? Colors.greenAccent : Colors.green[800];
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      bgColor = Colors.red.withValues(alpha: isDark ? 0.15 : 0.1);
      textColor = isDark ? Colors.redAccent : Colors.red[800];
    } else if (line.startsWith('@@')) {
      bgColor = Colors.blue.withValues(alpha: 0.1);
      textColor = isDark ? Colors.blueAccent : Colors.blue[800];
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Text(
        line,
        style: GoogleFonts.firaCode(
          fontSize: 11,
          color: textColor ?? (isDark ? Colors.white70 : Colors.black87),
          height: 1.5,
        ),
      ),
    );
  }
}
