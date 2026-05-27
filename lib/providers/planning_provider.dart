import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/plan_model.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';

class PlanningProvider extends ChangeNotifier {
  static const String boxName = 'plans_box';
  
  PlanModel? _currentPlan;
  List<PlanModel> _history = [];
  bool _isLoading = false;
  StreamSubscription? _rawMessageSub;
  Timer? _pollTimer;

  PlanModel? get currentPlan => _currentPlan;
  List<PlanModel> get history => _history;
  bool get isLoading => _isLoading;
  bool get hasActivePlan => _currentPlan != null;

  PlanningProvider() {
    _init();
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    // Register adapters if they aren't already (PlanStepStatus is 1, PlanStep is 2, PlanModel is 3)
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlanStepStatusAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PlanStepAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(PlanModelAdapter());
    
    await Hive.openBox<PlanModel>(boxName);
    await _loadHistory();

    // Listen for real-time plans from the backend
    _rawMessageSub = NotificationService().rawMessageStream.listen((message) {
      if (message['type'] == 'plan_created') {
        final plan = PlanModel.fromJson(message['plan']);
        setCurrentPlan(plan);
      } else if (message['type'] == 'plan_step_update') {
        final stepId = message['step_id'];
        final statusStr = message['status'];
        final status = _parseStatus(statusStr);
        updateStepStatus(stepId, status, output: message['output'], diff: message['diff']);
      } else if (message['type'] == 'execution_log') {
        final stepId = message['step_id'];
        final log = message['output'];
        updateStepLog(stepId, log);
      }
    });

    // Recovery of active state on startup or refresh
    if (_history.isNotEmpty) {
      final latest = _history.first;
      final hasUnfinished = latest.steps.any((s) => s.status == PlanStepStatus.pending || s.status == PlanStepStatus.running);
      if (latest.isApproved && hasUnfinished) {
        _currentPlan = latest;
        // Start polling fallback in case WebSockets dropped
        _startPollingFallback(_currentPlan!.id, null);
      } else {
        _currentPlan = latest;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _rawMessageSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  PlanStepStatus _parseStatus(String? status) {
    switch (status) {
      case 'running': return PlanStepStatus.running;
      case 'completed': return PlanStepStatus.completed;
      case 'failed': return PlanStepStatus.failed;
      default: return PlanStepStatus.pending;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final box = Hive.box<PlanModel>(boxName);
      _history = box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading planning history: $e');
    }
  }

  void setCurrentPlan(PlanModel plan) {
    _currentPlan = plan;
    // We removed auto-approve so the user can review it first
    notifyListeners();
  }

  Future<void> generatePlan(String prompt, String userId, String? token, {String? chatId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/plan');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'prompt': prompt,
          if (chatId != null) 'chat_id': chatId,
        }),
      );

      if (response.statusCode == 200) {
        final planData = jsonDecode(response.body);
        final plan = PlanModel.fromJson(planData);
        setCurrentPlan(plan);
        // Instantly execute the mission/plan autonomously
        await approvePlan(userId, token);
      } else {
        debugPrint('❌ Plan Generation Failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error generating plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPlanStatus(String planId, {String? token}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/plan/$planId');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final planData = jsonDecode(response.body);
        final plan = PlanModel.fromJson(planData);
        _currentPlan = plan;
        
        // Save to Hive locally
        final box = Hive.box<PlanModel>(boxName);
        await box.put(plan.id, plan);
        
        notifyListeners();
        
        // If finished, stop polling
        final isFinished = plan.steps.every(
          (s) => s.status == PlanStepStatus.completed || s.status == PlanStepStatus.failed
        );
        if (isFinished) {
          _pollTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching plan status: $e');
    }
  }

  void _startPollingFallback(String planId, String? token) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_currentPlan == null || !_currentPlan!.isApproved) {
        timer.cancel();
        return;
      }
      
      final isFinished = _currentPlan!.steps.every(
        (s) => s.status == PlanStepStatus.completed || s.status == PlanStepStatus.failed
      );
      
      if (isFinished) {
        timer.cancel();
        return;
      }
      
      await fetchPlanStatus(planId, token: token);
    });
  }

  Future<void> approvePlan(String userId, String? token) async {
    if (_currentPlan != null) {
      _currentPlan!.isApproved = true;
      final box = Hive.box<PlanModel>(boxName);
      await box.put(_currentPlan!.id, _currentPlan!);
      notifyListeners();

      // Trigger automatic background polling fallback in case WS fails
      _startPollingFallback(_currentPlan!.id, token);

      // Trigger Backend Execution
      try {
        final url = Uri.parse('${ApiConfig.baseUrl}/api/plan/${_currentPlan!.id}/execute');
        debugPrint('Triggering Autonomous Execution: $url');
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(_currentPlan!.toJson()),
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Execution Started Successfully');
        } else {
          debugPrint('❌ Execution Failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Error triggering plan execution: $e');
      }
    }
  }

  Future<void> updateStepStatus(String stepId, PlanStepStatus status, {String? output, String? diff}) async {
    if (_currentPlan != null) {
      final index = _currentPlan!.steps.indexWhere((s) => s.id == stepId);
      if (index != -1) {
        final step = _currentPlan!.steps[index];
        step.status = status;
        if (output != null) step.output = output;
        if (diff != null) step.diff = diff;
        
        final box = Hive.box<PlanModel>(boxName);
        await box.put(_currentPlan!.id, _currentPlan!);
        notifyListeners();
      }
    }
  }

  void updateStepLog(String stepId, String log) {
    if (_currentPlan != null) {
      final stepIndex = _currentPlan!.steps.indexWhere((s) => s.id == stepId);
      if (stepIndex != -1) {
        final step = _currentPlan!.steps[stepIndex];
        step.logs ??= [];
        step.logs!.add(log);
        
        notifyListeners();
        // Persist change
        final box = Hive.box<PlanModel>(boxName);
        box.put(_currentPlan!.id, _currentPlan!);
      }
    }
  }

  void reorderSteps(int oldIndex, int newIndex) {
    if (_currentPlan != null) {
      if (newIndex > oldIndex) newIndex -= 1;
      final step = _currentPlan!.steps.removeAt(oldIndex);
      _currentPlan!.steps.insert(newIndex, step);
      
      notifyListeners();
      final box = Hive.box<PlanModel>(boxName);
      box.put(_currentPlan!.id, _currentPlan!);
    }
  }

  void addStep(PlanStep step) {
    if (_currentPlan != null) {
      _currentPlan!.steps.add(step);
      notifyListeners();
      final box = Hive.box<PlanModel>(boxName);
      box.put(_currentPlan!.id, _currentPlan!);
    }
  }

  void removeStep(String stepId) {
    if (_currentPlan != null) {
      _currentPlan!.steps.removeWhere((s) => s.id == stepId);
      notifyListeners();
      final box = Hive.box<PlanModel>(boxName);
      box.put(_currentPlan!.id, _currentPlan!);
    }
  }

  void updateStep(String stepId, {String? title, String? description}) {
    if (_currentPlan != null) {
      final index = _currentPlan!.steps.indexWhere((s) => s.id == stepId);
      if (index != -1) {
        final step = _currentPlan!.steps[index];
        final newStep = PlanStep(
          id: step.id,
          title: title ?? step.title,
          description: description ?? step.description,
          status: step.status,
          output: step.output,
          logs: step.logs,
          toolCall: step.toolCall,
        );
        _currentPlan!.steps[index] = newStep;
        
        notifyListeners();
        final box = Hive.box<PlanModel>(boxName);
        box.put(_currentPlan!.id, _currentPlan!);
      }
    }
  }

  void clearActivePlan() {
    _currentPlan = null;
    notifyListeners();
  }

  // --- Testing Methods ---

  void addTestPlan() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final testPlan = PlanModel(
      id: id,
      goal: 'Implement a secure authentication flow with Hive persistence',
      createdAt: DateTime.now(),
      steps: [
        PlanStep(
          id: 'step_1',
          title: 'Define Auth Data Models',
          description: 'Create Hive-compatible models for User and Session state.',
          status: PlanStepStatus.completed,
        ),
        PlanStep(
          id: 'step_2',
          title: 'Implement AuthService Logic',
          description: 'Develop the core business logic for token management and validation.',
          status: PlanStepStatus.running,
        ),
        PlanStep(
          id: 'step_3',
          title: 'Design Login UI Components',
          description: 'Build responsive, theme-aware input fields and buttons.',
          status: PlanStepStatus.pending,
        ),
        PlanStep(
          id: 'step_4',
          title: 'Integrate Persistence Layer',
          description: 'Surgically connect the AuthService to Hive for session caching.',
          status: PlanStepStatus.pending,
        ),
      ],
    );

    _currentPlan = testPlan;
    notifyListeners();
  }
}
