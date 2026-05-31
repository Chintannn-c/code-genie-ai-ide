import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class WorkspaceSearchPanel extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String code) onInsert;

  const WorkspaceSearchPanel({
    super.key,
    required this.onClose,
    required this.onInsert,
  });

  @override
  State<WorkspaceSearchPanel> createState() => _WorkspaceSearchPanelState();
}

class _WorkspaceSearchPanelState extends State<WorkspaceSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 650,
          height: 500,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF89DCEB).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        const Icon(
                          Icons.travel_explore_rounded,
                          color: Color(0xFF89DCEB),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Semantic Workspace Search',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFA6ADC8)),
                          onPressed: widget.onClose,
                          hoverColor: Colors.white.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF11111B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF89DCEB).withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: GoogleFonts.firaCode(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask about codebase or search semantic references...',
                          hintStyle: GoogleFonts.outfit(
                            color: const Color(0xFFA6ADC8).withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF89DCEB),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white),
                                  onPressed: () {
                                    _searchController.clear();
                                    chatProvider.clearWorkspaceSearchResults();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                          chatProvider.searchWorkspace(val);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search Results List
                    Expanded(
                      child: chatProvider.isSearchingWorkspace
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF89DCEB),
                                ),
                              ),
                            )
                          : chatProvider.workspaceSearchResults.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchController.text.isEmpty
                                            ? Icons.search_rounded
                                            : Icons.sentiment_dissatisfied_rounded,
                                        size: 48,
                                        color: const Color(0xFFA6ADC8).withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchController.text.isEmpty
                                            ? 'Type query to search files semantically...'
                                            : 'No matching code snippets found',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFA6ADC8).withValues(alpha: 0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: chatProvider.workspaceSearchResults.length,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final item = chatProvider.workspaceSearchResults[index];
                                    final path = item['path'] ?? 'Unknown File';
                                    final content = item['content'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF181825).withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF89DCEB).withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: ExpansionTile(
                                          iconColor: const Color(0xFF89DCEB),
                                          collapsedIconColor: const Color(0xFFA6ADC8),
                                          leading: const Icon(
                                            Icons.description_rounded,
                                            color: Color(0xFF89DCEB),
                                          ),
                                          title: Text(
                                            path.split(RegExp(r'[\\/]')).last,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 15,
                                            ),
                                          ),
                                          subtitle: Text(
                                            path,
                                            style: GoogleFonts.firaCode(
                                              color: const Color(0xFFA6ADC8).withValues(alpha: 0.6),
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF11111B),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: Colors.white.withValues(alpha: 0.05),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      content,
                                                      style: GoogleFonts.firaCode(
                                                        color: const Color(0xFFCDD6F4),
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 10,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      TextButton.icon(
                                                        icon: const Icon(Icons.copy_rounded, size: 16),
                                                        label: const Text('Copy Snippet'),
                                                        onPressed: () {
                                                          Clipboard.setData(ClipboardData(text: content));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Copied snippet to clipboard'),
                                                              duration: Duration(seconds: 2),
                                                            ),
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: const Color(0xFFA6ADC8),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      ElevatedButton.icon(
                                                        icon: const Icon(Icons.input_rounded, size: 16),
                                                        label: const Text('Insert as Context'),
                                                        onPressed: () {
                                                          widget.onInsert(content);
                                                          widget.onClose();
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF89DCEB),
                                                          foregroundColor: const Color(0xFF11111B),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
