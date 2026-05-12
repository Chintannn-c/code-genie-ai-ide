/*
 * FIXES APPLIED: 2026-05-06
 * Bug #1 — RepaintBoundary + SizeTransition — line ~170
 */

import 'dart:ui';

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

  Map<String, List<dynamic>> _groupChats(List<dynamic> chats) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last7Days = today.subtract(const Duration(days: 7));

    Map<String, List<dynamic>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (var chat in chats) {
      final chatDate = DateTime(chat.updatedAt.year, chat.updatedAt.month, chat.updatedAt.day);
      if (chatDate == today) {
        groups['Today']!.add(chat);
      } else if (chatDate == yesterday) {
        groups['Yesterday']!.add(chat);
      } else if (chatDate.isAfter(last7Days)) {
        groups['Previous 7 Days']!.add(chat);
      } else {
        groups['Older']!.add(chat);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  Widget _buildGroupedChatList(ChatProvider cp, bool isDark) {
    final groups = _groupChats(cp.filteredChats);
    
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: groups.keys.length,
      padding: const EdgeInsets.only(bottom: 12),
      itemBuilder: (context, gIndex) {
        final groupTitle = groups.keys.elementAt(gIndex);
        final groupChats = groups[groupTitle]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                groupTitle.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...groupChats.map((chat) => ChatListTile(
              chat: chat,
              isSelected: cp.currentChatId == chat.chatId,
              isDark: isDark,
              onTap: () => cp.openChat(chat.chatId),
              onDelete: () => _confirmDelete(cp, chat.chatId),
            )),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final ap = context.watch<AuthProvider>();
    final isDark = themeProvider.isDark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? Colors.black : const Color(0xFFFAFBFC),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: isDark ? Colors.black : Colors.white,
              child: _buildSidebar(chatProvider, ap, isDark),
            ),
      floatingActionButton: _showScrollButton
          ? _buildScrollButton(isDark)
          : null,
      floatingActionButtonLocation: isWide 
          ? FloatingActionButtonLocation.endFloat 
          : FloatingActionButtonLocation.centerFloat,
      body: Row(
        children: [
          if (isWide) _buildSidebar(chatProvider, ap, isDark),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 1100 : double.infinity,
                ),
                child: Column(
                  children: [
                    _buildHeader(chatProvider, ap, themeProvider, isDark, isWide),
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
    AuthProvider ap,
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

            if (isWide) ...[
              const SizedBox(width: 16),
              // Chat Title & Model Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        cp.currentChat?.title ?? 'New Conversation',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (cp.currentChat != null) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.edit_note_rounded, size: 16, color: isDark ? Colors.white24 : Colors.black26),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6366F1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const ModelSelector(),
                      const SizedBox(width: 8),
                      Container(width: 3, height: 3, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      if (cp.currentChat == null)
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'System Ready',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF10B981).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Last active: Just now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
            IconButton(
              icon: Icon(Icons.star_outline_rounded, size: 20, color: isDark ? Colors.white24 : Colors.black26),
              onPressed: () {},
              tooltip: 'Favorite',
            ),
            _buildNotificationBadge(context, isDark),
            _buildThemeToggle(tp, isDark),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
              backgroundImage: ap.user?.pictureUrl != null
                  ? NetworkImage(ap.user!.pictureUrl!)
                  : null,
              child: ap.user?.pictureUrl == null
                  ? Icon(Icons.person_rounded, size: 14, color: isDark ? Colors.white70 : Colors.black87)
                  : null,
            ),
            const SizedBox(width: 12),
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
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code Genie',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'PRO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF6366F1),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'VERSION 2.0',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white24 : Colors.black26,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: cp.newChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'New Chat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.03) 
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.06) 
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: cp.setSearchQuery,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: isDark ? Colors.white24 : Colors.black26,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: isDark ? Colors.white24 : Colors.black26,
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
                    : _buildGroupedChatList(cp, isDark),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          
          _buildUserProfileCard(ap, isDark),
          _buildSidebarUtility(context, isDark),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(AuthProvider ap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  backgroundImage: ap.user?.pictureUrl != null
                      ? NetworkImage(ap.user!.pictureUrl!)
                      : null,
                  child: ap.user?.pictureUrl == null
                      ? const Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 18)
                      : null,
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.black : Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        ap.user?.fullName ?? 'Developer',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF6366F1)),
                    ],
                  ),
                  Text(
                    'pro@codegenie.ai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarUtility(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _utilityIcon(Icons.settings_outlined, 'Settings', isDark),
          _utilityIcon(Icons.help_outline_rounded, 'Help', isDark),
          _utilityIcon(Icons.star_outline_rounded, 'Favorites', isDark),
          _utilityIcon(Icons.logout_rounded, 'Sign Out', isDark, color: Colors.redAccent.withValues(alpha: 0.6), onTap: () => _confirmLogout(context)),
        ],
      ),
    );
  }

  Widget _utilityIcon(IconData icon, String tooltip, bool isDark, {Color? color, VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color ?? (isDark ? Colors.white38 : Colors.black38)),
        ),
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
        itemCount: cp.messages.length + (cp.isStreaming ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == cp.messages.length && cp.isStreaming) {
            return const TypingIndicator();
          }
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Pulsating Monolith
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 54),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds, curve: Curves.easeInOut)
             .shimmer(duration: 3.seconds, color: Colors.white24),

            const SizedBox(height: 40),

            // Aurora Gradient Title
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFF6366F1), Color(0xFFA855F7), Colors.white],
                stops: [0.0, 0.4, 0.6, 1.0],
              ).createShader(bounds),
              child: Text(
                'CODE GENIE',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: Colors.white,
                ),
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),

            Text(
              'Your Intelligence, Accelerated.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 64),

            // Premium Action Grid
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildActionCard(
                  title: 'Generate Code',
                  subtitle: 'Turn ideas into logic',
                  icon: Icons.code_rounded,
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('generate'),
                ),
                _buildActionCard(
                  title: 'Debug Errors',
                  subtitle: 'Heal broken scripts',
                  icon: Icons.bug_report_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('debug'),
                ),
                _buildActionCard(
                  title: 'Explain Snippets',
                  subtitle: 'Master complex logic',
                  icon: Icons.psychology_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                  onTap: () => context.read<ChatProvider>().setMode('explain'),
                ),
              ],
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white38 : Colors.black45,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
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

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 20, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.03) 
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (controller) => controller.repeat()).scale(
                  duration: 600.ms,
                  delay: (index * 200).ms,
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.2, 1.2),
                ).fadeIn(
                  duration: 600.ms,
                  delay: (index * 200).ms,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
