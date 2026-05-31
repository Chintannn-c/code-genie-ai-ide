import 'package:flutter/foundation.dart';
import 'package:ai_coding/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  bool get isLoadingState => !isUser && message.content.trim().isEmpty && !message.isImage;

  @override
  Widget build(BuildContext context) {
    final agentColor = _getAgentColor();
    final isWide = MediaQuery.of(context).size.width > 700;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: isLoadingState
              ? MainAxisAlignment.center
              : (isUser ? MainAxisAlignment.end : MainAxisAlignment.start),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser || isLoadingState) Spacer(flex: isWide ? 1 : 2),

            Flexible(
              flex: isWide ? 12 : 10,
              child: Column(
                crossAxisAlignment: isLoadingState
                    ? CrossAxisAlignment.center
                    : (isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start),
                children: [
                  _buildHeader(agentColor),
                  const SizedBox(height: 8),
                  Align(
                    alignment: isLoadingState
                        ? Alignment.center
                        : (isUser ? Alignment.centerRight : Alignment.centerLeft),
                    child: _buildMainBubble(context, agentColor),
                  ),
                  if (!isUser && !isStreaming)
                    _buildFooter(context, agentColor),
                ],
              ),
            ),

            if (!isUser || isLoadingState) Spacer(flex: isWide ? 1 : 2),
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
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              color: isUser
                  ? (isDark ? const Color(0xFF6B6B6B) : const Color(0xFFA3A3A3))
                  : const Color(0xFF6B6B6B),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.person_outline_rounded,
              size: 12,
              color: const Color(0xFF6B6B6B),
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
        maxWidth: isUser ? 520 : (isWide ? 680 : double.infinity),
      ),
      child: Container(
            decoration: BoxDecoration(
              color: isUser
                  ? (isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5))
                  : Colors.transparent,
              borderRadius: isUser
                  ? BorderRadius.circular(8)
                  : BorderRadius.zero,
              border: isUser
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFFFFFFFF).withValues(alpha: 0.1)
                          : const Color(0x00000000).withValues(alpha: 0.08),
                      width: 1,
                    )
                  : Border(
                      left: BorderSide(
                        color: agentColor,
                        width: 2,
                      ),
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isUser ? 16 : 16,
                isUser ? 12 : 12,
                16,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (message.fileId != null) ...[
                    Consumer<ChatProvider>(
                      builder: (context, cp, _) {
                        final staged = cp.selectedFiles.where((f) => f.fileId == message.fileId);
                        final isImage = message.isImage || 
                            (staged.isNotEmpty && staged.first.language == 'image') ||
                            message.content.toLowerCase().contains('screenshot');
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isImage)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF89DCEB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF89DCEB).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.photo_size_select_actual_rounded,
                                      color: Color(0xFF89DCEB),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Screenshot → UI Code',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF89DCEB),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms),
                            FilePreviewRenderer(
                              fileId: message.fileId!,
                              isDark: isDark,
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._buildContent(context, agentColor),
                ],
              ),
            ),
          )
          .animate(target: 1)
          .fadeIn(duration: 200.ms, curve: Curves.easeOut)
          .slideY(begin: 0.01, end: 0, curve: Curves.easeOut),
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

    if (purified.isEmpty && !message.isImage) {
      return [
        _buildMinimalistThinkingIndicator(agentColor)
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
        } else            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SelectableText(
                s.content,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.7,
                  color: isUser
                      ? (isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A))
                      : (isDark
                            ? const Color(0xFFF5F5F5)
                            : const Color(0xFF0A0A0A)),
                  letterSpacing: 0,
                ),
              ),
            );
        }
      ).toList(),
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
                fontSize: 11,
                color: const Color(0xFF6B6B6B),
              ),
            ),
            const Spacer(),
            _ActionIcon(
              icon: Icons.copy_rounded,
              color: const Color(0xFF6B6B6B),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
              },
            ),
            const SizedBox(width: 12),
            _ActionIcon(
              icon: Icons.auto_fix_high_rounded,
              color: const Color(0xFF6B6B6B),
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
                fontSize: 11,
                color: const Color(0xFF6B6B6B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMinimalistThinkingIndicator(Color agentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.06) : const Color(0x00000000).withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThreePulsingDots(color: const Color(0xFF6B6B6B)),
              const SizedBox(width: 12),
              Text(
                'Thinking...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B6B6B),
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 2,
            width: 140,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                  isDark ? const Color(0xFF8B8BF5) : const Color(0xFF6366F1),
                ),
              ),
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
    // Static dot — no animation, no glow
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
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
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF6B6B6B).withValues(alpha: 0.2)),
      ),
      child: Icon(Icons.hub_rounded, size: 10, color: const Color(0xFF6B6B6B)),
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
      child: Icon(icon, size: 14, color: const Color(0xFF6B6B6B)),
    );
  }
}



class ThreePulsingDots extends StatefulWidget {
  final Color color;
  const ThreePulsingDots({super.key, required this.color});

  @override
  State<ThreePulsingDots> createState() => _ThreePulsingDotsState();
}

class _ThreePulsingDotsState extends State<ThreePulsingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        _controllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _controllers[index],
            curve: Curves.easeInOut,
          ),
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
