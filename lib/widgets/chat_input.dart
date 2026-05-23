import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

// ============================================================
// COGNITIVE THOUGHT WAVE PAINTER (For Deep Mode Reasoning)
// ============================================================

class ThoughtWavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  ThoughtWavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    final yCenter = size.height / 2;

    for (double x = 0; x <= size.width; x += 2) {
      // Multiple sine waves superposition for complex thought visualizer
      double wave1 = math.sin((x * 0.035) + (animationValue * math.pi * 2)) * 6.0;
      double wave2 = math.cos((x * 0.015) - (animationValue * math.pi * 1.5)) * 3.0;
      path.lineTo(x, yCenter + wave1 + wave2);
    }

    canvas.drawPath(path, paint);

    // Draw secondary lighter path
    final path2 = Path();
    paint.color = color.withOpacity(0.12);
    for (double x = 0; x <= size.width; x += 2) {
      double wave1 = math.cos((x * 0.025) + (animationValue * math.pi * 1.2)) * 5.0;
      double wave2 = math.sin((x * 0.045) - (animationValue * math.pi * 2.0)) * 2.0;
      path2.lineTo(x, yCenter + wave1 + wave2);
    }
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant ThoughtWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

// ============================================================
// STRUCTURAL BLUEPRINT LINE PAINTER (For Plan Mode)
// ============================================================

class BlueprintPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  BlueprintPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw structural blueprint connector lines
    double stepWidth = size.width / 5;
    for (int i = 0; i <= 5; i++) {
      double x = i * stepWidth;
      // Draw grid ticks
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      
      // Draw pulsing blueprint node dots
      double pulse = 1.5 + math.sin((animationValue * math.pi * 2) + i) * 1.0;
      canvas.drawCircle(Offset(x, size.height / 2), pulse, dotPaint);
    }

    // Horizontal connection line
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

// ============================================================
// REDESIGNED ORCHESTRATION INPUT DOCK
// ============================================================

class ChatInput extends StatefulWidget {
  final String mode;
  final bool isStreaming;
  final VoidCallback onStop;
  final Widget? attachmentButton;
  final Function({required String prompt, String code, String error}) onSend;
  final bool isDark;
  final VoidCallback onToggleTerminal;
  final VoidCallback onToggleWeb;
  final bool isTerminalOpen;
  final bool isWebOpen;

  const ChatInput({
    super.key,
    required this.mode,
    required this.isStreaming,
    required this.onStop,
    required this.onSend,
    required this.onToggleTerminal,
    required this.onToggleWeb,
    required this.isTerminalOpen,
    required this.isWebOpen,
    this.attachmentButton,
    this.isDark = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _errorCtrl = TextEditingController();
  final _focus = FocusNode();
  String _detectedLang = 'python';
  String? _lastValue;
  
  // Voice interaction visual state
  bool _isVoiceRecording = false;
  late AnimationController _voiceController;

  // Custom Suggestion predictions
  final List<String> _suggestions = [
    'Analyze security threats',
    'Execute target build pipeline',
    'Refactor auth schema in Hive',
    'Examine current vector indices'
  ];

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
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _send();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    _focus.addListener(() => setState(() {}));

    _voiceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _codeCtrl.dispose();
    _errorCtrl.dispose();
    _focus.dispose();
    _voiceController.dispose();
    super.dispose();
  }

  String _detectLanguage(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('def ') || lower.contains('import ') || lower.contains('print(')) return 'python';
    if (lower.contains('public class ') || lower.contains('system.out.print')) return 'java';
    if (lower.contains('function ') || lower.contains('const ') || lower.contains('let ') || lower.contains('console.log')) return 'javascript';
    if (lower.contains('#include <') || lower.contains('std::cout')) return 'cpp';
    if (lower.contains('package ') && lower.contains('func ')) return 'go';
    if (lower.contains('void main()') || lower.contains('widget')) return 'dart';
    return 'python';
  }

