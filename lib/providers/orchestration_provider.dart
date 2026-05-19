import 'dart:async';
import 'package:flutter/material.dart';
import '../services/orchestration_service.dart';

/// Provides live orchestration telemetry to the UI.
class OrchestrationProvider extends ChangeNotifier {
  final OrchestrationService _service = OrchestrationService();
  Timer? _pollTimer;
  DateTime? lastRefreshed;
  int _refreshIntervalSeconds = 5;

  // Stats
  Map<String, dynamic> stats = {};
  Map<String, dynamic> securityStats = {};
  Map<String, dynamic> auditData = {};
  List<dynamic> workflows = [];
  List<dynamic> approvals = [];
  List<dynamic> modelLimits = [];
  bool isLoading = false;
  String? error;

  // Derived metrics
  int get totalOrchestrations => stats['total_orchestrations'] ?? 0;
  int get totalAgentCalls => stats['total_agent_calls'] ?? 0;
  int get synthesisCount => stats['synthesis_count'] ?? 0;
  int get totalScanned => securityStats['total_scanned'] ?? 0;
  int get blocked => securityStats['blocked'] ?? 0;
  int get flagged => securityStats['flagged'] ?? 0;
  int get clean => securityStats['clean'] ?? 0;
  int get pendingApprovals => approvals.length;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;

  String get lastRefreshedFormatted {
    if (lastRefreshed == null) return 'Never';
    final h = lastRefreshed!.hour.toString().padLeft(2, '0');
    final m = lastRefreshed!.minute.toString().padLeft(2, '0');
    final s = lastRefreshed!.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void setToken(String? token) => _service.setToken(token);

  /// Start auto-polling with the configured interval
  void startPolling() {
    _pollTimer?.cancel();
    refresh(); // Immediate first fetch
    _pollTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (_) => refresh());
  }

  void setRefreshInterval(int seconds) {
    if (_refreshIntervalSeconds == seconds) return;
    _refreshIntervalSeconds = seconds;
    if (_pollTimer != null) {
      startPolling();
    }
    notifyListeners();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        _service.getStats(),
        _service.getSecurityStats(),
        _service.getAuditTrail(),
        _service.getWorkflows(),
        _service.getApprovals(),
      ]);

      stats = results[0] as Map<String, dynamic>;
      securityStats = results[1] as Map<String, dynamic>;
      auditData = results[2] as Map<String, dynamic>;
      workflows = results[3] as List<dynamic>;
      approvals = results[4] as List<dynamic>;
      modelLimits = stats['model_limits'] as List<dynamic>? ?? [];
      error = null;
      lastRefreshed = DateTime.now();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<bool> resolveApproval(String id, bool approved) async {
    final ok = await _service.resolveApproval(id, approved);
    if (ok) await refresh();
    return ok;
  }

  @override
  void dispose() {
    stopPolling();
    _service.dispose();
    super.dispose();
  }
}
