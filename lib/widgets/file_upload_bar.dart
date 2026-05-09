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
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final file = files[index];
                return _buildFileItem(context, file);
              },
            ),
          ),
          if (files.length > 1) ...[
            const SizedBox(width: 16),
            _buildProjectActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: onAnalyzeProject,
          icon: const Icon(Icons.layers_rounded, size: 14),
          label: const Text('ANALYZE PROJECT'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 20),
          ),
          child: Text(
            'Clear All',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(BuildContext context, AppFile file) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForLang(file.language),
            size: 18,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  file.sizeString,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          _actionMenu(context, file),
        ],
      ),
    );
  }

  Widget _actionMenu(BuildContext context, AppFile file) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 14,
        color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
      ),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'analyze',
          child: Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16),
              SizedBox(width: 8),
              Text('Analyze', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Remove', style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'remove') onRemove(file.fileId);
        if (val == 'analyze') onAnalyze(file.fileId);
      },
    );
  }

  IconData _getIconForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'python': return Icons.terminal_rounded;
      case 'dart': return Icons.flutter_dash_rounded;
      case 'javascript':
      case 'typescript': return Icons.javascript_rounded;
      case 'html': return Icons.html_rounded;
      case 'css': return Icons.css_rounded;
      default: return Icons.description_outlined;
    }
  }
}
