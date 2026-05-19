/// Chat model representing a conversation session.
class Chat {
  final String chatId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessageSnippet;

  Chat({
    required this.chatId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessageSnippet,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chat_id'] ?? '',
      title: json['title'] ?? 'Untitled',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      messageCount: json['message_count'] ?? 0,
      lastMessageSnippet: json['last_message_snippet'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'message_count': messageCount,
      'last_message_snippet': lastMessageSnippet,
    };
  }
}