  void _handleAutoClosing(String value) {
    final cp = context.read<ChatProvider>();
    if (!cp.isEditorMode) return;

    final selection = _promptCtrl.selection;
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

    if (lastChar == '(') closingChar = ')';
    else if (lastChar == '[') closingChar = ']';
    else if (lastChar == '{') closingChar = '}';
    else if (lastChar == '"') closingChar = '"';
    else if (lastChar == "'") closingChar = "'";

    if (closingChar != null) {
      final newText = value.substring(0, selection.start) + closingChar + value.substring(selection.start);
      _promptCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }
    _lastValue = _promptCtrl.text;
  }

  bool get _canSend => _promptCtrl.text.trim().isNotEmpty;

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
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    final isPlan = cp.isMissionMode;
    final isDeep = cp.useParallelOrchestration;

    // Glowing border color theme reflecting mode selection
    Color auraColor = const Color(0xFF64748B);
    if (isPlan && isDeep) {
      auraColor = const Color(0xFF06B6D4); // Neon Teal
    } else if (isPlan) {
      auraColor = const Color(0xFF10B981); // Neon Green
    } else if (isDeep) {
      auraColor = const Color(0xFF6366F1); // Neon Indigo
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONTEXT PREDICTOR CHIPS POPUP
          if (_promptCtrl.text.isEmpty && !_focus.hasFocus)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _suggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          suggestion,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: auraColor.withOpacity(0.85),
                          ),
                        ),
                        backgroundColor: widget.isDark ? const Color(0xFF13172E).withOpacity(0.4) : Colors.black.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: auraColor.withOpacity(0.2), width: 1.0),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _promptCtrl.text = suggestion;
                            _focus.requestFocus();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1),

          // Floating Adaptive Glass Dock Container
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF0B0E14).withOpacity(0.72)
                      : Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focus.hasFocus
                        ? auraColor.withOpacity(0.7)
                        : auraColor.withOpacity(0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (_focus.hasFocus)
                      BoxShadow(
                        color: auraColor.withOpacity(0.18),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.45 : 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Header indicators
                    Row(
                      children: [
                        if (cp.isEditorMode)
                          Container(
                            padding: const EdgeInsets.only(left: 16, top: 12),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: auraColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _detectedLang.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: auraColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'COMPILING CONTEXT',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: widget.isDark ? Colors.white24 : Colors.black26,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                        
                        const Spacer(),

                        // Memory Injection micro token
                        if (_focus.hasFocus)
                          Padding(
                            padding: const EdgeInsets.only(right: 16, top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.hub_rounded, size: 10, color: Color(0xFF818CF8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Memory Injected',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(),
                      ],
                    ),

                    // Main Textfield area
                    TextField(
                      controller: _promptCtrl,
                      focusNode: _focus,
                      maxLines: 8,
                      minLines: 1,
                      onChanged: _handleAutoClosing,
                      onSubmitted: (_) => _send(),
                      style: cp.isEditorMode
                          ? GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              height: 1.6,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            )
                          : GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: widget.isDark ? Colors.white : Colors.black87,
                            ),
                      decoration: InputDecoration(
                        hintText: cp.isEditorMode
                            ? 'Surgically insert code overrides...'
                            : (isPlan ? 'Command system targets... (Mission mode enabled)' : 'Ask Code Genie anything...'),
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: widget.isDark ? Colors.white30 : Colors.black38,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),

                    // Voice waveform overlay
                    if (_isVoiceRecording)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: AnimatedBuilder(
                          animation: _voiceController,
                          builder: (context, child) {
                            return SizedBox(
                              width: double.infinity,
                              height: 24,
                              child: CustomPaint(
                                painter: ThoughtWavePainter(
                                  animationValue: _voiceController.value,
                                  color: auraColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ).animate().fadeIn(),

                    // Actions Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          if (widget.attachmentButton != null) widget.attachmentButton!,
                          const SizedBox(width: 4),

                          // Web view toggle
                          _buildDockIcon(
                            icon: Icons.public_rounded,
                            isActive: widget.isWebOpen,
                            message: widget.isWebOpen ? 'Close Live Web Browser' : 'Launch Integrated Web Browser',
                            onPressed: widget.onToggleWeb,
                            color: auraColor,
                          ),
                          const SizedBox(width: 4),

                          // Terminal toggle
                          _buildDockIcon(
                            icon: Icons.terminal_rounded,
                            isActive: widget.isTerminalOpen,
                            message: widget.isTerminalOpen ? 'Hide Operations Cockpit' : 'Reveal Operations Cockpit',
                            onPressed: widget.onToggleTerminal,
                            color: auraColor,
                          ),
                          const SizedBox(width: 4),

                          // Interactive Voice Waveform toggle
                          Tooltip(
                            message: _isVoiceRecording ? 'Stop Voice Recording' : 'Orchestrate by Voice Command',
                            child: IconButton(
                              icon: Icon(
                                _isVoiceRecording ? Icons.settings_voice_rounded : Icons.keyboard_voice_rounded,
                                size: 20,
                                color: _isVoiceRecording 
                                    ? const Color(0xFFEF4444) 
                                    : (widget.isDark ? Colors.white38 : Colors.black38),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isVoiceRecording = !_isVoiceRecording;
                                });
                              },
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),

                          const Spacer(),
                          
                          // Custom Plan & Deep Mode switches
                          _buildMissionToggle(),
                          const SizedBox(width: 8),
                          _buildOrchestratorToggle(),
                          const SizedBox(width: 8),
                          _buildSendButton(),
                        ],
                      ),
                    ),

                    // Plan or Deep mode Custom-Painted blueprint strips at bottom edge
                    if (isPlan || isDeep)
                      AnimatedBuilder(
                        animation: _voiceController,
                        builder: (context, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 6,
                            child: CustomPaint(
                              painter: isDeep
                                  ? ThoughtWavePainter(animationValue: _voiceController.value, color: auraColor)
                                  : BlueprintPainter(animationValue: _voiceController.value, color: auraColor),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockIcon({
    required IconData icon,
    required bool isActive,
    required String message,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Tooltip(
      message: message,
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isActive ? color : (widget.isDark ? Colors.white38 : Colors.black38),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildOrchestratorToggle() {
    final cp = context.watch<ChatProvider>();
    final isActive = cp.useParallelOrchestration;

    return Tooltip(
      message: 'Orchestrate cognitive debates and multi-agent chains',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          cp.toggleParallelOrchestration();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6366F1).withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF6366F1).withOpacity(0.35) : (widget.isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 18,
                color: isActive ? const Color(0xFF818CF8) : (widget.isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 6),
              Text(
                'Deep',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive ? const Color(0xFF818CF8) : (widget.isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionToggle() {
    final cp = context.watch<ChatProvider>();
    final isActive = cp.isMissionMode;

    return Tooltip(
      message: 'Plan structured visual timeline sequencing',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          cp.toggleMissionMode();
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF10B981).withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF10B981).withOpacity(0.32) : (widget.isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: isActive ? const Color(0xFF10B981) : (widget.isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 6),
              Text(
                'Plan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive ? const Color(0xFF10B981) : (widget.isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
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
        onTap: () {
          if (isStop) {
            HapticFeedback.mediumImpact();
            widget.onStop();
          } else {
            HapticFeedback.mediumImpact();
            _send();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isStop ? 16 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            gradient: canSend && !isStop
                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                : null,
            color: isStop
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : (!canSend
                    ? (widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05))
                    : null),
            borderRadius: BorderRadius.circular(14),
            border: isStop ? Border.all(color: const Color(0xFFF87171).withOpacity(0.4), width: 1.5) : null,
            boxShadow: [
              if (canSend && !isStop)
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              if (isStop)
                BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStop ? Icons.stop_circle_rounded : Icons.send_rounded,
                color: canSend
                    ? (isStop ? const Color(0xFFF87171) : Colors.white)
                    : (widget.isDark ? Colors.white24 : Colors.black26),
                size: 20,
              ),
              if (isStop) ...[
                const SizedBox(width: 8),
                Text(
                  'Abort Engine',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFF87171),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        )
        .animate(target: canSend ? 1 : 0)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        ),
      ),
    );
  }
}
