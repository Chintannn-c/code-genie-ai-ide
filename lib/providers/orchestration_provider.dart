import 'dart:async';
import 'package:flutter/material.dart';
import '../services/orchestration_service.dart';

/// Provides live orchestration telemetry to the UI.
class OrchestrationProvider extends ChangeNotifier {
  final OrchestrationService _service = OrchestrationService();
  Timer? _pollTimer;

  // Stats
  Map<String, dynamic> stats = {};
  Map<String, dynamic> securityStats = {};
  Map<String, dynamic> auditData = {};
  List<dynamic> workflows = [];
  List<dynamic> approvals = [];
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

  void setToken(String? token) => _service.setToken(token);

  /// Start auto-polling every 5 seconds
  void startPolling() {
    _pollTimer?.cancel();
    refresh(); // Immediate first fetch
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
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
      error = null;
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
