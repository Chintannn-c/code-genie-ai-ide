import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/notification_model.dart';
import '../config/api_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  
  static const String boxName = 'notifications_box';

  // Stream controller to notify UI of new notifications
  final _notificationStreamController = StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get notificationStream => _notificationStreamController.stream;

  // Generic stream for all WebSocket messages
  final _rawMessageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rawMessageStream => _rawMessageStreamController.stream;

  // Stream controller for navigation events triggered by notification taps
  final _navigationStreamController = StreamController<String?>.broadcast();
  Stream<String?> get navigationStream => _navigationStreamController.stream;

  Future<void> init() async {
    // 1. Initialize Hive
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NotificationModelAdapter());
    }
    await Hive.openBox<NotificationModel>(boxName);

    // 2. Initialize Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap by broadcasting payload for navigation
        debugPrint('🚀 Notification tapped with payload: ${details.payload}');
        _navigationStreamController.add(details.payload);
      },
    );
    
    debugPrint('🔔 NotificationService Initialized');
  }

  void connect(String userId, String? token) {
    if (_isConnected) return;

    final wsUrl = Uri.parse('${ApiConfig.wsBaseUrl}${ApiConfig.wsNotifications(userId)}${token != null ? '?token=$token' : ''}');
    debugPrint('🔌 Connecting to Notifications WebSocket: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onDone: () {
          _isConnected = false;
          debugPrint('📡 Notifications WebSocket Closed. Retrying in 5s...');
          Future.delayed(const Duration(seconds: 5), () => connect(userId, token));
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('❌ Notifications WebSocket Error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      debugPrint('❌ Failed to connect to Notifications WebSocket: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    debugPrint('🔌 Notifications WebSocket Disconnected');
  }

  Future<void> _handleIncomingMessage(dynamic message) async {
    try {
      debugPrint('📥 Incoming WebSocket Message: $message');
      final Map<String, dynamic> data = jsonDecode(message);
      
      // 1. Broadcast to generic listeners (e.g., PlanningProvider)
      _rawMessageStreamController.add(data);

      // 2. Handle as Notification if applicable
      if (data.containsKey('title') && data.containsKey('body')) {
        final notification = NotificationModel.fromJson(data);
        
        // Save to Hive
        final box = Hive.box<NotificationModel>(boxName);
        await box.put(notification.id, notification);

        // Notify notification listeners
        _notificationStreamController.add(notification);

        // Show Local Notification (System Tray)
        await _showLocalNotification(notification);
      }
    } catch (e) {
      debugPrint('⚠️ Error handling incoming WebSocket message: $e');
    }
  }

  Future<void> _showLocalNotification(NotificationModel notification) async {
    if (kIsWeb) {
      // For web, the browser might block local notifications without permission.
      // We rely on the In-App stream for web primarily.
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Notifications',
      channelDescription: 'Used for all app notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
      payload: jsonEncode(notification.toJson()),
    );
  }

  void dispose() {
    _notificationStreamController.close();
    _rawMessageStreamController.close();
    disconnect();
  }

  /// Public method to show a notification manually (useful for testing)
  Future<void> showNotification(NotificationModel notification) async {
    await _showLocalNotification(notification);
  }
}
