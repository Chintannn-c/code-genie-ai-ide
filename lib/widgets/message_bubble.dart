import 'dart:ui';

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
                  _buildMainBubble(context, agentColor),
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
    return ClipRRect(
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
                        ..._buildContent(context, agentColor),
                        if (isStreaming && !isUser)
                          _buildStreamingIndicator(agentColor),
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
        .slideY(begin: 0.02, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildStreamingIndicator(Color agentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(agentColor),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Orchestrating response...",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: agentColor.withValues(alpha: 0.5),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
        ],
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

    if (purified.isEmpty && !message.isImage) {
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
        if (s.isCode) {
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
