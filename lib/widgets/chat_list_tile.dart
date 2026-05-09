import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat.dart';
import 'package:intl/intl.dart';

/// Tile widget for displaying a chat in the sidebar/history list.
class ChatListTile extends StatelessWidget {
  final Chat chat;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIcon(),
                    size: 16,
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMMd().add_jm().format(chat.updatedAt.toLocal()),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3),
                  ),
                  onPressed: onDelete,
                  splashRadius: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    if (chat.title.startsWith('Generate')) return Icons.auto_fix_high;
    if (chat.title.startsWith('Debug')) return Icons.bug_report;
    if (chat.title.startsWith('Explain')) return Icons.school;
    return Icons.chat_bubble_outline;
  }
}
