/// Chat model representing a conversation session.
class Chat {
  final String chatId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  Chat({
    required this.chatId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chat_id'] ?? '',
      title: json['title'] ?? 'Untitled',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      messageCount: json['message_count'] ?? 0,
    );
  }
}
