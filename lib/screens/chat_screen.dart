import 'dart:ui';
import 'package:ai_coding/widgets/code_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'history_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/chat_list_tile.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/file_upload_bar.dart';
import '../widgets/attachment_button.dart';
import '../widgets/ai_thinking_indicator.dart';

import '../widgets/planning_timeline.dart';
import '../providers/planning_provider.dart';
import '../providers/orchestration_provider.dart';
import 'dart:convert';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'orchestration_dashboard.dart';

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
  bool _showRightPanel = false;
  bool _isSidebarOpen = true; // Added: Collapsible sidebar state
  final TextEditingController _searchController = TextEditingController();

  // ANIM FIX: Explicit AnimationController for CodePanel size transition
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  // Added: Explicit AnimationController for Sidebar size transition
  late AnimationController _sidebarController;
  late Animation<double> _sidebarAnimation;

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

    // Start panel as collapsed (Web-First / Terminal Suppressed)
    _panelController.value = 0.0;

    // Added: Initialize controller for smooth, compositor-only sidebar size transitions
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOutCubic,
    );

    // Start sidebar as fully expanded
    _sidebarController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cp = context.read<ChatProvider>();
        final ap = context.read<AuthProvider>();
        cp.initialize();
        
        // ADDED: Error Listener to show feedback to user and automatically clear stale/expired sessions
        cp.addListener(() {
          if (cp.errorMessage != null && mounted) {
            final error = cp.errorMessage!;
            
            // Auto-heal on stale session / expired credentials
            if (error.contains('Could not validate credentials') || error.contains('401')) {
              debugPrint('⚠️ [Session Interceptor] Expired credentials detected. Auto-recovering session...');
              ap.signOut(); // Triggers session cleanup and redirects user to LoginScreen
              cp.clearError();
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () => cp.clearError(),
                ),
              ),
            );
            // We don't clear it here automatically because the SnackBarAction does it,
            // or it might be cleared by other logic. But let's clear it to avoid repeat snacks.
            cp.clearError();
          }
        });

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
              debugPrint(
                '⚠️ Error parsing notification payload for redirect: $e',
              );
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
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
    _sidebarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  // ANIM FIX: Toggle logic for explicit controller
  void _togglePanel() {
    final cp = context.read<ChatProvider>();
    setState(() {
      _showRightPanel = !_showRightPanel;
      if (_showRightPanel) {
        // Suppress Web view if Terminal is opened
        cp.setWebMode(false);
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    });
  }

  void _toggleWeb() {
    final cp = context.read<ChatProvider>();
    cp.toggleWebMode();

    setState(() {
      _showRightPanel = cp.isWebMode;
      if (cp.isWebMode) {
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
      final chatDate = DateTime(
        chat.updatedAt.year,
        chat.updatedAt.month,
        chat.updatedAt.day,
      );
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
            ...groupChats.map(
              (chat) => ChatListTile(
                chat: chat,
                isSelected: cp.currentChatId == chat.chatId,
                isDark: isDark,
                onTap: () => cp.openChat(chat.chatId),
                onDelete: () => _confirmDelete(cp, chat.chatId),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(ChatProvider cp, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E22)
            : Colors.white,
        title: Text(
          'Delete Chat',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              cp.deleteChat(chatId);
              Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final chatProvider = context
        .read<ChatProvider>(); // OPTIMIZATION: Read, don't watch
    final ap = context.read<AuthProvider>(); // OPTIMIZATION: Read, don't watch
    final isDark = themeProvider.isDark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark
          ? themeProvider.darkTheme.scaffoldBackgroundColor
          : themeProvider.lightTheme.scaffoldBackgroundColor,
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
              child: Consumer<ChatProvider>(
                builder: (context, cp, _) => _buildSidebar(cp, ap, isDark),
              ),
            ),
      floatingActionButton: _showScrollButton
          ? _buildScrollButton(isDark)
          : null,
      floatingActionButtonLocation: isWide
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          Row(
            children: [
              if (isWide)
                SizeTransition(
                  sizeFactor: _sidebarAnimation,
                  axis: Axis.horizontal,
                  axisAlignment: -1.0,
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: 280,
                      child: Consumer<ChatProvider>(
                        builder: (context, cp, _) => _buildSidebar(cp, ap, isDark),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 1100 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        Consumer<ChatProvider>(
                          builder: (context, cp, _) =>
                              _buildHeader(cp, ap, isDark, isWide),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const PlanningTimeline(),
                              Expanded(
                                child: Selector<ChatProvider, String>(
                                  selector: (_, cp) =>
                                      '${cp.messages.length}_${cp.isLoading}_${cp.isStreaming && cp.messages.isNotEmpty ? cp.messages.last.content.length : 0}',
                                  builder: (context, _, __) {
                                    if (chatProvider.isLoading) {
                                      return _buildSkeletonLoader(isDark);
                                    }
                                    return chatProvider.messages.isEmpty
                                        ? _buildEmptyState(isDark)
                                        : _buildMessageList(chatProvider, isDark);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Selector<ChatProvider, String>(
                          selector: (_, cp) =>
                              '${cp.selectedFiles.length}_${cp.isUploading}',
                          builder: (context, _, __) => FileUploadBar(
                            files: chatProvider.selectedFiles,
                            isDark: isDark,
                            onRemove: chatProvider.removeFile,
                            onAnalyze: (id) => chatProvider.analyzeFile(id),
                            onAnalyzeProject: chatProvider.analyzeProject,
                            onClearAll: chatProvider.clearFiles,
                          ),
                        ),
                        Selector<ChatProvider, String>(
                          selector: (_, cp) =>
                              '${cp.isOrchestrating}_${cp.currentContextStatus}_${cp.isStreaming}',
                          builder: (context, _, __) {
                            final showThinking = chatProvider.isOrchestrating ||
                                chatProvider.currentContextStatus != null ||
                                (chatProvider.isStreaming &&
                                    chatProvider.messages.isNotEmpty &&
                                    chatProvider.messages.last.content.isEmpty);

                            if (!showThinking) return const SizedBox.shrink();

                            List<String> statuses = [
                              'Understanding request...',
                              'Planning response...',
                              'Thinking...',
                              'Generating answer...',
                            ];

                            if (chatProvider.currentContextStatus != null &&
                                chatProvider.currentContextStatus!.isNotEmpty) {
                              statuses = [chatProvider.currentContextStatus!];
                            } else if (chatProvider.isOrchestrating) {
                              statuses = [
                                'Deep solve: coordinating expert agents...',
                                'Planning expert reasoning mesh...',
                                'Consulting planner and auditor...',
                              ];
                            }

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isWide ? 40 : 12,
                                vertical: 4,
                              ),
                              child: AiThinkingIndicator(
                                isActive: true,
                                statuses: statuses,
                                loop: chatProvider.currentContextStatus == null,
                                cycleInterval: const Duration(milliseconds: 2500),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isWide ? 40 : 12,
                            vertical: 12,
                          ),
                          child: Selector<ChatProvider, String>(
                            selector: (_, cp) => cp.selectedMode,
                            builder: (context, mode, _) => ChatInput(
                              mode: mode,
                              isStreaming: chatProvider.isStreaming,
                              onToggleTerminal: _togglePanel,
                              onToggleWeb: _toggleWeb,
                              isTerminalOpen: _showRightPanel,
                              isWebOpen: chatProvider.isWebMode,
                              isDark: isDark,
                              onStop: chatProvider.stopStreaming,
                              attachmentButton: Selector<ChatProvider, int>(
                                selector: (_, cp) => cp.selectedFiles.length,
                                builder: (context, fileCount, _) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AttachmentButton(
                                      isDark: isDark,
                                      isLoading: chatProvider.isUploading,
                                      onFilesSelected: chatProvider.uploadFiles,
                                    ),
                                    if (fileCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6366F1),
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 14,
                                            minHeight: 14,
                                          ),
                                          child: Text(
                                            fileCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              onSend: ({required prompt, code = '', error = ''}) {
                                if (chatProvider.isMissionMode) {
                                  final auth = context.read<AuthProvider>();
                                  final pp = context.read<PlanningProvider>();
                                  pp.generatePlan(
                                    prompt,
                                    auth.user?.userId ?? 'anonymous',
                                    auth.user?.token,
                                    chatId: chatProvider.currentChatId,
                                  );
                                } else {
                                  final sp = context.read<SettingsProvider>();
                                  final keys = {
                                    if (sp.geminiApiKey.isNotEmpty)
                                      'gemini': sp.geminiApiKey,
                                    if (sp.groqApiKey.isNotEmpty)
                                      'groq': sp.groqApiKey,
                                    if (sp.openrouterApiKey.isNotEmpty)
                                      'openrouter': sp.openrouterApiKey,
                                    if (sp.githubApiKey.isNotEmpty)
                                      'github': sp.githubApiKey,
                                    if (sp.mistralApiKey.isNotEmpty)
                                      'mistral': sp.mistralApiKey,
                                  };

                                  chatProvider.sendMessage(
                                    prompt: prompt,
                                    code: code,
                                    error: error,
                                    temperature: sp.temperature,
                                    maxTokens: sp.maxTokens.toInt(),
                                    customApiKeys: keys.isNotEmpty ? keys : null,
                                  );
                                }
                                _scrollToBottom(force: true);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ANIM FIX: Replaced AnimatedContainer with SizeTransition + RepaintBoundary
              if (isWide)
                SizeTransition(
                  sizeFactor: _panelAnimation,
                  axis: Axis.horizontal,
                  axisAlignment: 1.0,
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.30,
                      child: Selector<ChatProvider, String>(
                        selector: (_, cp) => cp.latestCode,
                        builder: (context, code, _) => RightCockpitPanel(
                          code: code,
                          language: chatProvider.latestLanguage,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Consumer<ChatProvider>(
            builder: (context, cp, _) {
              if (!cp.isSessionExpired) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Center(
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFF59E0B),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Session Expired',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your session has ended due to inactivity or security reasons.\n\nPlease log in again to continue.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                height: 1.45,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: const LinearProgressIndicator(
                                  minHeight: 3,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                                ).animate().shimmer(duration: 1500.ms),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 180.ms).scale(
                      begin: const Offset(0.96, 0.96),
                      end: const Offset(1, 1),
                      duration: 180.ms,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ChatProvider cp,
    AuthProvider ap,
    bool isDark,
    bool isWide,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 20 : 12, 10, isWide ? 20 : 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF141414)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.06)
                : const Color(0x00000000).withValues(alpha: 0.04),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (!isWide) ...[
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: Icon(
                      Icons.menu_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    tooltip: 'Menu',
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  IconButton(
                    onPressed: _toggleSidebar,
                    icon: Icon(
                      _isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    tooltip: _isSidebarOpen ? 'Collapse Sidebar' : 'Expand Sidebar',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(child: _buildConversationTitle(cp, isDark)),
                _buildActivityPill(cp, isDark),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(
                    0xFF6366F1,
                  ).withValues(alpha: 0.1),
                  backgroundImage: ap.user?.pictureUrl != null
                      ? NetworkImage(ap.user!.pictureUrl!)
                      : null,
                  child: ap.user?.pictureUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                        )
                      : null,
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildConversationTitle(ChatProvider cp, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cp.currentChat?.title ?? 'New Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          cp.currentChat == null
              ? 'Ready for a new task'
              : '${cp.messages.length} messages',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityPill(ChatProvider cp, bool isDark) {
    final active = cp.isStreaming || cp.isOrchestrating;
    final statusText = active 
        ? (cp.isOrchestrating ? 'Agent Active' : 'Streaming') 
        : 'System Sync';

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF6366F1).withOpacity(0.12)
            : const Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? const Color(0xFF6366F1).withOpacity(0.3)
              : const Color(0xFF10B981).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing heartbeat node
          _LiveHeartbeat(isActive: active),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: active ? const Color(0xFF818CF8) : const Color(0xFF10B981),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Latency: 24ms | Synced',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: isDark ? Colors.white30 : Colors.black38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSidebar(ChatProvider cp, AuthProvider ap, bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.06)
                : const Color(0x00000000).withValues(alpha: 0.04),
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Code Genie',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
                    letterSpacing: -0.01 * 17,
                  ),
                ),
              ],
            ),
          ),

          // New Chat Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              onPressed: cp.newChat,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'New Chat',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          cp.searchQuery.isEmpty
                              ? 'No chats yet'
                              : 'No results found',
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

          if (cp.selectedFiles.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROJECT FILES (${cp.selectedFiles.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: cp.clearFiles,
                    child: Text(
                      'CLEAR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                itemCount: cp.selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = cp.selectedFiles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 14,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 12),
                          onPressed: () => cp.removeFile(file.fileId),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),

          _buildUserProfile(ap, isDark),
          _buildSidebarUtility(context, isDark),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildUserProfile(AuthProvider ap, bool isDark) {
    final user = ap.user;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                backgroundImage: user.pictureUrl != null
                    ? NetworkImage(user.pictureUrl!)
                    : null,
                child: user.pictureUrl == null
                    ? Text(
                        user.fullName?[0] ?? 'C',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.fullName ?? 'Chintan Sharma',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
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
          _utilityIcon(
            Icons.settings_outlined,
            'Settings',
            isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _utilityIcon(
            Icons.dashboard_rounded,
            'Cockpit',
            isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrchestrationDashboard(),
                ),
              );
            },
          ),
          _utilityIcon(Icons.help_outline_rounded, 'Help', isDark),
          _utilityIcon(
            Icons.history_rounded,
            'History',
            isDark,
            onTap: () {
              // Optimistic instant navigation with high-performance pre-mounted route transitions
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const HistoryScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.fastEaseInToSlowEaseOut,
                        ),
                      ),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
          _utilityIcon(
            Icons.logout_rounded,
            'Sign Out',
            isDark,
            color: Colors.redAccent.withValues(alpha: 0.6),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _utilityIcon(
    IconData icon,
    String tooltip,
    bool isDark, {
    Color? color,
    VoidCallback? onTap,
  }) {
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
          child: Icon(
            icon,
            size: 20,
            color: color ?? (isDark ? Colors.white38 : Colors.black38),
          ),
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
        itemCount:
            cp.messages.length +
            ((cp.isStreaming || cp.isOrchestrating) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == cp.messages.length) {
            // Only show dots if we don't have a streaming AI message bubble already
            final hasStreamingBubble =
                cp.messages.isNotEmpty &&
                cp.messages.last.role == 'ai' &&
                cp.messages.last.content.isEmpty;

            if (hasStreamingBubble && cp.isStreaming) {
              return const SizedBox.shrink();
            }
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

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        final isUser = index % 2 == 0;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              width: isUser ? 180 : 320,
              height: isUser ? 60 : 110,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isUser ? 100 : 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: isUser ? 140 : 260,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    if (!isUser) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 200,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .fade(
              duration: const Duration(milliseconds: 1500),
              begin: 0.3,
              end: 0.6,
              curve: Curves.easeInOut,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFFA3A3A3),
              size: 28,
            ),
            const SizedBox(height: 22),
            Text(
              'Start a coding session',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a mode, attach files if needed, then ask for code, debugging, or explanation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252),
              ),
            ),
          ],
        ),
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
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E21),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
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
                        color: Color(0xFF6B6B6B),
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .fade(
                      duration: 900.ms,
                      delay: (index * 150).ms,
                      begin: 0.3,
                      end: 1.0,
                      curve: Curves.easeInOut,
                    );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DYNAMIC TABBED RIGHT PANEL (Cockpit panel: Code + Telemetry)
// ============================================================

class RightCockpitPanel extends StatefulWidget {
  final String code;
  final String language;
  final bool isDark;

  const RightCockpitPanel({
    super.key,
    required this.code,
    required this.language,
    required this.isDark,
  });

  @override
  State<RightCockpitPanel> createState() => _RightCockpitPanelState();
}

class _RightCockpitPanelState extends State<RightCockpitPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0D0F16) : Colors.white,
        border: Border(
          left: BorderSide(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: const Color(0xFF818CF8),
                unselectedLabelColor: widget.isDark ? Colors.white30 : Colors.black38,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
                tabs: const [
                  Tab(text: 'CODE PLAYGROUND', icon: Icon(Icons.code_rounded, size: 14)),
                  Tab(text: 'ORCHESTRATION TELEMETRY', icon: Icon(Icons.hub_rounded, size: 14)),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: original Code Panel
                CodePanel(
                  code: widget.code,
                  language: widget.language,
                  isDark: widget.isDark,
                ),
                
                // Tab 2: Live Orchestration Dashboard / Telemetry HUD
                _OrchestrationTelemetryTab(isDark: widget.isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LIVE ORCHESTRATION TELEMETRY PANEL
// ============================================================

class _OrchestrationTelemetryTab extends StatelessWidget {
  final bool isDark;
  const _OrchestrationTelemetryTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<OrchestrationProvider>(
          create: (_) => OrchestrationProvider()..startPolling(),
        ),
      ],
      child: Consumer<OrchestrationProvider>(
        builder: (context, orch, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat Cards Grid
                _buildHUDCard(
                  title: 'ORCHESTRATION NETWORK',
                  color: const Color(0xFF6366F1),
                  child: Row(
                    children: [
                      _buildHUDMetric('Orchestrations', '${orch.totalOrchestrations}', const Color(0xFF6366F1)),
                      _buildHUDMetric('Agent Calls', '${orch.totalAgentCalls}', const Color(0xFF06B6D4)),
                      _buildHUDMetric('Blocked Scans', '${orch.blocked}', const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Active multi-agent mesh networks
                _buildHUDCard(
                  title: 'ACTIVE COGNITIVE AGENTS',
                  color: const Color(0xFF06B6D4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildAgentNode('🗺️ Planner', const Color(0xFF6366F1)),
                      _buildAgentNode('🏗️ Architect', const Color(0xFF8B5CF6)),
                      _buildAgentNode('💻 Coder', const Color(0xFF06B6D4)),
                      _buildAgentNode('🔒 Auditor', const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Ingestion & Vector SOC
                _buildHUDCard(
                  title: 'ZERO-TRUST SECURITY SOC',
                  color: const Color(0xFF10B981),
                  child: Column(
                    children: [
                      _socRow('Clean Files Ingested', '${orch.clean}', const Color(0xFF10B981)),
                      _socRow('Threat Blocked', '${orch.blocked}', const Color(0xFFEF4444)),
                      _socRow('Leaked Key Detections', '${orch.flagged}', const Color(0xFFF59E0B)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: orch.totalScanned > 0 ? (orch.clean / orch.totalScanned).clamp(0.0, 1.0) : 1.0,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Pending approvals human-in-the-loop
                if (orch.approvals.isNotEmpty) ...[
                  _buildHUDCard(
                    title: 'PENDING APPROVAL GATEWAYS',
                    color: const Color(0xFFEF4444),
                    child: Column(
                      children: orch.approvals.map((a) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.security_rounded, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${a['agent']} → ${a['action']}',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  orch.resolveApproval(a['request_id'], true);
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  orch.resolveApproval(a['request_id'], false);
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // AI debate logs / recent events
                _buildHUDCard(
                  title: 'COGNITIVE LOG DEBATE ENGINE',
                  color: const Color(0xFFF59E0B),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: ListView.builder(
                      itemCount: (orch.auditData['recent_events'] as List?)?.length ?? 0,
                      itemBuilder: (context, index) {
                        final events = (orch.auditData['recent_events'] as List);
                        final e = events[events.length - 1 - index];
                        final type = e['event_type'] ?? 'THINK';
                        final agent = e['agent_name'] ?? 'Planner';
                        final action = e['action'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text(type, style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8))),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$agent → $action',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHUDCard({required String title, required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131520).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildHUDMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildAgentNode(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        name,
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    ).animate().fadeIn(duration: 200.ms, curve: Curves.easeOut);
  }

  Widget _socRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white60)),
          const Spacer(),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ============================================================
// REAL-TIME HEARTBEAT PULSER — now a static dot
// ============================================================

class _LiveHeartbeat extends StatelessWidget {
  final bool isActive;
  const _LiveHeartbeat({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF8B8BF5) : const Color(0xFF4ADE80);
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
