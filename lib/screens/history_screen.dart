import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Pagination & Prefetching
  int _currentPage = 1;
  bool _isFetchingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Stale-While-Revalidate: Trigger background silent sync instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChats();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isFetchingMore || !_hasMore) return;
    
    final threshold = _scrollController.position.maxScrollExtent * 0.8;
    if (_scrollController.position.pixels >= threshold) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    setState(() {
      _isFetchingMore = true;
    });

    final cp = context.read<ChatProvider>();
    final ap = context.read<AuthProvider>();
    if (ap.user == null) return;

    try {
      final nextPage = _currentPage + 1;
      // Fetch fresh paginated chats from remote database
      final nextChats = await cp.getChatsFromApi(ap.user!.userId, page: nextPage);
      
      if (nextChats.isEmpty) {
        setState(() {
          _hasMore = false;
        });
      } else {
        setState(() {
          _currentPage = nextPage;
        });
        cp.appendChats(nextChats);
      }
    } catch (e) {
      debugPrint('⚠️ Error prefetching next page: $e');
    } finally {
      setState(() {
        _isFetchingMore = false;
      });
    }
  }

  List<Chat> _filterChats(List<Chat> chats) {
    if (_searchQuery.isEmpty) return chats;
    return chats.where((chat) {
      return chat.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (chat.lastMessageSnippet?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;
    final cp = context.watch<ChatProvider>();
    final filtered = _filterChats(cp.chats);
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF070709)
          : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF070709).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                'Engineering History',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              centerTitle: false,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                // Live synchronization badge
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ).animate(onPlay: (c) => c.repeat()).scale(
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1.3, 1.3),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Synced',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 850 : double.infinity,
            ),
            child: Column(
              children: [
                // Real-time optimistic search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131316)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search files, snippets or summaries...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white24 : Colors.black38,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                // Error Indicator if optimistic rollback triggered
                if (cp.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cp.errorMessage!,
                              style: GoogleFonts.inter(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                            onPressed: cp.clearError,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                Expanded(
                  child: cp.chats.isEmpty && cp.isLoading
                      ? _buildSkeletonList(isDark)
                      : filtered.isEmpty
                          ? _buildEmptyState(isDark)
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length + (_isFetchingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == filtered.length) {
                                  return _buildMiniShimmerLoader(isDark);
                                }

                                final chat = filtered[index];
                                return _buildHistoryCard(chat, cp, isDark);
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Chat chat, ChatProvider cp, bool isDark) {
    // Dynamically assign language color accents for rich visual details
    final snippet = chat.lastMessageSnippet ?? '';
    final hasCode = snippet.contains('```');
    final isDart = snippet.toLowerCase().contains('dart') || chat.title.toLowerCase().contains('dart');
    final isPython = snippet.toLowerCase().contains('def ') || chat.title.toLowerCase().contains('py');
    final accentColor = isDart 
        ? const Color(0xFF00C4B4) 
        : (isPython ? const Color(0xFF007ACC) : const Color(0xFF6366F1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: Key(chat.chatId),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            // Optimistic Delete Trigger! State updates instantly and recovers on rollback
            cp.deleteChat(chat.chatId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deleting "${chat.title}"...'),
                backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.black87,
                action: SnackBarAction(
                  label: 'UNDO',
                  textColor: const Color(0xFF6366F1),
                  onPressed: () {
                    // Quick undo operation
                    cp.loadChats();
                  },
                ),
              ),
            );
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111115) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cp.currentChatId == chat.chatId
                    ? accentColor.withValues(alpha: 0.4)
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Instant navigation switch using pre-hydrated routing
                  cp.openChat(chat.chatId);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.terminal_rounded,
                              size: 16,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chat.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(chat.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 11,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${chat.messageCount}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (snippet.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF08080B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasCode ? 'CODE GENERATION PREVIEW' : 'DISCUSSION SUMMARY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor.withValues(alpha: 0.7),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _cleanCodeSnippet(snippet),
                                style: GoogleFonts.firaCode(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _cleanCodeSnippet(String raw) {
    if (!raw.contains('```')) return raw;
    final index = raw.indexOf('```');
    final next = raw.indexOf('\n', index);
    if (next != -1) {
      return raw.substring(next + 1).replaceAll('```', '').trim();
    }
    return raw.replaceAll('```', '').trim();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildSkeletonCard(isDark);
      },
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111115) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 70,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF08080B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 220,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 140,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1500.ms,
          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
        );
  }

  Widget _buildMiniShimmerLoader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 40,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Conversations Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try typing another search keyword or create a new code generation prompt.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }
}
