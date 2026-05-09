import 'package:hive/hive.dart';

part 'plan_model.g.dart';

@HiveType(typeId: 1)
enum PlanStepStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  running,
  @HiveField(2)
  completed,
  @HiveField(3)
  failed
}

@HiveType(typeId: 2)
class PlanStep extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  PlanStepStatus status;
  
  @HiveField(4)
  String? output;

  @HiveField(5)
  List<String>? logs;

  @HiveField(6)
  Map<String, dynamic>? toolCall;

  @HiveField(7)
  String? diff;

  PlanStep({
    required this.id,
    required this.title,
    required this.description,
    this.status = PlanStepStatus.pending,
    this.output,
    this.logs,
    this.toolCall,
    this.diff,
  });

  factory PlanStep.fromJson(Map<String, dynamic> json) {
    return PlanStep(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: _statusFromString(json['status']),
      output: json['output'],
      logs: (json['logs'] as List?)?.map((e) => e.toString()).toList(),
      toolCall: json['tool_call'],
      diff: json['diff'],
    );
  }

  static PlanStepStatus _statusFromString(String? status) {
    switch (status) {
      case 'running': return PlanStepStatus.running;
      case 'completed': return PlanStepStatus.completed;
      case 'failed': return PlanStepStatus.failed;
      default: return PlanStepStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'output': output,
      'logs': logs,
      'tool_call': toolCall,
      'diff': diff,
    };
  }
}

@HiveType(typeId: 3)
class PlanModel extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String goal;
  
  @HiveField(2)
  final List<PlanStep> steps;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  bool isApproved;

  PlanModel({
    required this.id,
    required this.goal,
    required this.steps,
    required this.createdAt,
    this.isApproved = false,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] ?? '',
      goal: json['goal'] ?? '',
      steps: (json['steps'] as List?)?.map((s) => PlanStep.fromJson(s as Map<String, dynamic>)).toList() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      isApproved: json['is_approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal': goal,
      'steps': steps.map((s) => s.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'is_approved': isApproved,
    };
  }
}
