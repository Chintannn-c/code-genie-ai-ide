import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketService._internal();
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get stream => _messageController.stream;
  
  Timer? _reconnectTimer;
  String? _currentUserId;

  void connect(String userId, [String? token]) {
    if (_currentUserId == userId && _channel != null) return;
    
    _currentUserId = userId;
    _disconnectInternal();
    
    final tokenQuery = token != null ? '?token=$token' : '';
    final wsUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws') + '/ws/$userId$tokenQuery';
    
    try {
      if (kIsWeb) {
        // Explicit Web Connection
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } else {
        // Native/Mobile Connection
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      }
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            print('WS Data Error: $e');
          }
        },
        onDone: () => _handleReconnect(),
        onError: (e) => _handleReconnect(),
      );
      
      print('Connected to Sync Hub: $wsUrl');
    } catch (e) {
      print('WS Connection Error: $e');
      _handleReconnect();
    }
  }

  void _handleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_currentUserId != null) {
        connect(_currentUserId!);
      }
    });
  }

  void disconnect() {
    _currentUserId = null;
    _reconnectTimer?.cancel();
    _disconnectInternal();
  }

  void _disconnectInternal() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
