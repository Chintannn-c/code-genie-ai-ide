import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium, ultra-minimal AI response planning and thinking animation widget.
/// Styled for modern dark UIs (background #050816) with extreme visual simplicity.
/// Does not use large glowing boxes, heavy gradients, or progress sweeps.
class AiThinkingIndicator extends StatefulWidget {
  /// Whether the thinking indicator is active and visible.
  final bool isActive;

  /// The list of status texts to cycle through.
  final List<String> statuses;

  /// The duration to display each status text before cycling.
  final Duration cycleInterval;

  /// Whether the status text cycles continuously in a loop.
  final bool loop;

  /// Triggered when the last status text is reached (only if [loop] is false).
  final VoidCallback? onCompleted;

  /// Optional trailing widget, e.g., small action tags or buttons.
  final Widget? trailing;

  /// Solid background color. Defaults to premium dark #050816.
  final Color backgroundColor;

  /// Border color. Defaults to subtle translucent slate.
  final Color borderColor;

  /// Accent color used for the breathing pulse dot and progress shimmer.
  final Color accentColor;

  /// Text color for the status text.
  final Color textColor;

  /// Whether the widget should expand to full width or stay compact.
  final bool isFullWidth;

  const AiThinkingIndicator({
    super.key,
    this.isActive = true,
    this.statuses = const [
      'Planning response...',
      'Thinking...',
      'Generating answer...',
      'Working...',
    ],
    this.cycleInterval = const Duration(milliseconds: 3000),
    this.loop = true,
    this.onCompleted,
    this.trailing,
    this.backgroundColor = const Color(0xFF0F111E), // sleek modern SaaS flat dark
    this.borderColor = const Color(0x1BFFFFFF),     // subtle thin transparent border
    this.accentColor = const Color(0xFF6366F1),      // premium indigo/blue accent
    this.textColor = const Color(0xDEFFFFFF),        // clean off-white
    this.isFullWidth = false,
  });

  @override
  State<AiThinkingIndicator> createState() => _AiThinkingIndicatorState();
}

class _AiThinkingIndicatorState extends State<AiThinkingIndicator> {
  int _currentIndex = 0;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  @override
  void didUpdateWidget(covariant AiThinkingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statuses != oldWidget.statuses || widget.cycleInterval != oldWidget.cycleInterval || widget.loop != oldWidget.loop) {
      _cycleTimer?.cancel();
      _currentIndex = 0;
      _startCycle();
    }
  }

  void _startCycle() {
    if (widget.statuses.isEmpty) return;

    _cycleTimer = Timer.periodic(widget.cycleInterval, (timer) {
      if (!mounted) return;
      
      if (_currentIndex < widget.statuses.length - 1) {
        setState(() {
          _currentIndex++;
        });
      } else if (widget.loop) {
        setState(() {
          _currentIndex = 0;
        });
      } else {
        timer.cancel();
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        }
      }
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  Color _getDotColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('plan') || lower.contains('context')) {
      return const Color(0xFF06B6D4); // Sleek Cyan
    } else if (lower.contains('think') || lower.contains('expert') || lower.contains('reason')) {
      return const Color(0xFF6366F1); // Indigo
    } else if (lower.contains('generat') || lower.contains('answer') || lower.contains('solv')) {
      return const Color(0xFFD946EF); // Violet/Magenta
    } else if (lower.contains('work') || lower.contains('run') || lower.contains('compil')) {
      return const Color(0xFF10B981); // Emerald Green
    }
    return widget.accentColor;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || widget.statuses.isEmpty) return const SizedBox.shrink();

    final status = widget.statuses[_currentIndex];
    final dotColor = _getDotColor(status);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Elegant Gemini/ChatGPT style fluid breathing dot
          _GeminiChatGptDot(color: dotColor),
          const SizedBox(width: 12),
          
          // Cycling status text (smooth slide and fade transition)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            child: Text(
              status,
              key: ValueKey<String>(status),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
                letterSpacing: 0.1,
              ),
            ),
          ),
          
          if (widget.trailing != null) ...[
            const Spacer(),
            widget.trailing!,
          ],
        ],
      ),
    );

    if (widget.isFullWidth) {
      return content;
    } else {
      return Center(
        child: IntrinsicWidth(
          child: content,
        ),
      );
    }
  }
}

/// A compact dot that gently breathes and pulses outward (ChatGPT/Gemini hybrid style)
class _GeminiChatGptDot extends StatefulWidget {
  final Color color;
  const _GeminiChatGptDot({required this.color});

  @override
  State<_GeminiChatGptDot> createState() => _GeminiChatGptDotState();
}

class _GeminiChatGptDotState extends State<_GeminiChatGptDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(18, 18),
          painter: _DotPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _DotPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DotPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 4.5;

    // Smooth, gentle size breath animation (ChatGPT/Gemini flat dot)
    final coreScale = 1.0 + (math.sin(progress * math.pi * 2) * 0.16);
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, baseRadius * coreScale, corePaint);
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
