import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'code_execution_panel.dart';
import '../providers/chat_provider.dart';

class CodePanel extends StatelessWidget {
  final String code;
  final String language;
  final bool isDark;

  const CodePanel({
    super.key,
    required this.code,
    required this.language,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();

    if (code.isEmpty) {
      return Container(
        width: 400,
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.code_rounded,
                size: 48,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'No code generated yet',
                style: GoogleFonts.plusJakartaSans(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, cp),
          _buildActionBar(context, cp),
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  code,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChatProvider cp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
          const SizedBox(width: 10),
          Text(
            language.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 18),
            onPressed: () => _handleDownload(context),
            tooltip: 'Download as file',
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            tooltip: 'Copy Code',
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, ChatProvider cp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildActionChip(
            label: 'RUN',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF10B981),
            onTap: () => _showExecutionPanel(context),
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            label: 'FIX',
            icon: Icons.bug_report_rounded,
            color: const Color(0xFFF43F5E),
            onTap: () => cp.fixCode(code, language),
          ),
        
        ],
      ),
    );
  }

  void _showExecutionPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CodeExecutionPanel(
        initialCode: code,
        language: language,
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDownload(BuildContext context) {
    // Simple copy as simulation for now, 
    // or just show snackbar that it would download
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preparing ${language.toLowerCase()} file for download...')),
    );
  }
}
