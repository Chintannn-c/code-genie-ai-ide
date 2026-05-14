import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/message.dart';
import '../config/api_config.dart';
import '../utils/code_parser.dart';
import 'code_block.dart';

/// Chat message bubble widget that renders text and code blocks.
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(),
          if (!isUser) const SizedBox(width: 12),
          
          // ADDED: Left spacer for User messages to push them to the right and limit their width
          if (isUser) Spacer(flex: isWide ? 4 : 2),

          Flexible(
            flex: isWide ? 6 : 8,
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Role label
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                  child: Text(
                    isUser ? 'YOU' : 'CODE GENIE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                // Message content
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isUser ? 24 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 24),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: isUser ? 0 : 12, sigmaY: isUser ? 0 : 12),
                    child: Container(
                      constraints: BoxConstraints(
                        // Reduced maxWidth to avoid stretching too much
                        maxWidth: MediaQuery.of(context).size.width * (isWide ? 0.6 : 0.75),
                        minWidth: 80, // Ensure bubbles aren't too thin
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                              )
                            : null,
                        color: !isUser
                            ? (message.content.contains('[Error')
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.8)))
                            : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(24),
                          topRight: const Radius.circular(24),
                          bottomLeft: Radius.circular(isUser ? 24 : 6),
                          bottomRight: Radius.circular(isUser ? 6 : 24),
                        ),
                        border: Border.all(
                          color: message.content.contains('[Error')
                              ? Colors.redAccent.withValues(alpha: 0.4)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (isUser)
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          if (!isUser && !isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (message.content.contains('[Error'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'AI ENGINE ERROR',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.redAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._buildContent(context),
                      if (isStreaming && !isUser) _buildCursor(),
                    ],
                  ),
                ),
              ),
            ).animate(
                  target: isStreaming ? 1 : 1, // Always stay at end state for history
                ).fadeIn(
                  duration: isStreaming ? 400.ms : 0.ms,
                ).slideY(
                  begin: isStreaming ? 0.05 : 0, 
                  end: 0, 
                  duration: isStreaming ? 400.ms : 0.ms, 
                  curve: Curves.easeOutCubic
                ),
                // Actions row
                if (!isUser && message.content.isNotEmpty && !isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _actionIcon(Icons.thumb_up_outlined),
                          const SizedBox(width: 8),
                          _actionIcon(Icons.thumb_down_outlined),
                          const SizedBox(width: 8),
                          _actionIcon(Icons.content_copy_rounded, onTap: () {
                             Clipboard.setData(ClipboardData(text: message.content));
                          }),
                          const SizedBox(width: 8),
                          _actionIcon(Icons.open_in_new_rounded),
                          const SizedBox(width: 8),
                          _actionIcon(Icons.refresh_rounded),
                          if (message.modelName != null) ...[
                            const SizedBox(width: 12),
                            _modelBadge(message.modelName!),
                          ],
                        ],
                      ),
                    ),
                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat.jm().format(message.timestamp.toLocal()),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 12,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ADDED: Right spacer for AI messages to push them to the left and limit their width
          if (!isUser) Spacer(flex: isWide ? 4 : 2),

          if (isUser) const SizedBox(width: 12),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 16,
        height: 16,
        fit: BoxFit.contain,
      ),

    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF6366F1)),
    );
  }

  Widget _actionIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 16,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    List<Widget> children = [];

    // Add image if present
    if (message.isImage && message.fileId != null) {
      final imageUrl = "${ApiConfig.baseUrl}${ApiConfig.file(message.fileId!)}";
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 100,
                color: Colors.redAccent.withValues(alpha: 0.1),
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Purify content: remove technical model attribution lines
    String purifiedContent = message.content;
    purifiedContent = purifiedContent.split('\n')
        .where((line) => !line.contains('Model: AI Orchestrator'))
        .join('\n')
        .trim();

    if (purifiedContent.isEmpty && !message.isImage) {
      children.add(
        Text(
          'Thinking...',
          style: GoogleFonts.inter(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
      return children;
    }

    final segments = CodeParser.parse(purifiedContent);

    children.addAll(segments.asMap().entries.map((entry) {
      final index = entry.key;
      final segment = entry.value;
      
      Widget child;
      if (segment.isCode) {
        child = CodeBlock(
          code: segment.content,
          language: segment.language,
          isDark: isDark,
        );
      } else {
        child = Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText(
            segment.content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: isUser
                  ? Colors.white
                  : isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.85),
            ),
          ),
        );
      }

      // Only animate segments if we are currently streaming the message
      if (isStreaming) {
        return child.animate(
          key: ValueKey('${message.messageId}_segment_$index'),
        ).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
      }
      
      return child;
    }).toList());

    return children;
  }

  Widget _buildCursor() {
    if (message.content.isEmpty) {
      // Premium Skeleton Loading
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: isDark ? Colors.white24 : Colors.black26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 150, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(width: 250, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 8),
            Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
          ],
        ),
      );
    }
    
    // Typing cursor
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value > 0.5 ? 1.0 : 0.0,
          child: Container(
            width: 8,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _modelBadge(String modelName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_rounded, size: 12, color: const Color(0xFF6366F1)),
          const SizedBox(width: 4),
          Text(
            modelName.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF6366F1),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
