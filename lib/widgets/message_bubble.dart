import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:ai_coding/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/message.dart';
import '../utils/code_parser.dart';
import 'code_block.dart';
import 'diagram_renderer.dart';
import 'file_preview_renderer.dart';

/// Chat message bubble with readable code-aware rendering.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isDark;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isDark,
    this.isStreaming = false,
  });

  bool get isUser => message.role == 'user';

  // Model-specific color mapping for cinematic glows
  Color _getAgentColor() {
    if (isUser) return const Color(0xFF6366F1);
    final m = (message.modelName ?? '').toLowerCase();
    if (m.contains('gemini')) return const Color(0xFF4285F4); // Electric Blue
    if (m.contains('qwen')) return const Color(0xFF00F2FF); // Cyber Cyan
    if (m.contains('mistral')) return const Color(0xFFFF4B4B); // Security Red
    if (m.contains('llama') || m.contains('groq'))
      return const Color(0xFF00FF88); // Optimizer Green
    if (m.contains('gpt') || m.contains('oss'))
      return const Color(0xFFFFD700); // Holographic Gold
    return const Color(0xFF6366F1); // Default Neural Purple
  }

  @override
  Widget build(BuildContext context) {
    final agentColor = _getAgentColor();
    final isWide = MediaQuery.of(context).size.width > 700;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser) Spacer(flex: isWide ? 1 : 2),

            Flexible(
              flex: isWide ? 12 : 10,
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _buildHeader(agentColor),
                  const SizedBox(height: 8),
                  Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: _buildMainBubble(context, agentColor),
                  ),
                  if (!isUser && !isStreaming)
                    _buildFooter(context, agentColor),
                ],
              ),
            ),

            if (!isUser) Spacer(flex: isWide ? 1 : 2),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color agentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isUser) ...[
            _PulseIndicator(color: agentColor),
            const SizedBox(width: 8),
          ],
          Text(
            (isUser ? 'You' : (message.modelName ?? 'Code Genie')),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: isUser
                  ? agentColor.withValues(alpha: 0.72)
                  : agentColor.withValues(alpha: 0.78),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.person_outline_rounded,
              size: 12,
              color: agentColor.withValues(alpha: 0.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainBubble(BuildContext context, Color agentColor) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isUser ? 520 : (isWide ? 640 : double.infinity),
      ),
      child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isUser ? 10 : 4),
              topRight: Radius.circular(isUser ? 4 : 10),
              bottomLeft: const Radius.circular(10),
              bottomRight: const Radius.circular(10),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isUser
                      ? agentColor.withValues(alpha: 0.13)
                      : (isDark
                            ? const Color(0xFF111827).withValues(alpha: 0.9)
                            : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isUser ? 10 : 4),
                    topRight: Radius.circular(isUser ? 4 : 10),
                    bottomLeft: const Radius.circular(10),
                    bottomRight: const Radius.circular(10),
                  ),
                  border: Border.all(
                    color: agentColor.withValues(
                      alpha: isStreaming ? 0.35 : 0.12,
                    ),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.fileId != null) ...[
                            FilePreviewRenderer(
                              fileId: message.fileId!,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                          ],
                          ..._buildContent(context, agentColor),
                          if (isStreaming && !isUser)
                            _buildStreamingIndicator(context, agentColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .animate(target: 1)
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.02, end: 0, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildStreamingIndicator(BuildContext context, Color agentColor) {
    final cp = Provider.of<ChatProvider>(context);
    final status = cp.currentContextStatus;
    final String displayText = status ?? "Orchestrating response...";
    final bool isStalled = cp.isStalled;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isStalled
              ? const Color(0xFFF97316).withValues(alpha: 0.1)
              : agentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isStalled
                ? const Color(0xFFF97316).withValues(alpha: 0.3)
                : agentColor.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStalled)
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: Color(0xFFF97316),
              )
            else
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(agentColor),
                ),
              ),
            const SizedBox(width: 10),
            Text(
              isStalled ? "Connection stalled... waiting for host response" : displayText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isStalled
                    ? const Color(0xFFF97316)
                    : agentColor.withValues(alpha: 0.82),
                letterSpacing: 0.2,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1800.ms,
              color: isStalled ? const Color(0xFFFB923C) : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, Color agentColor) {
    List<Widget> children = [];

    // Purify content
    String purified = message.content
        .split('\n')
        .where(
          (line) =>
              !line.contains('Model: AI Orchestrator') &&
              !line.startsWith('[Error:'),
        )
        .join('\n')
        .trim();

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (purified.isEmpty && !message.isImage) {
      if (isStreaming && !isUser && chatProvider.documentReadingStage != null) {
        return [
          _buildDocumentScanningBlock(context, agentColor, chatProvider.documentReadingStage!)
        ];
      }
      return [
        Shimmer.fromColors(
          baseColor: agentColor.withValues(alpha: 0.1),
          highlightColor: agentColor.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 150,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final segments = CodeParser.parse(purified);
    children.addAll(
      segments.map((s) {
        if (s.isDiagram) {
          if (kIsWeb) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CodeBlock(
                code: s.content,
                language: 'mermaid',
                isDark: isDark,
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DiagramRenderer(
              diagramCode: s.content,
              isStreaming: isStreaming,
              agentColor: agentColor,
            ),
          );
        } else if (s.isCode) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CodeBlock(
              code: s.content,
              language: s.language,
              isDark: isDark,
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SelectableText(
              s.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: isUser
                    ? Colors.white
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.85)),
                letterSpacing: 0,
              ),
            ),
          );
        }
      }),
    );

    return children;
  }

  Widget _buildFooter(BuildContext context, Color agentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AgentContributionIcon(agentColor: agentColor),
            const SizedBox(width: 12),
            Text(
              DateFormat.jm().format(message.timestamp.toLocal()),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: agentColor.withValues(alpha: 0.4),
              ),
            ),
            const Spacer(),
            _ActionIcon(
              icon: Icons.copy_rounded,
              color: agentColor,
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
              },
            ),
            const SizedBox(width: 12),
            _ActionIcon(
              icon: Icons.auto_fix_high_rounded,
              color: agentColor,
              onTap: () {
                context.read<ChatProvider>().sendMessage(
                  prompt: "Explain the architecture of your previous response.",
                );
              },
            ),
          ],
          if (isUser)
            Text(
              DateFormat.jm().format(message.timestamp.toLocal()),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: agentColor.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatelessWidget {
  final Color color;
  const _PulseIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          duration: 1000.ms,
          begin: const Offset(1, 1),
          end: const Offset(1.5, 1.5),
          curve: Curves.easeInOut,
        )
        .fadeOut();
  }
}

