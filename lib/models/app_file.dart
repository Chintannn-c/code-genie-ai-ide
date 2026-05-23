import 'package:file_picker/file_picker.dart' show PlatformFile;

enum FileUploadStatus {
  preparing,
  encrypting,
  uploading,
  scanning,
  validating,
  parsing,
  ready,
  failed,
  paused,
  quarantined
}

/// Upgraded App file model supporting optimistic shims, real-time progress metrics, and retries.
class AppFile {
  final String fileId;
  final String fileName;
  final String language;
  final int size;
  final DateTime? createdAt;
  
  // Progress metrics for advanced UX/UI
  final FileUploadStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final String uploadSpeed;
  final String timeRemaining;
  final PlatformFile? platformFile;

  AppFile({
    required this.fileId,
    required this.fileName,
    required this.language,
    required this.size,
    this.createdAt,
    this.status = FileUploadStatus.ready,
    this.progress = 1.0,
    this.errorMessage,
    this.uploadSpeed = '',
    this.timeRemaining = '',
    this.platformFile,
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
      status: FileUploadStatus.ready,
      progress: 1.0,
    );
  }

  AppFile copyWith({
    String? fileId,
    String? fileName,
    String? language,
    int? size,
    DateTime? createdAt,
    FileUploadStatus? status,
    double? progress,
    String? errorMessage,
    String? uploadSpeed,
    String? timeRemaining,
    PlatformFile? platformFile,
  }) {
    return AppFile(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      language: language ?? this.language,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      platformFile: platformFile ?? this.platformFile,
    );
  }

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
