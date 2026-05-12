/*
 * FIXES APPLIED: 2026-05-06
 * Bug #1 — RepaintBoundary + SizeTransition — line ~170
 */

import 'dart:io';
import 'package:ai_coding/widgets/code_panel.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/orchestration_indicator.dart';
import '../widgets/file_upload_bar.dart';
import '../widgets/model_selector.dart';
import '../widgets/attachment_button.dart';
import '../providers/notification_provider.dart';
import '../providers/planning_provider.dart';
import '../widgets/planning_timeline.dart';
import 'dart:convert';
import '../services/notification_service.dart';
import 'notification_screen.dart';

/// Main chat screen with sidebar and chat area.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// ANIM FIX: Added SingleTickerProviderStateMixin for AnimationController vsync
class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showScrollButton = false;
  bool _isAtBottom = true;
  bool _showRightPanel = true;
  final TextEditingController _searchController = TextEditingController();

  // ANIM FIX: Explicit AnimationController for CodePanel size transition
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // ANIM FIX: Initialize controller for smooth, compositor-only size transitions
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOutCubic,
    );

    // Start panel as expanded
    _panelController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().initialize();
        
        // --- SMART REDIRECT LOGIC ---
        // Listen for notification taps to auto-navigate to the source
        NotificationService().navigationStream.listen((payload) {
          if (payload != null && mounted) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              final String? chatId = data['chatId'] ?? data['id'];
              if (chatId != null) {
                debugPrint('📍 Redirecting to Chat: $chatId');
                context.read<ChatProvider>().openChat(chatId);
                // If drawer is open, close it
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing notification payload for redirect: $e');
            }
          }
        });
      }
    });
  }

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final isBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    if (isBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isBottom;
        if (isBottom) _showScrollButton = false;
      });
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final cp = context.read<ChatProvider>();

      if (force || _isAtBottom) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      } else if (cp.isStreaming && !_isAtBottom) {
        if (!_showScrollButton) {
          setState(() => _showScrollButton = true);
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _panelController.dispose(); 
    _searchController.dispose();
    super.dispose();
  }

  // ANIM FIX: Toggle logic for explicit controller
  void _togglePanel() {
    setState(() {
      _showRightPanel = !_showRightPanel;
      if (_showRightPanel) {
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.black : const Color(0xFFFAFBFC),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: isDark ? Colors.black : Colors.white,
              child: _buildSidebar(chatProvider, authProvider, isDark),
            ),
      floatingActionButton: _showScrollButton
          ? _buildScrollButton(isDark)
          : null,
      floatingActionButtonLocation: isWide 
          ? FloatingActionButtonLocation.endFloat 
          : FloatingActionButtonLocation.centerFloat,
      body: Row(
        children: [
          if (isWide) _buildSidebar(chatProvider, authProvider, isDark),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1100 : double.infinity,
                ),
                child: Column(
                  children: [
                    _buildHeader(chatProvider, themeProvider, isDark, isWide),
                    Expanded(
                      child: Column(
                        children: [
                          const PlanningTimeline(),
                          Expanded(
                            child: chatProvider.messages.isEmpty
                                ? _buildEmptyState(isDark)
                                : _buildMessageList(chatProvider, isDark),
                          ),
                        ],
                      ),
                    ),
                    FileUploadBar(
                      files: chatProvider.selectedFiles,
                      isDark: isDark,
                      onRemove: chatProvider.removeFile,
                      onAnalyze: (id) => chatProvider.analyzeFile(id),
                      onAnalyzeProject: chatProvider.analyzeProject,
                      onClearAll: chatProvider.clearFiles,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OrchestrationIndicator(
                        isActive:
                            chatProvider.isStreaming ||
                            chatProvider.isOrchestrating,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 12,
                        vertical: 12,
                      ),
                      child: ChatInput(
                        mode: chatProvider.selectedMode,
                        isStreaming: chatProvider.isStreaming,
                        isDark: isDark,
                        onStop: chatProvider.stopStreaming,
                        attachmentButton: AttachmentButton(
                          isDark: isDark,
                          isLoading: chatProvider.isUploading,
                          onFilesSelected: chatProvider.uploadFiles,
                        ),
                        onSend: ({required prompt, code = '', error = ''}) {
                          chatProvider.sendMessage(
                            prompt: prompt,
                            code: code,
                            error: error,
                          );
                          _scrollToBottom(force: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ANIM FIX: Replaced AnimatedContainer with SizeTransition + RepaintBoundary
          // Why RepaintBoundary works: It isolates the expensive CodePanel from the main render layer.
          // During the animation, only the boundary needs to be recomposited, not repainted.
          if (isWide)
            SizeTransition(
              sizeFactor: _panelAnimation,
              axis: Axis.horizontal,
              axisAlignment: 1.0,
              child: RepaintBoundary(
                // ANIM FIX: Stops rebuild cascade
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.30,
                  child: CodePanel(
                    code: chatProvider.latestCode,
                    language: chatProvider.latestLanguage,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ChatProvider cp,
    ThemeProvider tp,
    bool isDark,
    bool isWide,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (!isWide) ...[
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child:
                    Icon(
                          Icons.menu_rounded,
                          color: isDark ? Colors.white70 : Colors.black87,
                        )
                        .animate()
                        .shimmer(duration: 2.seconds, color: Colors.white24)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          duration: 200.ms,
                        ),
              ),
              const SizedBox(width: 16),
            ],

            const Spacer(),

            // Editor Mode Toggle
            GestureDetector(
              onTap: cp.toggleEditorMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cp.isEditorMode
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cp.isEditorMode
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cp.isEditorMode
                          ? Icons.auto_awesome_rounded
                          : Icons.code_rounded,
                      size: 14,
                      color: cp.isEditorMode
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EDITOR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: cp.isEditorMode
                            ? const Color(0xFF6366F1)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _togglePanel, // ANIM FIX: Use controller toggle
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _showRightPanel
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _showRightPanel
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 14,
                      color: _showRightPanel
                          ? const Color(0xFF6366F1)
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 6),
                      Text(
                        'TERMINAL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: _showRightPanel
                              ? const Color(0xFF6366F1)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildNotificationBadge(context, isDark),
            const SizedBox(width: 4),
            _buildThemeToggle(tp, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(BuildContext context, bool isDark) {
    final np = context.watch<NotificationProvider>();
    final unreadCount = np.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationScreen()),
          ),
          icon: Icon(
            Icons.notifications_outlined,
            size: 20,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.black : Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThemeToggle(ThemeProvider tp, bool isDark) {
    return IconButton(
      onPressed: tp.toggleTheme,
      icon: Icon(
        isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round_outlined,
        size: 20,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      tooltip: 'Toggle Theme',
    );
  }

  Widget _buildSidebar(ChatProvider cp, AuthProvider ap, bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : Colors.white,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
        ],
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Code Genie',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cp.newChat,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.04) 
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: cp.setSearchQuery,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: GoogleFonts.inter(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8), 
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cp.loadChats(),
              child: cp.filteredChats.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          cp.searchQuery.isEmpty ? 'No chats yet' : 'No results found',
                          style: GoogleFonts.inter(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: cp.filteredChats.length,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemBuilder: (context, index) {
                        final chat = cp.filteredChats[index];
                        return ChatListTile(
                          chat: chat,
                          isSelected: cp.currentChatId == chat.chatId,
                          isDark: isDark,
                          onTap: () => cp.openChat(chat.chatId),
                          onDelete: () => _confirmDelete(cp, chat.chatId),
                        );
                      },
                    ),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              backgroundImage: ap.user?.pictureUrl != null
                  ? NetworkImage(ap.user!.pictureUrl!)
                  : null,
              child: ap.user?.pictureUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    )
                  : null,
            ),
            title: Text(
              ap.user?.fullName ?? 'User',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                size: 20,
                color: Colors.redAccent,
              ),
              onPressed: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider cp, bool isDark) {
    if (cp.isStreaming || (!cp.isLoading && cp.messages.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (cp.currentChatId != null) {
          await cp.loadMessages(cp.currentChatId!);
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: cp.messages.length,
        itemBuilder: (context, index) {
          final msg = cp.messages[index];
          final isLastAI = index == cp.messages.length - 1 && msg.role == 'ai';
          return MessageBubble(
            message: msg,
            isDark: isDark,
            isStreaming: cp.isStreaming && isLastAI,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CODE GENIE',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 48),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildActionCard(
                  title: 'Generate Code',
                  subtitle: 'Create from English',
                  icon: Icons.auto_awesome_rounded,
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('generate'),
                ),
                _buildActionCard(
                  title: 'Debug Errors',
                  subtitle: 'Fix with AI Fix',
                  icon: Icons.bug_report_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('debug'),
                ),
                _buildActionCard(
                  title: 'Explain Snippets',
                  subtitle: 'Understand logic',
                  icon: Icons.psychology_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('explain'),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ChatProvider cp, String chatId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text(
          'This will permanently delete this chat and all messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cp.deleteChat(chatId);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out of Codegenie?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF111111)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollButton(bool isDark) {
    return GestureDetector(
      onTap: () => _scrollToBottom(force: true),
      child:
          Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'New Messages',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .slideY(
                begin: 1.0,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(),
    );
  }
}