class _AgentContributionIcon extends StatelessWidget {
  final Color agentColor;
  const _AgentContributionIcon({required this.agentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: agentColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: agentColor.withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.hub_rounded, size: 10, color: agentColor),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Icon(icon, size: 14, color: color.withValues(alpha: 0.4)),
    );
  }
}

extension _MessageBubbleScanningExtension on MessageBubble {
  Widget _buildDocumentScanningBlock(BuildContext context, Color agentColor, String stageText) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8), // Slate 900
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: agentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: agentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DocumentScannerVisual(agentColor: agentColor),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'AI READING DOCUMENT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: agentColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: agentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: agentColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'INDEXING',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: agentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stageText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).animate(key: ValueKey(stageText)).fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0),
                const SizedBox(height: 10),
                // Smooth progressive scanning bar indicator
                Stack(
                  children: [
                    Container(
                      height: 5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 0.65,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              agentColor.withValues(alpha: 0.3),
                              agentColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: agentColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentScannerVisual extends StatefulWidget {
  final Color agentColor;
  const DocumentScannerVisual({super.key, required this.agentColor});

  @override
  State<DocumentScannerVisual> createState() => _DocumentScannerVisualState();
}

class _DocumentScannerVisualState extends State<DocumentScannerVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
        final val = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glowing background concentric rings
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.agentColor.withValues(alpha: 0.15 * (1 - val)),
                  width: 1.5 + (val * 3),
                ),
              ),
            ),
            // Floating scan particle dots
            Positioned(
              top: 12 + (val * 16),
              left: 10 + (val * 8),
              child: Opacity(
                opacity: (1 - val),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.agentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8 + (val * 18),
              right: 12 + (val * 6),
              child: Opacity(
                opacity: val,
                child: Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: widget.agentColor.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Futuristic scanner card body
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(val * 2 * 3.14159), // Elegant spin
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.agentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.agentColor.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.description_rounded,
                    color: widget.agentColor,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Laser scan bar
            Positioned(
              top: 4 + (val * 40),
              child: Container(
                width: 46,
                height: 2,
                decoration: BoxDecoration(
                  color: widget.agentColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.agentColor,
                      blurRadius: 8,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
