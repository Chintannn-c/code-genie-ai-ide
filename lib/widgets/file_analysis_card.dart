import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Specialized card for showing file analysis results (summary, issues, suggestions).
class FileAnalysisCard extends StatelessWidget {
  final String summary;
  final List<String> issues;
  final List<String> suggestions;
  final bool isDark;

  const FileAnalysisCard({
    super.key,
    required this.summary,
    required this.issues,
    required this.suggestions,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(Icons.analytics_rounded, 'File Analysis'),
          const SizedBox(height: 12),
          _buildSection('Summary', summary),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildListSection('Potential Issues', issues, Colors.redAccent),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildListSection('Suggestions', suggestions, Colors.blueAccent),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: accentColor.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
