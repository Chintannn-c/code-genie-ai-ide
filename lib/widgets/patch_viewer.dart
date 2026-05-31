import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatchViewer extends StatelessWidget {
  final String patch;
  final String? fileName;
  final bool isDark;

  const PatchViewer({
    super.key,
    required this.patch,
    this.fileName,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final lines = patch.split('\n');
    
    // Parse line numbers
    int oldLine = 0;
    int newLine = 0;
    
    List<Map<String, dynamic>> parsedLines = [];
    final headerRegex = RegExp(r'^@@ \-(\d+),?\d* \+(\d+),?\d* @@');

    for (var line in lines) {
      if (line.isEmpty) continue;
      
      String type = 'normal';
      String? oldNum;
      String? newNum;
      String displayContent = line;
      
      final match = headerRegex.firstMatch(line);
      if (match != null) {
        oldLine = int.parse(match.group(1)!);
        newLine = int.parse(match.group(2)!);
        type = 'header';
      } else if (line.startsWith('+') && !line.startsWith('+++')) {
        type = 'addition';
        newNum = (newLine++).toString();
        displayContent = line.substring(1);
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        type = 'deletion';
        oldNum = (oldLine++).toString();
        displayContent = line.substring(1);
      } else if (line.startsWith('@@')) {
        type = 'header';
      } else if (line.startsWith(' ') || line.trim().isEmpty || (!line.startsWith('+') && !line.startsWith('-') && !line.startsWith('@@') && !line.startsWith('index') && !line.startsWith('diff'))) {
        type = 'context';
        oldNum = (oldLine++).toString();
        newNum = (newLine++).toString();
        if (line.startsWith(' ')) {
          displayContent = line.substring(1);
        }
      } else {
        type = 'meta'; // diff, index, ---, +++
      }
      
      parsedLines.add({
        'content': displayContent,
        'raw': line,
        'type': type,
        'oldNum': oldNum ?? '',
        'newNum': newNum ?? '',
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            if (fileName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0891B2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Patching: $fileName',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE6EDF3) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Diff Content
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 64,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: parsedLines.map((pLine) => _buildDiffRow(pLine)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffRow(Map<String, dynamic> pLine) {
    final String content = pLine['content'];
    final String raw = pLine['raw'];
    final String type = pLine['type'];
    final String oldNum = pLine['oldNum'];
    final String newNum = pLine['newNum'];

    Color? rowBgColor;
    Color? codeColor;
    Color gutterBgColor = isDark ? const Color(0xFF161B22) : const Color(0xFFF0F2F5);
    Color gutterTextColor = isDark ? Color(0xFFFFFFFF).withValues(alpha: 0.35) : Colors.black38;

    String symbol = ' ';
    if (type == 'addition') {
      rowBgColor = const Color(0xFF2EA44F).withValues(alpha: isDark ? 0.15 : 0.1);
      codeColor = isDark ? const Color(0xFF56D364) : const Color(0xFF1A7F37);
      gutterBgColor = const Color(0xFF2EA44F).withValues(alpha: isDark ? 0.25 : 0.15);
      gutterTextColor = isDark ? const Color(0xFF56D364) : const Color(0xFF1A7F37);
      symbol = '+';
    } else if (type == 'deletion') {
      rowBgColor = const Color(0xFFF85149).withValues(alpha: isDark ? 0.15 : 0.1);
      codeColor = isDark ? const Color(0xFFF85149) : const Color(0xFFCF222E);
      gutterBgColor = const Color(0xFFF85149).withValues(alpha: isDark ? 0.25 : 0.15);
      gutterTextColor = isDark ? const Color(0xFFF85149) : const Color(0xFFCF222E);
      symbol = '-';
    } else if (type == 'header') {
      rowBgColor = const Color(0xFF388BFD).withValues(alpha: 0.1);
      codeColor = isDark ? const Color(0xFF79C0FF) : const Color(0xFF0969DA);
    } else if (type == 'meta') {
      rowBgColor = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01);
      codeColor = isDark ? Colors.white38 : Colors.black45;
    } else {
      codeColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    }

    return Container(
      color: rowBgColor,
      child: Row(
        children: [
          // Gutter: Old Line Number
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            color: gutterBgColor,
            alignment: Alignment.centerRight,
            child: Text(
              oldNum,
              style: GoogleFonts.firaCode(fontSize: 10, color: gutterTextColor),
            ),
          ),
          // Gutter: New Line Number
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            color: gutterBgColor,
            alignment: Alignment.centerRight,
            child: Text(
              newNum,
              style: GoogleFonts.firaCode(fontSize: 10, color: gutterTextColor),
            ),
          ),
          // Gutter: Symbol Gutter (+, -, etc)
          Container(
            width: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text(
              symbol,
              style: GoogleFonts.firaCode(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: codeColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Code Content
          Text(
            type == 'header' || type == 'meta' ? raw : content,
            style: GoogleFonts.firaCode(
              fontSize: 11,
              height: 1.5,
              color: codeColor,
            ),
          ),
        ],
      ),
    );
  }
}
