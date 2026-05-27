import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium, ultra-minimal AI response planning and thinking animation widget.
/// Styled for modern dark UIs (background #050816) with extreme visual simplicity.
/// Does not use large glowing boxes or heavy gradients.
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
      'Understanding request...',
      'Planning response...',
      'Thinking...',
      'Generating answer...',
    ],
    this.cycleInterval = const Duration(milliseconds: 3200),
    this.loop = true,
    this.onCompleted,
    this.trailing,
    this.backgroundColor = const Color(0xFF050816),
    this.borderColor = const Color(0x1BFFFFFF), // subtle thin transparent border
    this.accentColor = const Color(0xFF6366F1),  // premium indigo/blue accent
    this.textColor = const Color(0xDEFFFFFF),    // clean off-white
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

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || widget.statuses.isEmpty) return const SizedBox.shrink();

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.borderColor,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main horizontal AI Status Bar body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // Animated breathing pulse dot on the left
                  _PulseDot(color: widget.accentColor),
                  const SizedBox(width: 10),
                  
                  // Text cycle container (constrained height to prevent vertical shifting during transition)
                  SizedBox(
                    height: 18,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutQuad,
                        switchOutCurve: Curves.easeInQuad,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          widget.statuses[_currentIndex],
                          key: ValueKey<String>(widget.statuses[_currentIndex]),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: widget.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tiny staggering typing indicator
                  _TypingIndicator(color: widget.textColor.withValues(alpha: 0.5)),

                  if (widget.trailing != null) ...[
                    const Spacer(),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
            
            // Ultra-thin bottom progress sweep
            _ShimmerProgressLine(accentColor: widget.accentColor),
          ],
        ),
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

/// A compact dot that gently breathes using scale and opacity animations.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Staggered typing indicator with 3 small dots that bounce sequentially.
class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Apply delay based on the dot's index to stagger animation
            final double value = (_controller.value - (index * 0.16)) % 1.0;
            
            // Generate a bouncing effect using a partial sine curve
            double yOffset = 0.0;
            double opacity = 0.45;
            
            if (value < 0.4) {
              final double normalized = value / 0.4;
              yOffset = -2.5 * double.parse(Theme.of(context).platform == TargetPlatform.iOS ? '1.0' : '1.0') * (normalized < 0.5 ? normalized * 2 : (1 - normalized) * 2);
              // Simple quadratic approximation of a sine wave for high performance
              final double wave = 4 * normalized * (1 - normalized); 
              yOffset = -2.5 * wave;
              opacity = 0.45 + (0.55 * wave);
            }
            
            return Transform.translate(
              offset: Offset(0, yOffset),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 3.2,
                  height: 3.2,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// A very thin horizontal line at the bottom that sweeps a solid color bar from left to right.
class _ShimmerProgressLine extends StatefulWidget {
  final Color accentColor;
  const _ShimmerProgressLine({required this.accentColor});

  @override
  State<_ShimmerProgressLine> createState() => _ShimmerProgressLineState();
}

class _ShimmerProgressLineState extends State<_ShimmerProgressLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.5,
      width: double.infinity,
      color: Colors.white.withValues(alpha: 0.04), // faint background track
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double value = _controller.value;
              final double barWidth = totalWidth * 0.22; // 22% of total width
              // Calculate left offset to sweep bar off-screen on left to off-screen on right
              final double leftOffset = (totalWidth + barWidth) * value - barWidth;

              return Stack(
                children: [
                  Positioned(
                    left: leftOffset,
                    width: barWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      color: widget.accentColor.withValues(alpha: 0.35), // subtle flat translucent color sweep
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
