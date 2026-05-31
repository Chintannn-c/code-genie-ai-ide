import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'code_execution_panel.dart';
import 'critic_card.dart';

/// Syntax-highlighted code block widget with copy and AI Critique functionality.
class CodeBlock extends StatefulWidget {
  final String code;
  final String language;
  final bool isDark;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.isDark = true,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _showCritique = false;

  @override
  Widget build(BuildContext context) {
    final baseTheme = widget.isDark ? atomOneDarkTheme : atomOneLightTheme;
    final bgColor = baseTheme['root']?.backgroundColor ?? 
        (widget.isDark ? const Color(0xFF282C34) : Colors.white);
    
    // Create a modified theme with transparent background for the root
    final theme = Map<String, TextStyle>.from(baseTheme);
    theme['root'] = theme['root']!.copyWith(backgroundColor: Colors.transparent);

    final langDisplay = widget.language.isNotEmpty ? widget.language.toUpperCase() : 'CODE';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with language label and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF121214)
                  : const Color(0xFFEFF1F3),
              border: Border(
                bottom: BorderSide(
                  color: widget.isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Language badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF58A6FF).withValues(alpha: 0.2)
                        : const Color(0xFF0969DA).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    langDisplay,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF0969DA),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AI Critique button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showCritique = !_showCritique;
                        });
                        if (_showCritique) {
                          final chatProvider = context.read<ChatProvider>();
                          if (chatProvider.getCritique(widget.code) == null) {
                            chatProvider.critiqueCode(widget.code, widget.language);
                          }
                        }
                      },
                      icon: const Icon(Icons.rate_review_rounded, size: 20),
                      tooltip: 'AI Critic Review',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      color: _showCritique 
                          ? const Color(0xFFF38BA8) 
                          : (widget.isDark 
                              ? Colors.white.withValues(alpha: 0.6) 
                              : Colors.black.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    // Run button (only for supported languages)
                    if (['python', 'javascript', 'js', 'java'].contains(widget.language.toLowerCase()))
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => CodeExecutionPanel(
                              initialCode: widget.code,
                              language: widget.language,
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        tooltip: 'Run Code',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        color: widget.isDark ? const Color(0xFF3FB950) : const Color(0xFF1F883D),
                      ),
                    const SizedBox(width: 8),
                    // Copy button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Code copied to clipboard!'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.black.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Code content with scrollable horizontal area
          Container(
            width: double.infinity,
            color: bgColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: HighlightView(
                widget.code.trimRight(), // Clean up trailing newlines
                language: _mapLanguage(widget.language),
                theme: theme,
                padding: const EdgeInsets.all(16),
                textStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          // Critique Card section
          if (_showCritique)
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final critique = chatProvider.getCritique(widget.code);
                final isLoading = chatProvider.isCritiquing(widget.code);
                
                if (critique == null && !isLoading) {
                  return const SizedBox.shrink();
                }
                
                return Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                  child: CriticCard(
                    critique: critique ?? {},
                    isLoading: isLoading,
                    onReanalyze: () {
                      chatProvider.critiqueCode(widget.code, widget.language);
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Map common language names to highlight.js identifiers.
  String _mapLanguage(String lang) {
    final map = {
      'c++': 'cpp',
      'c#': 'csharp',
      'shell': 'bash',
      'sh': 'bash',
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'rb': 'ruby',
    };
    return map[lang.toLowerCase()] ?? lang.toLowerCase();
  }
}
