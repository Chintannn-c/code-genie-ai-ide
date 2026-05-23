import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/app_file.dart';
import '../providers/chat_provider.dart';

/// Horizontal deck showing uploaded/uploading files with stateful indicators.
class FileUploadBar extends StatelessWidget {
  final List<AppFile> files;
  final Function(String) onRemove;
  final Function(String) onAnalyze;
  final VoidCallback? onAnalyzeProject;
  final VoidCallback? onClearAll;
  final bool isDark;

  const FileUploadBar({
    super.key,
    required this.files,
    required this.onRemove,
    required this.onAnalyze,
    this.onAnalyzeProject,
    this.onClearAll,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    return Container(
      height: 145,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F0F13).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length + (onAnalyzeProject != null ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                if (index == files.length) {
                  return _buildProjectActionCard();
                }
                final file = files[index];
                return _buildResponsiveFileCard(context, file, chatProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFileCard(BuildContext context, AppFile file, ChatProvider cp) {
    switch (file.status) {
      case FileUploadStatus.preparing:
      case FileUploadStatus.encrypting:
        return _buildSkeletonCard(context, file);
      case FileUploadStatus.failed:
        return _buildFailedCard(context, file, cp);
      case FileUploadStatus.paused:
        return _buildPausedCard(context, file, cp);
      case FileUploadStatus.quarantined:
        return _buildQuarantinedCard(context, file);
      case FileUploadStatus.uploading:
      case FileUploadStatus.scanning:
      case FileUploadStatus.validating:
      case FileUploadStatus.parsing:
        return _buildProgressCard(context, file, cp);
      case FileUploadStatus.ready:
        return _buildReadyCard(context, file);
    }
  }

  // OPTIMISTIC SKELETON CARD (Preparing/Encrypting)
  Widget _buildSkeletonCard(BuildContext context, AppFile file) {
    final themeColor = _getColorForLang(file.language);
    final statusText = file.status == FileUploadStatus.preparing ? 'Preparing...' : 'Encrypting...';
    
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.05),
      highlightColor: isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.02),
      child: Container(
        width: 270,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131316) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 70,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: themeColor.withValues(alpha: 0.5),
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

  // FAILED ATTACHMENT CARD
  Widget _buildFailedCard(BuildContext context, AppFile file, ChatProvider cp) {
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: Color(0xFFF87171),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.errorMessage ?? 'Upload failed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF87171),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => cp.retryUpload(file.fileId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFF87171),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(file.fileId),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PAUSED CARD
  Widget _buildPausedCard(BuildContext context, AppFile file, ChatProvider cp) {
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_rounded,
              size: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => cp.resumeUpload(file.fileId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Resume',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onRemove(file.fileId),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PROGRESSIVE UPLOAD PROGRESS CARD (Uploading, Processing, Analyzing)
  Widget _buildProgressCard(BuildContext context, AppFile file, ChatProvider cp) {
    final themeColor = _getColorForLang(file.language);
    String statusLabel = 'Uploading...';
    IconData statusIcon = Icons.cloud_upload_outlined;
    
    if (file.status == FileUploadStatus.validating) {
      statusLabel = 'Validating Binary Header...';
      statusIcon = Icons.verified_user_outlined;
    } else if (file.status == FileUploadStatus.scanning) {
      statusLabel = 'Malware Scanning...';
      statusIcon = Icons.security_rounded;
    } else if (file.status == FileUploadStatus.parsing) {
      statusLabel = 'Context Ingestion Parsing...';
      statusIcon = Icons.analytics_outlined;
    }

    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131316).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                size: 14,
                color: themeColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  if (file.status == FileUploadStatus.uploading) {
                    cp.pauseUpload(file.fileId);
                  } else {
                    onRemove(file.fileId);
                  }
                },
                child: Icon(
                  file.status == FileUploadStatus.uploading
                      ? Icons.pause_circle_outline_rounded
                      : Icons.cancel_outlined,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                '${(file.progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: themeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: file.progress,
              minHeight: 4,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            ),
          ),
          if (file.uploadSpeed.isNotEmpty && file.status == FileUploadStatus.uploading) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  file.uploadSpeed,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                Text(
                  file.timeRemaining,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // READY FOR AI CARD (Success State)
  Widget _buildReadyCard(BuildContext context, AppFile file) {
    final themeColor = _getColorForLang(file.language);
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131316).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Futuristic Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              _getIconForLang(file.language),
              size: 20,
              color: themeColor,
            ),
          ),
          const SizedBox(width: 12),

          // Metadata (Name & Size)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      file.sizeString,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ready',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Divider
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white10 : Colors.black12,
          ),

          const SizedBox(width: 8),

          // Actions Column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Close/Remove Button
              GestureDetector(
                onTap: () => onRemove(file.fileId),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Analyze Button
              GestureDetector(
                onTap: () => onAnalyze(file.fileId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 11,
                        color: Color(0xFF818CF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Analyze',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectActionCard() {
    return InkWell(
      onTap: onAnalyzeProject,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_copy_rounded,
                size: 20,
                color: Color(0xFF818CF8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Analyze Project',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Scan workspace',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white24 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return const Color(0xFF38BDF8);
      case 'dart':
        return const Color(0xFF0EA5E9);
      case 'javascript':
      case 'typescript':
        return const Color(0xFFFBBF24);
      case 'html':
        return const Color(0xFFF97316);
      case 'css':
        return const Color(0xFF818CF8);
      default:
        return const Color(0xFFA78BFA);
    }
  }

  IconData _getIconForLang(String lang) {
    switch (lang.toLowerCase()) {
      case 'python':
        return Icons.terminal_rounded;
      case 'dart':
        return Icons.flutter_dash_rounded;
      case 'javascript':
      case 'typescript':
        return Icons.javascript_rounded;
      case 'html':
        return Icons.html_rounded;
      case 'css':
        return Icons.css_rounded;
      default:
        return Icons.description_outlined;
    }
  }

  Widget _buildQuarantinedCard(BuildContext context, AppFile file) {
    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF450A0A).withValues(alpha: 0.8), // Deep Red
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEF4444),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Animate(
              onPlay: (c) => c.repeat(reverse: true),
              child: const Icon(
                Icons.gpp_bad_rounded,
                size: 20,
                color: Color(0xFFF87171),
              ),
            ).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.15, 1.15),
              duration: const Duration(milliseconds: 1000),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'QUARANTINED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFEF4444),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(
                              'Security Threat Quarantine',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The security gateway isolated this file due to potential hazards.',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                file.errorMessage ?? 'Malware payload detected.',
                                style: GoogleFonts.firaCode(
                                  color: const Color(0xFFF87171),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onRemove(file.fileId);
                            },
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                            child: const Text('Dismiss & Discard'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 10, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text(
                          'View Threat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
