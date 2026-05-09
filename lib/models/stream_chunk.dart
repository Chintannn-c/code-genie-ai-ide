import 'dart:convert';

/// Represents a single chunk from the SSE stream.
class StreamChunk {
  final String text;
  final bool done;
  final String? chatId;
  final String? messageId;
  final String? error;
  final String? modelName;

  StreamChunk({
    required this.text,
    required this.done,
    this.chatId,
    this.messageId,
    this.error,
    this.modelName,
  });

  factory StreamChunk.fromJson(Map<String, dynamic> json) {
    return StreamChunk(
      text: json['text'] ?? json['token'] ?? '', // Support both for safety
      done: json['done'] ?? false,
      chatId: json['chat_id'],
      messageId: json['message_id'],
      error: json['error'],
      modelName: json['model_name'],
    );
  }

  factory StreamChunk.fromSSEData(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return StreamChunk.fromJson(json);
    } catch (e) {
      // Fallback for raw text
      return StreamChunk(text: data, done: false);
    }
  }

  factory StreamChunk.error(String message) {
    return StreamChunk(text: '', done: true, error: message);
  }
}
