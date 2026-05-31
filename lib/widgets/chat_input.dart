import 'dart:math' as math;
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../models/app_file.dart';

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
      if (event is KeyDownEvent) {
        if ((event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _send();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyV &&
            HardwareKeyboard.instance.isControlPressed) {
          final cp = context.read<ChatProvider>();
          _handleClipboardPaste(cp);
          return KeyEventResult.handled;
        }
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

  Widget _buildImageThumbnail(AppFile file) {
    if (file.platformFile == null) return const Icon(Icons.image_rounded, size: 40, color: Color(0xFF89DCEB));
    
    // Multiplatform check for web vs native
    if (kIsWeb) {
      if (file.platformFile!.bytes != null) {
        return Image.memory(file.platformFile!.bytes!, fit: BoxFit.cover);
      }
    } else {
      if (file.platformFile!.path != null) {
        return Image.file(io.File(file.platformFile!.path!), fit: BoxFit.cover);
      }
    }
    return const Icon(Icons.image_rounded, size: 40, color: Color(0xFF89DCEB));
  }

  Future<void> _handleClipboardPaste(ChatProvider cp) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        cp.uploadFiles(result.files);
        if (_promptCtrl.text.trim().isEmpty) {
          _promptCtrl.text = "Generate UI code from this screenshot";
        }
      }
    } catch (e) {
      debugPrint("Paste handler warning: $e");
    }
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

  bool get _canSend {
    final cp = context.read<ChatProvider>();
    return _promptCtrl.text.trim().isNotEmpty && !cp.isSessionExpired && !cp.isRateLimited;
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
  Widget build(BuildContext context) {
    final cp = context.watch<ChatProvider>();
    final isPlan = cp.isMissionMode;
    final isDeep = cp.useParallelOrchestration;


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
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252),
                          ),
                        ),
                        backgroundColor: widget.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        onPressed: cp.isSessionExpired ? null : () {
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

          // Flat input container — no blur, no glow
          AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF141414)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _focus.hasFocus
                        ? (widget.isDark ? const Color(0xFF8B8BF5) : const Color(0xFF6366F1))
                        : (widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08)),
                    width: 1,
                  ),
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
                                    color: widget.isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _detectedLang.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6B6B6B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'COMPILING CONTEXT',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B6B6B),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(),
                        
                        const Spacer(),

                        // Memory Injection micro token
                        if (_focus.hasFocus)
                          Padding(
                            padding: const EdgeInsets.only(right: 16, top: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.06) : const Color(0x00000000).withValues(alpha: 0.04),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.hub_rounded, size: 10, color: const Color(0xFF6B6B6B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Memory Injected',
                                    style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w500, color: const Color(0xFF6B6B6B)),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(),
                      ],
                    ),

                    // Image attachment thumbnail preview
                    if (cp.selectedFiles.any((f) => f.fileName.toLowerCase().endsWith('.png') || f.fileName.toLowerCase().endsWith('.jpg') || f.fileName.toLowerCase().endsWith('.jpeg')))
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: cp.selectedFiles.where((f) => f.fileName.toLowerCase().endsWith('.png') || f.fileName.toLowerCase().endsWith('.jpg') || f.fileName.toLowerCase().endsWith('.jpeg')).map((file) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF89DCEB).withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _buildImageThumbnail(file),
                                  ),
                                ),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: GestureDetector(
                                    onTap: () => cp.removeFile(file.fileId),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF38BA8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 12,
                                        color: Color(0xFF11111B),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    // Visual Dropzone Panel (renders if no images are currently selected)
                    if (!cp.selectedFiles.any((f) => f.fileName.toLowerCase().endsWith('.png') || f.fileName.toLowerCase().endsWith('.jpg') || f.fileName.toLowerCase().endsWith('.jpeg')))
                      GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            cp.uploadFiles(result.files);
                            // Auto set prompt
                            if (_promptCtrl.text.trim().isEmpty) {
                              _promptCtrl.text = "Generate UI code from this screenshot";
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF89DCEB).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF89DCEB).withValues(alpha: 0.15),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Color(0xFF89DCEB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Paste or click to upload a UI screenshot for Screenshot-to-Code',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFCDD6F4).withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Main Textfield area
                    TextField(
                      controller: _promptCtrl,
                      focusNode: _focus,
                      enabled: !cp.isSessionExpired && !cp.isRateLimited,
                      maxLines: 8,
                      minLines: 1,
                      onChanged: _handleAutoClosing,
                      onSubmitted: (_) => _send(),
                      style: (cp.isSessionExpired || cp.isRateLimited)
                          ? GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF404040),
                            )
                          : cp.isEditorMode
                          ? GoogleFonts.jetBrainsMono(
                              fontSize: 14,
                              height: 1.6,
                              color: widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
                            )
                          : GoogleFonts.inter(
                              fontSize: 14,
                              color: widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
                            ),
                      decoration: InputDecoration(
                        hintText: cp.isRateLimited
                            ? 'Rate limit reached. Please wait ${cp.rateLimitRemainingSeconds}s before generating again.'
                            : (cp.isEditorMode
                                ? 'Surgically insert code overrides...'
                                : (isPlan ? 'Command system targets... (Mission mode enabled)' : 'Ask Code Genie anything...')),
                        hintStyle: GoogleFonts.inter(
                          color: widget.isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D4),
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
                                  color: const Color(0xFF6B6B6B),
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
                            color: const Color(0xFF6B6B6B),
                          ),
                          const SizedBox(width: 4),

                          // Terminal toggle
                          _buildDockIcon(
                            icon: Icons.terminal_rounded,
                            isActive: widget.isTerminalOpen,
                            message: widget.isTerminalOpen ? 'Hide Operations Cockpit' : 'Reveal Operations Cockpit',
                            onPressed: widget.onToggleTerminal,
                            color: const Color(0xFF6B6B6B),
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
                                    : const Color(0xFF6B6B6B),
                              ),
                              onPressed: cp.isSessionExpired ? null : () {
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

                    // Plan or Deep mode line strip — simplified
                    if (isPlan || isDeep)
                      Container(
                        width: double.infinity,
                        height: 2,
                        color: widget.isDark ? const Color(0xFF242424) : const Color(0xFFE5E5E5),
                      ),
                  ],
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
        onPressed: context.read<ChatProvider>().isSessionExpired ? null : () {
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
        onTap: cp.isSessionExpired ? null : () {
          HapticFeedback.selectionClick();
          cp.toggleParallelOrchestration();
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? (widget.isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? (widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08))
                  : (widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.06) : const Color(0x00000000).withValues(alpha: 0.04)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 18,
                color: isActive
                    ? (widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A))
                    : const Color(0xFF6B6B6B),
              ),
              const SizedBox(width: 6),
              Text(
                'Deep',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? (widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A))
                      : const Color(0xFF6B6B6B),
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
        onTap: cp.isSessionExpired ? null : () {
          HapticFeedback.selectionClick();
          cp.toggleMissionMode();
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? (widget.isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? (widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08))
                  : (widget.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.06) : const Color(0x00000000).withValues(alpha: 0.04)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: isActive
                    ? (widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A))
                    : const Color(0xFF6B6B6B),
              ),
              const SizedBox(width: 6),
              Text(
                'Plan',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? (widget.isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A))
                      : const Color(0xFF6B6B6B),
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
        onTap: context.read<ChatProvider>().isSessionExpired ? null : () {
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
            color: isStop
                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                : (canSend
                    ? (widget.isDark ? const Color(0xFF8B8BF5) : const Color(0xFF6366F1))
                    : (widget.isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5))),
            borderRadius: BorderRadius.circular(6),
            border: isStop
                ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStop ? Icons.stop_circle_rounded : Icons.send_rounded,
                color: canSend
                    ? (isStop ? const Color(0xFFEF4444) : Colors.white)
                    : const Color(0xFF6B6B6B),
                size: 20,
              ),
              if (isStop) ...[
                const SizedBox(width: 8),
                Text(
                  'Stop',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
