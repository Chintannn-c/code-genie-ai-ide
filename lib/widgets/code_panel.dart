import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'code_execution_panel.dart';
import '../providers/chat_provider.dart';

class CodePanel extends StatefulWidget {
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
  State<CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<CodePanel> {
  WebViewController? _webController;
  bool _isPreviewReady = false;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  @override
  void didUpdateWidget(CodePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.isDark != widget.isDark) {
      _initPreview();
    }
  }

  void _initPreview() {
    if (kIsWeb) return;
    try {
      final hasHTML = widget.code.contains('<html>') ||
          widget.code.contains('<!DOCTYPE html>') ||
          widget.language.toLowerCase() == 'html';

      if (hasHTML && widget.code.trim().isNotEmpty) {
        _webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(widget.isDark ? const Color(0xFF0F172A) : Colors.white)
          ..loadHtmlString(widget.code);
        _isPreviewReady = true;
      } else {
        _isPreviewReady = false;
      }
    } catch (_) {
      _isPreviewReady = false;
    }
  }

  String _getFileExtension(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return 'py';
      case 'javascript':
      case 'js':
        return 'js';
      case 'typescript':
      case 'ts':
        return 'ts';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'dart':
        return 'dart';
      default:
        return 'txt';
    }
  }

  Future<void> _handleDownload(BuildContext context) async {
    try {
      final ext = _getFileExtension(widget.language);
      if (kIsWeb) {
        final uri = Uri.parse(
          'data:text/plain;charset=utf-8,${Uri.encodeComponent(widget.code)}',
        );
        final canLaunch = await canLaunchUrl(uri);
        if (!context.mounted) return;
        if (canLaunch) {
          await launchUrl(uri);
          if (!context.mounted) return;
          _showSnackBar(context, 'File download successfully triggered.');
        } else {
          throw Exception('Browser blocked URL download.');
        }
      } else {
        // Native Platforms (Desktop/Mobile)
        final fileName = 'genie_export_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final file = File('./$fileName');
        await file.writeAsString(widget.code);
        if (!context.mounted) return;
        _showSnackBar(context, 'File saved locally as $fileName inside your workspace.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showSnackBar(context, 'Save failed: $e', isError: true);
    }
  }

  void _showSnackBar(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();

    if (widget.code.isEmpty && !cp.isWebMode) {
      return Container(
        width: 400,
        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.code_rounded,
                size: 48,
                color: widget.isDark ? Colors.white10 : Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                'No code generated yet',
                style: GoogleFonts.plusJakartaSans(
                  color: widget.isDark ? Colors.white24 : Colors.black26,
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
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          left: BorderSide(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, cp),
          if (!cp.isWebMode) _buildActionBar(context, cp),
          Expanded(
            child: cp.isWebMode ? _buildWebView(context) : _buildCodeArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeArea() {
    return Container(
      color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          widget.code,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            height: 1.5,
            color: widget.isDark
                ? const Color(0xFFE2E8F0)
                : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(BuildContext context) {
    if (kIsWeb) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.web_rounded,
                size: 48,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(height: 16),
              Text(
                'Web Mode Preview Active',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Web preview rendering is optimized for native app devices. Copy or download the HTML code to view it directly in your browser.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPreviewReady && _webController != null) {
      return WebViewWidget(controller: _webController!);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 12, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Preview target not connected',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
                Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.web_rounded,
                      size: 40,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'HTML Preview Not Loaded',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ensure the generated code is a valid HTML web page structure to automatically load a live sandboxed web view.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: widget.isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
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
      color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Icon(
            Icons.terminal_rounded,
            size: 18,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 10),
          Text(
            widget.language.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.isDark ? Colors.white70 : Colors.black54,
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
              Clipboard.setData(ClipboardData(text: widget.code));
              _showSnackBar(context, 'Code copied to clipboard.');
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
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.08),
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
            onTap: () => cp.fixCode(widget.code, widget.language),
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
      builder: (context) =>
          CodeExecutionPanel(initialCode: widget.code, language: widget.language),
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
}
