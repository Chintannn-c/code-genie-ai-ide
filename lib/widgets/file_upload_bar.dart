import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_file.dart';

/// Horizontal bar showing uploaded files before analysis.
class FileUploadBar extends StatelessWidget {
  final List<AppFile> files;
  final Function(String) onRemove;
  final Function(String) onAnalyze;
  final VoidCallback? onAnalyzeProject;
  final VoidCallback? onClearAll;
  final bool isDark;

  const FileUploadBar({
    super.key,
    required this.files,
    required this.onRemove,
    required this.onAnalyze,
    this.onAnalyzeProject,
    this.onClearAll,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F0F12).withValues(alpha: 0.7)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length + (onAnalyzeProject != null ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                if (index == files.length) {
                  return _buildProjectActionCard();
                }
                final file = files[index];
                return _buildFileCard(context, file);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, AppFile file) {
    final themeColor = _getColorForLang(file.language);
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131316).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Futuristic Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              _getIconForLang(file.language),
              size: 20,
              color: themeColor,
            ),
          ),
          const SizedBox(width: 12),

          // Metadata (Name & Size)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  file.sizeString,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white10 : Colors.black12,
          ),

          const SizedBox(width: 8),

          // Actions Column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Close/Remove Button
              GestureDetector(
                onTap: () => onRemove(file.fileId),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Analyze Button
              GestureDetector(
                onTap: () => onAnalyze(file.fileId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: Color(0xFF818CF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Analyze',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectActionCard() {
    return InkWell(
      onTap: onAnalyzeProject,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_copy_rounded,
                size: 20,
                color: Color(0xFF818CF8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Analyze Project',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Scan workspace',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white24 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return const Color(0xFF38BDF8);
      case 'dart':
        return const Color(0xFF0EA5E9);
      case 'javascript':
      case 'typescript':
        return const Color(0xFFFBBF24);
      case 'html':
        return const Color(0xFFF97316);
      case 'css':
        return const Color(0xFF818CF8);
      default:
        return const Color(0xFFA78BFA);
    }
  }

  IconData _getIconForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return Icons.terminal_rounded;
      case 'dart':
        return Icons.flutter_dash_rounded;
      case 'javascript':
      case 'typescript':
        return Icons.javascript_rounded;
      case 'html':
        return Icons.html_rounded;
      case 'css':
        return Icons.css_rounded;
      default:
        return Icons.description_outlined;
    }
  }
}
