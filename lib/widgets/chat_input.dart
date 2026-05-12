import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ChatInput extends StatefulWidget {
  final String mode;
  final bool isStreaming;
  final VoidCallback onStop;
  final Widget? attachmentButton;
  final Function({required String prompt, String code, String error}) onSend;
  final bool isDark;

  const ChatInput({
    super.key,
    required this.mode,
    required this.isStreaming,
    required this.onStop,
    required this.onSend,
    this.attachmentButton,
    this.isDark = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _promptCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _errorCtrl = TextEditingController();
  final _focus = FocusNode();

  String _detectedLang = 'python';

  @override
  void initState() {
    super.initState();
    _promptCtrl.addListener(() {
      final cp = context.read<ChatProvider>();
      if (cp.isEditorMode) {
        final newLang = _detectLanguage(_promptCtrl.text);
        if (newLang != _detectedLang) {
          setState(() => _detectedLang = newLang);
          cp.setLanguage(newLang);
        }
      }
      setState(() {});
    });
    
    _focus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent && 
          event.logicalKey == LogicalKeyboardKey.enter && 
          !HardwareKeyboard.instance.isShiftPressed) {
        _send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    
    _focus.addListener(() => setState(() {}));
  }

  String _detectLanguage(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('def ') ||
        lower.contains('import ') ||
        lower.contains('print('))
      return 'python';
    if (lower.contains('public class ') || lower.contains('system.out.print'))
      return 'java';
    if (lower.contains('function ') ||
        lower.contains('const ') ||
        lower.contains('let ') ||
        lower.contains('console.log'))
      return 'javascript';
    if (lower.contains('#include <') || lower.contains('std::cout'))
      return 'cpp';
    if (lower.contains('package ') && lower.contains('func ')) return 'go';
    if (lower.contains('void main()') || lower.contains('widget'))
      return 'dart';
    return 'python'; // Default
  }

  void _handleAutoClosing(String value) {
    final cp = context.read<ChatProvider>();
    if (!cp.isEditorMode) return;

    final selection = _promptCtrl.selection;
    // Only trigger if we just typed one character (length increased by 1)
    if (value.length <= (_lastValue?.length ?? 0)) {
      _lastValue = value;
      return;
    }

    if (selection.start != selection.end || selection.start < 1) {
      _lastValue = value;
      return;
    }

    final lastChar = value[selection.start - 1];
    String? closingChar;

    if (lastChar == '(')
      closingChar = ')';
    else if (lastChar == '[')
      closingChar = ']';
    else if (lastChar == '{')
      closingChar = '}';
    else if (lastChar == '"')
      closingChar = '"';
    else if (lastChar == "'")
      closingChar = "'";

    if (closingChar != null) {
      final newText =
          value.substring(0, selection.start) +
          closingChar +
          value.substring(selection.start);

      _promptCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }
    _lastValue = _promptCtrl.text;
  }

  String? _lastValue;

  bool get _canSend {
    return _promptCtrl.text.trim().isNotEmpty;
  }

  void _send() {
    if (!_canSend || widget.isStreaming) return;

    final cp = context.read<ChatProvider>();
    widget.onSend(
      prompt: _promptCtrl.text.trim(),
      code: cp.isEditorMode ? _promptCtrl.text.trim() : _codeCtrl.text.trim(),
      error: _errorCtrl.text.trim(),
    );
    _promptCtrl.clear();
    _codeCtrl.clear();
    _errorCtrl.clear();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _codeCtrl.dispose();
    _errorCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1F2937).withValues(
                        alpha: 0.8,
                      ) // High-performance translucent solid
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focus.hasFocus
                      ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                      : widget.isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.4 : 0.1,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.attachmentButton != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: widget.attachmentButton!,
                    ),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (context.watch<ChatProvider>().isEditorMode)
                          Container(
                            padding: const EdgeInsets.only(left: 16, top: 12),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _detectedLang.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SYNTAX DETECTED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark
                                        ? Colors.white24
                                        : Colors.black26,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                          ),
                        TextField(
                          controller: _promptCtrl,
                          focusNode: _focus,
                          maxLines: 5,
                          minLines: 1,
                          onChanged: _handleAutoClosing,
                          onSubmitted: (_) => _send(),
                          style: context.watch<ChatProvider>().isEditorMode
                              ? GoogleFonts.jetBrainsMono(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                )
                              : GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                          decoration: InputDecoration(
                            hintText: context.watch<ChatProvider>().isEditorMode
                                ? 'Write code here...'
                                : 'Ask me anything...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.black38,
                              fontSize: 14,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOrchestratorToggle(),
                        const SizedBox(width: 4),
                        _buildSendButton(),
                      ],
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

  Widget _buildOrchestratorToggle() {
    final cp = context.watch<ChatProvider>();
    final isActive = cp.useParallelOrchestration;

    return Tooltip(
      message: 'Parallel AI Orchestration (Multi-Model)',
      child: GestureDetector(
        onTap: cp.toggleParallelOrchestration,
        child: const Icon(Icons.psychology_rounded, size: 24)
            .animate(target: isActive ? 1 : 0)
            .shimmer(
              duration: 1500.ms,
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            )
            .tint(
              color: isActive
                  ? const Color(0xFF6366F1)
                  : (widget.isDark ? Colors.white38 : Colors.black38),
            ),
      ),
    );
  }

  Widget _buildSendButton() {
    final bool isStop = widget.isStreaming;
    final bool canSend = _canSend || isStop;

    return MouseRegion(
      cursor: canSend ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: isStop ? widget.onStop : _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: canSend && !isStop
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  )
                : null,
            color: isStop
                ? Colors.redAccent.withValues(alpha: 0.15)
                : (!canSend
                    ? (widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
                    : null),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (canSend && !isStop)
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(
            isStop ? Icons.stop_rounded : Icons.send_rounded,
            color: canSend
                ? (isStop ? Colors.redAccent : Colors.white)
                : (widget.isDark ? Colors.white24 : Colors.black26),
            size: 20,
          ),
        ).animate(target: canSend ? 1 : 0).scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1, 1),
              duration: 200.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }
}
