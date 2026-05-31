import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A premium, expandable AI response planning and thinking animation widget.
/// Styled for modern dark UIs (background #0F111E) with extreme visual simplicity.
/// Shows progress stages in a collapsible vertical timeline.
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

  /// Solid background color. Defaults to premium dark #0F111E.
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
      '🧠 Understanding request...',
      '📋 Planning solution...',
      '💻 Writing code...',
      '🧪 Testing logic...',
      '✅ Finalizing response...',
    ],
    this.cycleInterval = const Duration(milliseconds: 2500),
    this.loop = false,
    this.onCompleted,
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
  bool _isExpanded = false;

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

  Color _getDotColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFF06B6D4); // Cyan (Understanding)
      case 1:
        return const Color(0xFF6366F1); // Indigo (Planning)
      case 2:
        return const Color(0xFFD946EF); // Magenta (Coding)
      case 3:
        return const Color(0xFFF59E0B); // Amber (Testing)
      case 4:
        return const Color(0xFF10B981); // Emerald (Finalizing)
      default:
        return widget.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || widget.statuses.isEmpty) return const SizedBox.shrink();

    final currentStatus = widget.statuses[_currentIndex];
    final activeColor = _getDotColor(_currentIndex);

    return Center(
      child: Container(
        width: widget.isFullWidth ? double.infinity : 320,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.borderColor,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collapse/Expand Header bar
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _PulseIndicator(color: activeColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.02, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          ),
                        ),
                        child: Text(
                          currentStatus,
                          key: ValueKey<String>(currentStatus),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: widget.textColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Stages Timeline
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 16, top: 8),
                child: Column(
                  children: List.generate(widget.statuses.length, (index) {
                    final status = widget.statuses[index];
                    final isCompleted = index < _currentIndex;
                    final isActive = index == _currentIndex;

                    Widget indicatorWidget;

                    if (isCompleted) {
                      indicatorWidget = const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF10B981),
                      ).animate().scale(duration: 200.ms);
                    } else if (isActive) {
                      final itemColor = _getDotColor(index);
                      indicatorWidget = _PulseIndicator(color: itemColor, size: 10);
                    } else {
                      indicatorWidget = Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                      );
                    }

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left side: Line and Indicator column
                          Column(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                alignment: Alignment.center,
                                child: indicatorWidget,
                              ),
                              if (index < widget.statuses.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 1.5,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: isCompleted
                                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                        : Colors.white10,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Right side: Stage Text description
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                status,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive
                                      ? Colors.white
                                      : (isCompleted ? const Color(0xFFA3A3A3) : Colors.white30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

/// A compact dot that gently breathes and pulses outward (ChatGPT/Gemini hybrid style)
class _PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseIndicator({required this.color, this.size = 8.0});

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator> with SingleTickerProviderStateMixin {
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
          size: Size(widget.size + 10, widget.size + 10),
          painter: _PulsePainter(
            progress: _controller.value,
            color: widget.color,
            baseRadius: widget.size / 2,
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double baseRadius;

  _PulsePainter({required this.progress, required this.color, required this.baseRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Gently breathes and pulses outward
    final coreScale = 1.0 + (math.sin(progress * math.pi * 2) * 0.18);
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, baseRadius * coreScale, corePaint);

    // Dynamic wave glow pulse ring
    final wavePaint = Paint()
      ..color = color.withValues(alpha: 0.35 * (1.0 - progress))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * (1.0 + progress * 1.6), wavePaint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.baseRadius != baseRadius;
  }
}
