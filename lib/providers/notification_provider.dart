import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Listen to the live stream from the service
    _service.notificationStream.listen((notification) {
      // Check if it already exists to avoid duplicates
      final exists = _notifications.any((n) => n.id == notification.id);
      if (!exists) {
        _notifications.insert(0, notification);
        notifyListeners();
      }
    });

    // Load initial data from Hive
    await _loadFromHive();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    try {
      final box = Hive.box<NotificationModel>(NotificationService.boxName);
      _notifications = box.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications from Hive: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _notifications[index].save(); // Persist change to Hive
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        await n.save();
      }
    }
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notification = _notifications.removeAt(index);
      await notification.delete(); // Delete from Hive
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    final box = Hive.box<NotificationModel>(NotificationService.boxName);
    await box.clear();
    _notifications.clear();
    notifyListeners();
  }

  // --- Testing Methods ---
  
  void addTestNotification() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final testNotif = NotificationModel(
      id: id,
      title: 'AI IDE Notification',
      body: 'This is a real-time alert delivered via WebSockets and persisted locally without Firebase.',
      type: 'message',
      timestamp: DateTime.now(),
    );
    
    // Save to Hive
    final box = Hive.box<NotificationModel>(NotificationService.boxName);
    box.put(id, testNotif);
    
    // Update State
    _notifications.insert(0, testNotif);
    notifyListeners();
    
    // Show OS Alert
    _service.showNotification(testNotif);
  }
}
