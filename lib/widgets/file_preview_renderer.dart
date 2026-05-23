import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/app_file.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Cinematic preview engine for ingested files within chat bubbles.
class FilePreviewRenderer extends StatefulWidget {
  final String fileId;
  final bool isDark;

  const FilePreviewRenderer({
    super.key,
    required this.fileId,
    required this.isDark,
  });

  @override
  State<FilePreviewRenderer> createState() => _FilePreviewRendererState();
}

class _FilePreviewRendererState extends State<FilePreviewRenderer> {
  late Future<AppFile> _metadataFuture;
  Future<String>? _contentFuture;
  Future<List<int>>? _imageBytesFuture;
  bool _hasError = false;
  String _diagnosticLogs = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    setState(() {
      _hasError = false;
      _metadataFuture = _fetchMetadata();
    });
  }

  Future<AppFile> _fetchMetadata() async {
    try {
      final cp = Provider.of<ChatProvider>(context, listen: false);
      // Fast path: check if this file is currently in the active staged files list
      final staged = cp.selectedFiles.where((f) => f.fileId == widget.fileId);
      if (staged.isNotEmpty) {
        return staged.first;
      }

      final api = ApiService();
      final auth = Provider.of<AuthProvider>(context, listen: false);
      api.setToken(auth.user?.token);
      final meta = await api.getFileMetadata(widget.fileId);
      
      // If file metadata fetched successfully and it is ready/safe, load contents
      if (meta.status == FileUploadStatus.ready) {
        _triggerContentLoad(meta);
      }
      return meta;
    } catch (e, stack) {
      _handleCrash(e, stack);
      rethrow;
    }
  }

  void _triggerContentLoad(AppFile meta) {
    final api = ApiService();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    api.setToken(auth.user?.token);

    if (_isImage(meta.language)) {
      _imageBytesFuture = _loadImageBytes(widget.fileId, auth.user?.token);
    } else {
      _contentFuture = api.downloadFileContent(widget.fileId);
    }
  }

  Future<List<int>> _loadImageBytes(String fileId, String? token) async {
    final url = '${ApiConfig.baseUrl}/api/file/$fileId';
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
    };
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Image fetch failed: Code ${response.statusCode}');
    }
  }

  void _handleCrash(dynamic error, StackTrace stack) {
    setState(() {
      _hasError = true;
      _diagnosticLogs = 'Error: $error\n\nStack:\n$stack';
    });
  }

  bool _isImage(String language) {
    final imgTypes = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'image'};
    return imgTypes.contains(language.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildRecoveryUI();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.4)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: FutureBuilder<AppFile>(
          future: _metadataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorCard(snapshot.error.toString());
            }
            if (!snapshot.hasData) {
              return _buildIngestionLoader("Preparing pipeline configurations...");
            }

            final file = snapshot.data!;
            if (file.status != FileUploadStatus.ready) {
              return _buildProgressLifecycle(file);
            }

            // File is safe & ready - Route to isolated viewer
            return _buildViewer(file);
          },
        ),
      ),
    );
  }

  // LIFE-CYCLE LIFESPAN PROGRESS LOADER
  Widget _buildProgressLifecycle(AppFile file) {
    String label = 'Uploading file context...';
    String subLabel = 'Streaming bytes into cloud sandbox';
    double percent = file.progress;

    if (file.status == FileUploadStatus.validating) {
      label = 'Validating structural headers...';
      subLabel = 'Confirming integrity and MIME headers';
    } else if (file.status == FileUploadStatus.scanning) {
      label = 'Threat intelligence scanning...';
      subLabel = 'Analyzing heuristics with Security Gateway';
    } else if (file.status == FileUploadStatus.parsing) {
      label = 'Extracting document hierarchy...';
      subLabel = 'Tokenizing metadata structures for vectors';
    } else if (file.status == FileUploadStatus.quarantined) {
      return _buildQuarantinedThreatCard(file);
    } else if (file.status == FileUploadStatus.failed) {
      return _buildErrorCard(file.errorMessage ?? 'Context ingestion aborted.');
    }

    return _buildIngestionLoader(label, subLabel: subLabel, progress: percent);
  }

  Widget _buildIngestionLoader(String label, {String? subLabel, double progress = 0.3}) {
    final themeColor = const Color(0xFF6366F1);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(themeColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                color: widget.isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.05, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor.withValues(alpha: 0.4), themeColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1800.ms),
            ],
          ),
        ],
      ),
    );
  }

  // SECURITY GATEWAY WARNING OVERLAY
  Widget _buildQuarantinedThreatCard(AppFile file) {
    return Container(
      padding: const EdgeInsets.all(18),
      color: const Color(0xFF450A0A).withValues(alpha: 0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SECURITY GATEWAY BLOCK',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The file "${file.fileName}" was quarantined due to payload threats or prohibited structures.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              file.errorMessage ?? 'Signature hazard detected.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFFF87171),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ERROR CARD
  Widget _buildErrorCard(String errorMsg) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Context Loading Error',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMsg.replaceAll('Exception: ', ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: widget.isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ERROR BOUNDARY FALLBACK CARD
  Widget _buildRecoveryUI() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.broken_image_rounded, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 12),
              Text(
                'Preview Rendering Crashed',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'The preview component crashed due to structural layout failures. Your file was attached successfully to the AI context pipeline.',
            style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Retry Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1E),
                      title: const Text('Renderer Logs', style: TextStyle(color: Colors.white)),
                      content: SingleChildScrollView(
                        child: Text(
                          _diagnosticLogs,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white70),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        )
                      ],
                    ),
                  );
                },
                child: Text('Diagnostics', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ),
            ],
          )
        ],
      ),
    );
  }

  // CENTRAL ROUTING VIEW PREVIEWERS
  Widget _buildViewer(AppFile file) {
    if (_isImage(file.language)) {
      return _buildImageRenderer(file);
    }

    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorCard('Failed to load text contents.');
        }
        if (!snapshot.hasData) {
          return _buildIngestionLoader(
            "Extracting document structure...",
            subLabel: "Reading text buffers from cloud host",
            progress: 0.85,
          );
        }

        final content = snapshot.data!;
        
        // spreadsheet csv check
        if (file.language.toLowerCase() == 'csv') {
          return _buildSpreadsheetRenderer(file, content);
        }
        
        // zip folder structure check
        if (file.language.toLowerCase() == 'zip' || file.fileName.endsWith('.zip')) {
          return _buildRepoTreeRenderer(file, content);
        }

        // pdf mock check
        if (file.language.toLowerCase() == 'pdf' || file.fileName.endsWith('.pdf')) {
          return _buildPDFMockRenderer(file, content);
        }

        // Default Code/Markdown text viewer
        return _buildCodeViewerRenderer(file, content);
      },
    );
  }

  // 1. ISOLATED IMAGE RENDERER
  Widget _buildImageRenderer(AppFile file) {
    return FutureBuilder<List<int>>(
      future: _imageBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorCard("Image decoding failed.");
        if (!snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: widget.isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.05),
            highlightColor: widget.isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.02),
            child: Container(height: 200, color: Colors.white12),
          );
        }

        return MouseRegion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardHeader(file, Icons.image_rounded, const Color(0xFF10B981)),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child:ConstrainedBox(
  constraints: const BoxConstraints(
    maxHeight: 300,
  ),
  child: Image.memory(
    snapshot.data as Uint8List,
    fit: BoxFit.contain,
    alignment: Alignment.center,
    errorBuilder: (context, e, s) => const SizedBox(
      height: 100,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.redAccent,
        ),
      ),
    ),
  ),
)
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. ISOLATED SPREADSHEET RENDERER (CSV)
  Widget _buildSpreadsheetRenderer(AppFile file, String content) {
    try {
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return _buildErrorCard("CSV contains no rows.");

      final headers = lines.first.split(',');
      final rows = lines.skip(1).take(25).map((r) => r.split(',')).toList(); // Render first 25 rows

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardHeader(file, Icons.grid_on_rounded, const Color(0xFF10B981)),
          Container(
            height: 220,
            color: widget.isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 36,
                  dataRowMinHeight: 30,
                  dataRowMaxHeight: 34,
                  headingRowColor: WidgetStateProperty.all(
                    widget.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  ),
                  columns: headers
                      .map((h) => DataColumn(
                            label: Text(
                              h.trim(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: widget.isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ))
                      .toList(),
                  rows: rows
                      .map((r) => DataRow(
                            cells: r
                                .map((c) => DataCell(
                                      Text(
                                        c.trim(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          color: widget.isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
          _buildCardFooter('Displaying first ${rows.length} rows of datatable'),
        ],
      );
    } catch (e, stack) {
      _handleCrash(e, stack);
      return const SizedBox.shrink();
    }
  }

  // 3. ISOLATED PDF MOCK RENDERER
  Widget _buildPDFMockRenderer(AppFile file, String content) {
    try {
      // Split text by page anchors if present, otherwise split into mock paragraphs
      List<String> pages = [];
      if (content.contains('Page ')) {
        final regex = RegExp(r'(?=\[Page\s+\d+\]|Page\s+\d+)');
        pages = content.split(regex).where((p) => p.trim().isNotEmpty).toList();
      }
      
      if (pages.isEmpty) {
        // Fallback: chunk by 1000 characters
        int chunkSize = 1000;
        for (int i = 0; i < content.length; i += chunkSize) {
          int end = (i + chunkSize < content.length) ? i + chunkSize : content.length;
          pages.add(content.substring(i, end));
        }
      }

      return _PaginatedTextShell(
        file: file,
        pages: pages,
        isDark: widget.isDark,
      );
    } catch (e, stack) {
      _handleCrash(e, stack);
      return const SizedBox.shrink();
    }
  }

  // 4. ISOLATED REPOSITORY TREE ZIP RENDERER
  Widget _buildRepoTreeRenderer(AppFile file, String content) {
    try {
      // Parse paths inside a mock zip
      final paths = content.split('\n').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (paths.isEmpty) return _buildErrorCard("Archive is empty.");

      // Build folder trees
      final nodes = <_TreeNode>[];
      for (var path in paths) {
        final parts = path.split('/');
        _insertPathNode(nodes, parts, 0);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardHeader(file, Icons.folder_zip_rounded, const Color(0xFFF59E0B)),
          Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            color: widget.isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white,
            child: ListView.builder(
              itemCount: nodes.length,
              itemBuilder: (context, idx) => _buildTreeNodeWidget(nodes[idx], 0),
            ),
          ),
          _buildCardFooter('Ingested repository workspace map'),
        ],
      );
    } catch (e, stack) {
      _handleCrash(e, stack);
      return const SizedBox.shrink();
    }
  }

  void _insertPathNode(List<_TreeNode> siblingNodes, List<String> parts, int index) {
    if (index >= parts.length) return;
    final name = parts[index];
    final isDir = index < parts.length - 1;

    var existing = siblingNodes.where((n) => n.name == name);
    _TreeNode node;
    if (existing.isNotEmpty) {
      node = existing.first;
    } else {
      node = _TreeNode(name: name, isDir: isDir);
      siblingNodes.add(node);
    }

    if (isDir) {
      _insertPathNode(node.children, parts, index + 1);
    }
  }

  Widget _buildTreeNodeWidget(_TreeNode node, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 14.0, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                node.isDir ? Icons.folder_rounded : Icons.description_outlined,
                size: 14,
                color: node.isDir ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (node.isDir && node.children.isNotEmpty)
            ...node.children.map((c) => _buildTreeNodeWidget(c, depth + 1)),
        ],
      ),
    );
  }

  // 5. ISOLATED TEXT CODE VIEWER RENDERER
  Widget _buildCodeViewerRenderer(AppFile file, String content) {
    final cleanCode = content.length > 5000 
        ? content.substring(0, 5000) + '\n...[Preview truncated for length limits]...'
        : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCardHeader(file, Icons.integration_instructions_outlined, const Color(0xFF6366F1)),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          color: widget.isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white,
          child: SingleChildScrollView(
            child: HighlightView(
              cleanCode,
              language: file.language,
              theme: widget.isDark ? atomOneDarkTheme : atomOneLightTheme,
              padding: const EdgeInsets.all(14),
              textStyle: GoogleFonts.jetBrainsMono(fontSize: 11.5, height: 1.45),
            ),
          ),
        ),
        _buildCardFooter('Document payload context loaded directly'),
      ],
    );
  }

  // PREFAB REUSABLE UI ELEMENTS
  Widget _buildCardHeader(AppFile file, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        border: Border(
          bottom: BorderSide(
            color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            file.sizeString,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: widget.isDark ? Colors.white30 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black12 : Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? Colors.white30 : Colors.black38,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 10, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                'INDEXED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ZIP TREE INNER NODE MODEL
class _TreeNode {
  final String name;
  final bool isDir;
  final List<_TreeNode> children = [];

  _TreeNode({required this.name, required this.isDir});
}

// STATEFUL PAGINATED TEXT READER (For PDF)
class _PaginatedTextShell extends StatefulWidget {
  final AppFile file;
  final List<String> pages;
  final bool isDark;

  const _PaginatedTextShell({
    required this.file,
    required this.pages,
    required this.isDark,
  });

  @override
  State<_PaginatedTextShell> createState() => _PaginatedTextShellState();
}

class _PaginatedTextShellState extends State<_PaginatedTextShell> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final pageText = widget.pages[_currentPage].trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            border: Border(
              bottom: BorderSide(
                color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Text(
                'PAGE ${_currentPage + 1} OF ${widget.pages.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
        ),
        // Content view
        Container(
          height: 200,
          color: widget.isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : Colors.white,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SelectableText(
              pageText,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.5,
                color: widget.isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
        // Pagination footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.black12 : Colors.grey.shade50,
            border: Border(
              top: BorderSide(
                color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _currentPage > 0 
                    ? () => setState(() => _currentPage--) 
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 12),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                color: const Color(0xFF38BDF8),
              ),
              Text(
                'Document Context Pipeline Extracted',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white30 : Colors.black38,
                ),
              ),
              IconButton(
                onPressed: _currentPage < widget.pages.length - 1 
                    ? () => setState(() => _currentPage++) 
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                color: const Color(0xFF38BDF8),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
