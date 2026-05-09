import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_rounded, color: Colors.orange),
            onPressed: () => np.addTestNotification(),
            tooltip: 'Send Test Notification',
          ),
          if (np.unreadCount > 0)
            TextButton(
              onPressed: () => np.markAllAsRead(),
              child: Text(
                'Mark all as read',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: isDark ? Colors.white60 : Colors.black54),
            onPressed: () => _showClearDialog(context, np),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: np.isLoading
          ? const Center(child: CircularProgressIndicator())
          : np.notifications.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: np.notifications.length,
                  itemBuilder: (context, index) {
                    final notification = np.notifications[index];
                    return _NotificationTile(notification: notification);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 80,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notifications yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you receive alerts, they will appear here.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, NotificationProvider np) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently delete all your notification history.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              np.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final np = context.read<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(
          color: Colors.redAccent,
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => np.deleteNotification(notification.id),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) np.markAsRead(notification.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.transparent : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFF6366F1).withValues(alpha: 0.03)),
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat.jm().format(notification.timestamp),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 12, top: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case 'message':
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFF6366F1);
        break;
      case 'like':
        icon = Icons.favorite_rounded;
        color = Colors.pink;
        break;
      case 'system':
      default:
        icon = Icons.info_rounded;
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
