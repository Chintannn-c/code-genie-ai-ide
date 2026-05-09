/// Message model representing a single chat message.
class Message {
  final String messageId;
  final String role; // "user" or "ai"
  final String content;
  final String type; // "generate", "debug", "explain", "image"
  final String language;
  final DateTime timestamp;
  final String? fileId;
  final bool isImage;
  final String? modelName;

  Message({
    required this.messageId,
    required this.role,
    required this.content,
    required this.type,
    required this.language,
    required this.timestamp,
    this.fileId,
    this.isImage = false,
    this.modelName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['message_id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      type: json['type'] ?? 'generate',
      language: json['language'] ?? 'python',
      timestamp: DateTime.parse(json['timestamp']),
      fileId: json['file_id'],
      isImage: json['is_image'] ?? false,
      modelName: json['model_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'role': role,
      'content': content,
      'type': type,
      'language': language,
      'timestamp': timestamp.toIso8601String(),
      'file_id': fileId,
      'is_image': isImage,
      'model_name': modelName,
    };
  }

  /// Create a local user message (before server confirms)
  factory Message.userMessage({
    required String content,
    required String type,
    required String language,
    String? fileId,
    bool isImage = false,
  }) {
    return Message(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
      type: type,
      language: language,
      timestamp: DateTime.now(),
      fileId: fileId,
      isImage: isImage,
    );
  }

  /// Create a streaming AI message (updates as tokens arrive)
  factory Message.aiStreaming({
    required String type,
    required String language,
  }) {
    return Message(
      messageId: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
      role: 'ai',
      content: '',
      type: type,
      language: language,
      timestamp: DateTime.now(),
    );
  }

  /// Create a copy with updated content (for streaming updates)
  Message copyWith({String? content, String? messageId, String? modelName}) {
    return Message(
      messageId: messageId ?? this.messageId,
      role: role,
      content: content ?? this.content,
      type: type,
      language: language,
      timestamp: timestamp,
      fileId: fileId,
      isImage: isImage,
      modelName: modelName ?? this.modelName,
    );
  }
}
