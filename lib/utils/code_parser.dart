/// Utility to parse markdown content and extract code blocks.
class CodeParser {

  /// Represents a parsed segment of text (either plain text or a code block).
  static List<ContentSegment> parse(String content) {
    if (content.isEmpty) return [];

    final segments = <ContentSegment>[];
    final parts = content.split('```');
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      
      if (i % 2 == 0) {
        // Even index = Text before or between code blocks
        if (part.isNotEmpty) {
          segments.add(ContentSegment.text(part));
        }
      } else {
        // Odd index = Inside a code block
        // First line might be the language
        final lines = part.split('\n');
        String language = '';
        String code = part;
        
        if (lines.isNotEmpty) {
          // If the first part doesn't have a newline, it might just be the language being typed
          final firstLine = lines[0].trim();
          if (firstLine.isNotEmpty && !firstLine.contains(' ')) {
            language = firstLine;
            code = lines.skip(1).join('\n');
          }
        }
        
        // Normalize literal \n if they were sent as text by mistake
        code = code.replaceAll(r'\n', '\n').replaceAll(r'\t', '\t');
        
        segments.add(ContentSegment.code(code.trimRight(), language));
      }
    }

    return segments;
  }
}

/// A segment of parsed message content.
class ContentSegment {
  final bool isCode;
  final bool isDiagram;
  final String content;
  final String language;

  ContentSegment._({
    required this.isCode,
    required this.isDiagram,
    required this.content,
    this.language = '',
  });

  factory ContentSegment.text(String content) =>
      ContentSegment._(isCode: false, isDiagram: false, content: content);

  factory ContentSegment.code(String content, String language) =>
      ContentSegment._(
        isCode: true, 
        isDiagram: language.toLowerCase() == 'mermaid', 
        content: content, 
        language: language
      );
}
