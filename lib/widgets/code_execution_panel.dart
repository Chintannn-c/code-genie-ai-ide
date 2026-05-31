import 'dart:convert';

import 'package:ai_coding/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../config/api_config.dart';

class CodeExecutionPanel extends StatefulWidget {
  final String initialCode;
  final String language;
  final String? sourceFilePath; // optional: for hot-patching back to workspace

  const CodeExecutionPanel({
    super.key,
    required this.initialCode,
    required this.language,
    this.sourceFilePath,
  });

  @override
  State<CodeExecutionPanel> createState() => _CodeExecutionPanelState();
}

class _CodeExecutionPanelState extends State<CodeExecutionPanel> {
  late TextEditingController _codeController;
  final FocusNode _focusNode = FocusNode();
  String _output = "";
  String? _error;
  bool _isRunning = false;
  double? _executionTime;

  // ── New state for enhanced features ──
  List<String> _images = [];        // base64-encoded image data URIs
  String? _notice;                  // auto-heal informational notice
  List<String> _autoInstalled = []; // auto-installed packages
  bool _isPatching = false;         // hot-patch loading state

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _runCode() async {
    setState(() {
      _isRunning = true;
      _output = "";
      _error = null;
      _executionTime = null;
      _images = [];
      _notice = null;
      _autoInstalled = [];
    });

    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.execute}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'code': _codeController.text,
          'language': widget.language,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _output = data['output'] ?? "";
          _error = data['error'];
          _executionTime = data['execution_time'];
          // Parse new enhanced fields
          if (data['images'] != null) {
            _images = List<String>.from(data['images']);
          }
          _notice = data['notice'];
          if (data['auto_installed'] != null) {
            _autoInstalled = List<String>.from(data['auto_installed']);
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = "Server Error: ${response.statusCode}\n${response.body}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Connection Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _hotPatch() async {
    if (widget.sourceFilePath == null || widget.sourceFilePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No source file path available for hot-patching.',
            style: GoogleFonts.jetBrainsMono(fontSize: 12),
          ),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isPatching = true);
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.hotpatch}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'file_path': widget.sourceFilePath,
          'code': _codeController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data['message'] ?? 'File patched successfully!',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF7C3AED),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hot-patch failed: ${response.body}',
              style: GoogleFonts.jetBrainsMono(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFF85149),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hot-patch error: $e',
              style: GoogleFonts.jetBrainsMono(fontSize: 12)),
          backgroundColor: const Color(0xFFF85149),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPatching = false);
    }
  }

  /// Decode a base64 data URI to bytes for Image.memory
  Uint8List? _decodeBase64Image(String dataUri) {
    try {
      final parts = dataUri.split(',');
      if (parts.length == 2) {
        return base64Decode(parts[1]);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();

    // Real-time synchronization: Update controller if AI code changes and we are not focused
    if (chatProvider.latestCode != _codeController.text && !chatProvider.isLoading) {
       // Only sync if the AI is actively streaming OR if the initial code was empty
       if (chatProvider.isStreaming || _codeController.text.isEmpty) {
         _codeController.text = chatProvider.latestCode;
       }
    }
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle and Header
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'EDITOR (${widget.language.toUpperCase()})',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white38 : Colors.black38,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _codeController.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy current code',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black54, size: 18),
                  ),
                ],
              ),
            ),
          ),
          
          const Divider(height: 1),

          // Action Bar (Moved Above Editor)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF0F2F5),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // ── RUN button ──
                  ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runCode,
                    icon: _isRunning 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(_isRunning ? 'RUN' : 'RUN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_error != null) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        final cp = context.read<ChatProvider>();
                        cp.setMode('debug');
                        cp.setLanguage(widget.language);
                        cp.sendMessage(
                          prompt: "Fix this code and explain what's wrong.",
                          code: _codeController.text,
                          error: _error!,
                        );
                        Navigator.pop(context); // Close panel to see the response
                      },
                      icon: const Icon(Icons.bug_report_rounded, size: 16, color: Color(0xFFF43F5E)),
                      label: const Text('FIX'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF43F5E),
                        side: const BorderSide(color: Color(0xFFF43F5E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // ── OPTIMIZE button ──
                  OutlinedButton.icon(
                    onPressed: () {
                      final cp = context.read<ChatProvider>();
                      cp.optimizeCode(_codeController.text, widget.language);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                    label: const Text('OPTIMIZE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF59E0B),
                      side: const BorderSide(color: Color(0xFFF59E0B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── HOT PATCH button ──
                  _buildHotPatchButton(isDark),
                  if (_executionTime != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${_executionTime}s',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const Divider(height: 1),

          // Editor Section
          Expanded(
            flex: 6,
            child: Container(
              color: isDark ? const Color(0xFF090C10) : const Color(0xFFF6F8FA),
              child: GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: TextField(
                  controller: _codeController,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  readOnly: false,
                  enabled: true,
                  cursorColor: const Color(0xFF238636),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? const Color(0xFFE6EDF3) : Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(20),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),

          // Terminal Section (with auto-heal notice + images)
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF010409),
              padding: const EdgeInsets.all(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: SingleChildScrollView(
                  key: ValueKey('${_output.length}_${_error?.length}_${_images.length}_$_isRunning'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Auto-Heal Notice Banner ──
                      if (_notice != null)
                        _buildAutoHealBanner(),
                      
                      if (_output.isEmpty && _error == null && !_isRunning && _images.isEmpty)
                        Text(
                          'Ready for execution...',
                          style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 13),
                        ),
                      if (_isRunning)
                        Text(
                          'Executing code...',
                          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF6366F1), fontSize: 13),
                        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds),
                      if (_output.isNotEmpty)
                        Text(
                          _output,
                          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF7EE787), fontSize: 13),
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF85149), fontSize: 13),
                        ),
                      
                      // ── Rendered Images (Graphs/Charts) ──
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._images.map((dataUri) => _buildImageCard(dataUri)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // HOT PATCH BUTTON — Premium violet/cyan gradient
  // ═══════════════════════════════════════════════════
  Widget _buildHotPatchButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isPatching ? null : _hotPatch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isPatching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'HOT PATCH',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // AUTO-HEAL NOTICE BANNER
  // ═══════════════════════════════════════════════════
  Widget _buildAutoHealBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.15),
            const Color(0xFF06B6D4).withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.healing_rounded, size: 16, color: Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AUTO-HEAL',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF7C3AED),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _notice!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: const Color(0xFFB4BCD0),
                    height: 1.4,
                  ),
                ),
                if (_autoInstalled.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: _autoInstalled.map((pkg) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF238636).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF238636).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        pkg,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: const Color(0xFF7EE787),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);
  }

  // ═══════════════════════════════════════════════════
  // IMAGE CARD — Glassmorphism display for graphs/plots
  // ═══════════════════════════════════════════════════
  Widget _buildImageCard(String dataUri) {
    final bytes = _decodeBase64Image(dataUri);
    if (bytes == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          '⚠️ Failed to decode image.',
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF59E0B), fontSize: 11),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_graph_rounded, size: 14, color: Color(0xFF06B6D4)),
                const SizedBox(width: 6),
                Text(
                  'GENERATED OUTPUT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF06B6D4),
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: dataUri));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image data copied to clipboard')),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF606770)),
                ),
              ],
            ),
          ),
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '⚠️ Image render failed.',
                  style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF59E0B), fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96));
  }
}
