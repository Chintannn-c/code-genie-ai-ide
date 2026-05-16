import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Service for fetching orchestration telemetry from the backend.
class OrchestrationService {
  final http.Client _client = http.Client();
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Fetch live orchestration stats
  Future<Map<String, dynamic>> getStats() async {
    try {
      final res = await _client
          .get(_uri('/api/orchestration/stats'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  /// Fetch security SOC data
  Future<Map<String, dynamic>> getSecurityStats() async {
    try {
      final res = await _client
          .get(_uri('/api/orchestration/security'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  /// Fetch audit trail
  Future<Map<String, dynamic>> getAuditTrail() async {
    try {
      final res = await _client
          .get(_uri('/api/orchestration/audit'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  /// Fetch active workflows
  Future<List<dynamic>> getWorkflows() async {
    try {
      final res = await _client
          .get(_uri('/api/orchestration/workflows'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['workflows'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Fetch pending approvals
  Future<List<dynamic>> getApprovals() async {
    try {
      final res = await _client
          .get(_uri('/api/orchestration/approvals'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['pending'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Approve/deny a request
  Future<bool> resolveApproval(String requestId, bool approved) async {
    try {
      final res = await _client.post(
        _uri('/api/orchestration/approvals/$requestId?approved=$approved'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _client.close();
}
