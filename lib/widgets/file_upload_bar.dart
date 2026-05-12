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
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index == files.length) {
                  return _buildAddMoreCard();
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
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIconForLang(file.language),
                  size: 24,
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.sizeString,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: -8,
            top: -8,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
              onPressed: () => onRemove(file.fileId),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreCard() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          style: BorderStyle.solid,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(height: 4),
          Text(
            'Add files',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
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
