/// App file model for uploaded code files.
class AppFile {
  final String fileId;
  final String fileName;
  final String language;
  final int size;
  final DateTime? createdAt;

  AppFile({
    required this.fileId,
    required this.fileName,
    required this.language,
    required this.size,
    this.createdAt,
  });

  factory AppFile.fromJson(Map<String, dynamic> json) {
    return AppFile(
      fileId: json['file_id'] ?? '',
      fileName: json['file_name'] ?? '',
      language: json['language'] ?? 'text',
      size: json['size'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
