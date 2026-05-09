import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 0)
class NotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String body;

  @HiveField(3)
  final String type; // 'message', 'like', 'system'

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  bool isRead;

  @HiveField(6)
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'New Notification',
      body: json['body'] ?? '',
      type: json['type'] ?? 'system',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'data': data,
    };
  }
}
