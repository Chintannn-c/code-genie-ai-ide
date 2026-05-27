import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';
import 'auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _streamSub;
  StreamSubscription? _rawSub;

  String? _userId;
  String? _token;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Real-time Settings States
  bool push = true;
  bool aiAlerts = true;
  bool securityAlerts = true;
  bool modelFailure = true;
  bool deployment = true;
  bool collaboration = true;
  bool email = false;
  bool sound = true;

  // Advanced Enterprise Preferences
  int historyRetentionDays = 30;
  String aiAlertFiltering = "ALL";
  bool quietHoursEnabled = false;
  String quietHoursStart = "22:00";
  String quietHoursEnd = "08:00";
  String customWebhookUrl = "";
  String slackWebhookUrl = "";
  String discordWebhookUrl = "";
  String teamsWebhookUrl = "";

  // Synchronization status indicators
  bool isSyncing = false;
  String syncStatus = "Saved & Applied";

  NotificationProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Listen to local NotificationService stream
    _streamSub = _service.notificationStream.listen((notification) {
      final exists = _notifications.any((n) => n.id == notification.id);
      if (!exists) {
        _notifications.insert(0, notification);
        notifyListeners();
      }
    });

    await _loadFromHive();

    _isLoading = false;
    notifyListeners();
  }

  void updateAuth(String userId, String? token, [AuthProvider? auth]) {
    if (_userId == userId && _token == token) return;
    _userId = userId;
    _token = token;
    
    // Subscribe to raw socket channel to receive distributed settings updates
    _rawSub?.cancel();
    _rawSub = _service.rawMessageStream.listen((event) {
      if (event['type'] == 'notification_settings_update') {
        _handleSettingsUpdatePayload(event['notification_settings']);
      } else if (event['type'] == 'session_revoked') {
        debugPrint('🔒 [SECURITY] WebSocket remote session revocation received. Triggering forced logout...');
        auth?.triggerSessionExpiry();
      } else if (event['type'] == 'session_revoked_event' || event['type'] == 'all_sessions_revoked_event') {
        // If sessions are revoked from another device, dynamically reload active sessions
        _service.rawMessageStream.timeout(const Duration(seconds: 0), onTimeout: (sink) {});
      }
    });

    fetchSettings();
  }

  void _handleSettingsUpdatePayload(Map<String, dynamic> data) {
    push = data['push'] ?? true;
    aiAlerts = data['ai_alerts'] ?? true;
    securityAlerts = data['security_alerts'] ?? true;
    modelFailure = data['model_failure'] ?? true;
    deployment = data['deployment'] ?? true;
    collaboration = data['collaboration'] ?? true;
    email = data['email'] ?? false;
    sound = data['sound'] ?? true;
    historyRetentionDays = data['history_retention_days'] ?? 30;
    aiAlertFiltering = data['ai_alert_filtering'] ?? "ALL";
    quietHoursEnabled = data['quiet_hours_enabled'] ?? false;
    quietHoursStart = data['quiet_hours_start'] ?? "22:00";
    quietHoursEnd = data['quiet_hours_end'] ?? "08:00";
    customWebhookUrl = data['custom_webhook_url'] ?? "";
    slackWebhookUrl = data['slack_webhook_url'] ?? "";
    discordWebhookUrl = data['discord_webhook_url'] ?? "";
    teamsWebhookUrl = data['teams_webhook_url'] ?? "";
    
    syncStatus = "Saved & Applied";
    isSyncing = false;
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    if (_token == null) return;
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/notification-settings');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'success') {
          _handleSettingsUpdatePayload(resData['notification_settings']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching notification settings: $e');
    }
  }

  Future<void> updateSettings({
    bool? pushVal,
    bool? aiAlertsVal,
    bool? securityAlertsVal,
    bool? modelFailureVal,
    bool? deploymentVal,
    bool? collaborationVal,
    bool? emailVal,
    bool? soundVal,
    int? historyRetentionDaysVal,
    String? aiAlertFilteringVal,
    bool? quietHoursEnabledVal,
    String? quietHoursStartVal,
    String? quietHoursEndVal,
    String? customWebhookUrlVal,
    String? slackWebhookUrlVal,
    String? discordWebhookUrlVal,
    String? teamsWebhookUrlVal,
  }) async {
    if (_token == null) return;

    // Snapshot variables for rollback recovery
    final originalPush = push;
    final originalAiAlerts = aiAlerts;
    final originalSecurityAlerts = securityAlerts;
    final originalModelFailure = modelFailure;
    final originalDeployment = deployment;
    final originalCollaboration = collaboration;
    final originalEmail = email;
    final originalSound = sound;
    final originalHistoryRetentionDays = historyRetentionDays;
    final originalAiAlertFiltering = aiAlertFiltering;
    final originalQuietHoursEnabled = quietHoursEnabled;
    final originalQuietHoursStart = quietHoursStart;
    final originalQuietHoursEnd = quietHoursEnd;
    final originalCustomWebhookUrl = customWebhookUrl;
    final originalSlackWebhookUrl = slackWebhookUrl;
    final originalDiscordWebhookUrl = discordWebhookUrl;
    final originalTeamsWebhookUrl = teamsWebhookUrl;

    // Apply Optimistic Update
    if (pushVal != null) push = pushVal;
    if (aiAlertsVal != null) aiAlerts = aiAlertsVal;
    if (securityAlertsVal != null) securityAlerts = securityAlertsVal;
    if (modelFailureVal != null) modelFailure = modelFailureVal;
    if (deploymentVal != null) deployment = deploymentVal;
    if (collaborationVal != null) collaboration = collaborationVal;
    if (emailVal != null) email = emailVal;
    if (soundVal != null) sound = soundVal;
    if (historyRetentionDaysVal != null) historyRetentionDays = historyRetentionDaysVal;
    if (aiAlertFilteringVal != null) aiAlertFiltering = aiAlertFilteringVal;
    if (quietHoursEnabledVal != null) quietHoursEnabled = quietHoursEnabledVal;
    if (quietHoursStartVal != null) quietHoursStart = quietHoursStartVal;
    if (quietHoursEndVal != null) quietHoursEnd = quietHoursEndVal;
    if (customWebhookUrlVal != null) customWebhookUrl = customWebhookUrlVal;
    if (slackWebhookUrlVal != null) slackWebhookUrl = slackWebhookUrlVal;
    if (discordWebhookUrlVal != null) discordWebhookUrl = discordWebhookUrlVal;
    if (teamsWebhookUrlVal != null) teamsWebhookUrl = teamsWebhookUrlVal;

    isSyncing = true;
    syncStatus = "Syncing...";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/notification-settings/update');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'push': push,
          'ai_alerts': aiAlerts,
          'security_alerts': securityAlerts,
          'model_failure': modelFailure,
          'deployment': deployment,
          'collaboration': collaboration,
          'email': email,
          'sound': sound,
          'history_retention_days': historyRetentionDays,
          'ai_alert_filtering': aiAlertFiltering,
          'quiet_hours_enabled': quietHoursEnabled,
          'quiet_hours_start': quietHoursStart,
          'quiet_hours_end': quietHoursEnd,
          'custom_webhook_url': customWebhookUrl,
          'slack_webhook_url': slackWebhookUrl,
          'discord_webhook_url': discordWebhookUrl,
          'teams_webhook_url': teamsWebhookUrl,
        }),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'success') {
          syncStatus = "Saved & Applied";
          isSyncing = false;
          notifyListeners();
          return;
        }
      }
      throw Exception('Server returned status: ${response.statusCode}');
    } catch (e) {
      debugPrint('Failed to persist notification settings. Rolling back optimistic update: $e');
      
      // Rollback
      push = originalPush;
      aiAlerts = originalAiAlerts;
      securityAlerts = originalSecurityAlerts;
      modelFailure = originalModelFailure;
      deployment = originalDeployment;
      collaboration = originalCollaboration;
      email = originalEmail;
      sound = originalSound;
      historyRetentionDays = originalHistoryRetentionDays;
      aiAlertFiltering = originalAiAlertFiltering;
      quietHoursEnabled = originalQuietHoursEnabled;
      quietHoursStart = originalQuietHoursStart;
      quietHoursEnd = originalQuietHoursEnd;
      customWebhookUrl = originalCustomWebhookUrl;
      slackWebhookUrl = originalSlackWebhookUrl;
      discordWebhookUrl = originalDiscordWebhookUrl;
      teamsWebhookUrl = originalTeamsWebhookUrl;

      syncStatus = "Sync Failed (Rolled Back)";
      isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _rawSub?.cancel();
    super.dispose();
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
      await _notifications[index].save();
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
      await notification.delete();
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    final box = Hive.box<NotificationModel>(NotificationService.boxName);
    await box.clear();
    _notifications.clear();
    notifyListeners();
  }

  // --- Real-time Activity Simulations for AI Ops Center ---
  
  void simulateEvent(String category) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    String title = "Notification Title";
    String body = "Description goes here";
    String type = "system";
    Map<String, dynamic> metadata = {};

    switch (category) {
      case 'ai_complete':
        title = "AI Completed Task";
        body = "Successfully synchronized state manager and compiled Flutter Web release bundle.";
        type = "ai";
        metadata = {
          "duration": "14.2s",
          "model": "Gemini 1.5 Pro",
          "tokens": "8,192 used",
          "pipeline": "State Synthesis Engine",
          "reasoning": "Optimized memory mapping, resolved all active provider connections, and established WebSocket heartbeats."
        };
        break;
      case 'failover':
        title = "Model Failover Initiated";
        body = "Gemini experienced timeout error (504 Gateway) -> Switched to Groq Llama 3 fallback.";
        type = "model_failure";
        metadata = {
          "latency": "220ms reroute",
          "failover_cause": "Timeout (HTTP 504)",
          "active_provider": "Groq Llama 3",
          "estimated_recovery": "5 minutes",
          "affected_workflows": "Chat Response Generator"
        };
        break;
      case 'deployment':
        title = "Deployment Succeeded";
        body = "Release bundle v1.4.2 successfully compiled and pushed to production environment on Railway.";
        type = "deployment";
        metadata = {
          "environment": "Production",
          "platform": "Railway / Docker",
          "branch": "main",
          "build_duration": "1m 45s",
          "health_status": "100% healthy",
          "logs_url": "https://railway.app/project/genie/logs"
        };
        break;
      case 'security':
        title = "Security Alert: New Login";
        body = "Suspicious login detected from Chrome (Windows) in Frankfurt, Germany.";
        type = "security";
        metadata = {
          "severity": "HIGH",
          "ip_address": "194.22.84.103",
          "fingerprint": "sec_win_chrome_938102",
          "location": "Frankfurt, Germany",
          "mitigation": "Review active sessions in security workspace or trigger instant revocation."
        };
        break;
      case 'rag_failed':
        title = "Context Injection Failed";
        body = "Vector retrieval timeout. Falling back to semantic local chunk matches.";
        type = "system";
        metadata = {
          "error_code": "RAG_TIMEOUT",
          "source": "Qdrant Vector Server",
          "latency": "5000ms",
          "action": "Triggered offline local search context fallback"
        };
        break;
      case 'agent':
        title = "Autonomous Agent Completed Run";
        body = "Autonomous agent successfully resolved the requested ticket and pushed git patch.";
        type = "ai";
        metadata = {
          "agent_name": "Antigravity Coder",
          "files_modified": "lib/screens/settings/notifications_page.dart",
          "complexity": "High",
          "reasoning_steps": "1. Parsed requirements\n2. Built custom UI layouts\n3. Wrote tests\n4. Verified compiler logs successfully."
        };
        break;
      default:
        title = "Generic Notification";
        body = "Event occurred in the Code Genie ecosystem.";
        type = "system";
        metadata = {
          "timestamp": DateTime.now().toIso8601String(),
          "device": "Android Client"
        };
    }

    final testNotif = NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      data: metadata,
    );
    
    final box = Hive.box<NotificationModel>(NotificationService.boxName);
    box.put(id, testNotif);
    
    _notifications.insert(0, testNotif);
    notifyListeners();
    
    if (sound) {
      _service.showNotification(testNotif);
    }
  }

  void addTestNotification() {
    simulateEvent('ai_complete');
  }
}
