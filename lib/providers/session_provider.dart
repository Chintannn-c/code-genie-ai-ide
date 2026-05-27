import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class UserSession {
  final String id;
  final String deviceName;
  final String browser;
  final String operatingSystem;
  final String ipAddress;
  final String platform;
  final String userAgent;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isCurrent;
  final bool isActive;

  UserSession({
    required this.id,
    required this.deviceName,
    required this.browser,
    required this.operatingSystem,
    required this.ipAddress,
    required this.platform,
    required this.userAgent,
    required this.createdAt,
    required this.lastSeen,
    required this.isCurrent,
    required this.isActive,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'] ?? '',
      deviceName: json['device_name'] ?? 'Unknown Device',
      browser: json['browser'] ?? 'Unknown Browser',
      operatingSystem: json['operating_system'] ?? 'Unknown OS',
      ipAddress: json['ip_address'] ?? 'Unknown IP',
      platform: json['platform'] ?? 'Web',
      userAgent: json['user_agent'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen']) : DateTime.now(),
      isCurrent: json['is_current'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }
}

class SessionProvider extends ChangeNotifier {
  List<UserSession> _sessions = [];
  bool _isLoading = false;
  String? _error;
  String? _token;

  List<UserSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String? token) {
    if (_token != token) {
      _token = token;
      if (_token != null) {
        fetchSessions();
      } else {
        _sessions = [];
        notifyListeners();
      }
    }
  }

  Future<void> fetchSessions() async {
    if (_token == null) return;
    _isLoading = true;
    _error = null;
    // We notify listeners to show the loading skeleton in UI
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/security/sessions'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List list = data['sessions'] ?? [];
          _sessions = list.map((item) => UserSession.fromJson(item)).toList();
          
          // Sort sessions so the current one is always first, then by last seen
          _sessions.sort((a, b) {
            if (a.isCurrent) return -1;
            if (b.isCurrent) return 1;
            return b.lastSeen.compareTo(a.lastSeen);
          });
          
          _error = null;
        } else {
          _error = data['message'] ?? 'Failed to load sessions';
        }
      } else {
        _error = 'Failed to load sessions (${response.statusCode})';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> revokeSession(String sessionId) async {
    if (_token == null) return false;
    
    // Find the session for optimistic UI removal
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    UserSession? removedSession;
    if (index != -1) {
      removedSession = _sessions[index];
      _sessions.removeAt(index);
      notifyListeners();
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/security/sessions/$sessionId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return true;
        }
      }
      
      // Rollback on failure
      if (removedSession != null) {
        _sessions.insert(index, removedSession);
        notifyListeners();
      }
      return false;
    } catch (e) {
      if (removedSession != null) {
        _sessions.insert(index, removedSession);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> revokeAllOtherSessions() async {
    if (_token == null) return false;

    // Optimistically keep only the current session
    final List<UserSession> originalSessions = List.from(_sessions);
    _sessions.removeWhere((s) => !s.isCurrent);
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/security/sessions/revoke-all'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return true;
        }
      }
      
      // Rollback on failure
      _sessions = originalSessions;
      notifyListeners();
      return false;
    } catch (e) {
      _sessions = originalSessions;
      notifyListeners();
      return false;
    }
  }
}
