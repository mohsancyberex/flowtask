import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';  // Add this import

enum TaskPriority { none, low, medium, high }
enum TaskEnergy { low, medium, high }
enum TaskState { pending, snoozed, completed }

class Subtask {
  final String id;
  String text;
  bool isDone;

  Subtask({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isDone': isDone,
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      text: map['text'],
      isDone: map['isDone'] ?? false,
    );
  }
}

class Task {
  final String id;
  final String text;
  final DateTime createdAt;
  DateTime? dueDate;
  TaskPriority priority;
  TaskEnergy? energy;
  TaskState state;
  DateTime? lastShown;
  int avoidanceCount;
  DateTime? hiddenUntil;
  DateTime? interventionShownAt;
  List<String>? tags;
  int? estimatedMinutes;
  String? project;
  
  // Phase 2 Fields
  bool isRecurring;
  String? recurrencePattern; // daily, weekly, custom
  List<Subtask> subtasks;
  int durationSeconds;
  bool isTimerRunning;
  DateTime? lastTimerStart;
  DateTime? completedAt;
  
  Task({
    required this.id,
    required this.text,
    required this.createdAt,
    this.dueDate,
    this.priority = TaskPriority.none,
    this.energy,
    this.state = TaskState.pending,
    this.lastShown,
    this.avoidanceCount = 0,
    this.hiddenUntil,
    this.interventionShownAt,
    this.tags,
    this.estimatedMinutes,
    this.project,
    this.isRecurring = false,
    this.recurrencePattern,
    this.subtasks = const [],
    this.durationSeconds = 0,
    this.isTimerRunning = false,
    this.lastTimerStart,
    this.completedAt,
  });
  
  bool needsIntervention() {
    return avoidanceCount >= 3 && 
           (interventionShownAt == null || 
            DateTime.now().difference(interventionShownAt!).inDays >= 1);
  }
  
  Color get priorityColor {
    switch (priority) {
      case TaskPriority.high: return const Color(0xFFF43F5E); // Rose 500
      case TaskPriority.medium: return const Color(0xFFF59E0B); // Amber 500
      case TaskPriority.low: return const Color(0xFF3B82F6); // Blue 500
      default: return Colors.grey;
    }
  }
  
  String get priorityText {
    switch (priority) {
      case TaskPriority.high: return 'HIGH PRIORITY';
      case TaskPriority.medium: return 'MEDIUM PRIORITY';
      case TaskPriority.low: return 'LOW PRIORITY';
      default: return '';
    }
  }
  
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());
  
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
           dueDate!.month == now.month &&
           dueDate!.day == now.day;
  }

  double get subtaskProgress {
    if (subtasks.isEmpty) return 0.0;
    return subtasks.where((s) => s.isDone).length / subtasks.length;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': describeEnum(priority),
      'energy': energy != null ? describeEnum(energy!) : null,
      'state': describeEnum(state),
      'lastShown': lastShown?.toIso8601String(),
      'avoidanceCount': avoidanceCount,
      'hiddenUntil': hiddenUntil?.toIso8601String(),
      'interventionShownAt': interventionShownAt?.toIso8601String(),
      'tags': tags,
      'estimatedMinutes': estimatedMinutes,
      'project': project,
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'durationSeconds': durationSeconds,
      'isTimerRunning': isTimerRunning,
      'lastTimerStart': lastTimerStart?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
  
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      priority: _parsePriority(map['priority']),
      energy: map['energy'] != null ? _parseEnergy(map['energy']) : null,
      state: _parseState(map['state']),
      lastShown: map['lastShown'] != null ? DateTime.parse(map['lastShown']) : null,
      avoidanceCount: map['avoidanceCount'] ?? 0,
      hiddenUntil: map['hiddenUntil'] != null ? DateTime.parse(map['hiddenUntil']) : null,
      interventionShownAt: map['interventionShownAt'] != null ? DateTime.parse(map['interventionShownAt']) : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      estimatedMinutes: map['estimatedMinutes'],
      project: map['project'],
      isRecurring: map['isRecurring'] ?? false,
      recurrencePattern: map['recurrencePattern'],
      subtasks: map['subtasks'] != null 
          ? (map['subtasks'] as List).map((s) => Subtask.fromMap(s)).toList()
          : [],
      durationSeconds: map['durationSeconds'] ?? 0,
      isTimerRunning: map['isTimerRunning'] ?? false,
      lastTimerStart: map['lastTimerStart'] != null ? DateTime.parse(map['lastTimerStart']) : null,
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
    );
  }
  
  static TaskPriority _parsePriority(String priority) {
    switch (priority) {
      case 'high': return TaskPriority.high;
      case 'medium': return TaskPriority.medium;
      case 'low': return TaskPriority.low;
      default: return TaskPriority.none;
    }
  }
  
  static TaskEnergy _parseEnergy(String energy) {
    switch (energy) {
      case 'high': return TaskEnergy.high;
      case 'medium': return TaskEnergy.medium;
      case 'low': return TaskEnergy.low;
      default: return TaskEnergy.low;
    }
  }
  
  static TaskState _parseState(String state) {
    switch (state) {
      case 'completed': return TaskState.completed;
      case 'snoozed': return TaskState.snoozed;
      default: return TaskState.pending;
    }
  }
  
  Task copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskEnergy? energy,
    TaskState? state,
    DateTime? lastShown,
    int? avoidanceCount,
    DateTime? hiddenUntil,
    DateTime? interventionShownAt,
    List<String>? tags,
    int? estimatedMinutes,
    String? project,
    bool? isRecurring,
    String? recurrencePattern,
    List<Subtask>? subtasks,
    int? durationSeconds,
    bool? isTimerRunning,
    DateTime? lastTimerStart,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      energy: energy ?? this.energy,
      state: state ?? this.state,
      lastShown: lastShown ?? this.lastShown,
      avoidanceCount: avoidanceCount ?? this.avoidanceCount,
      hiddenUntil: hiddenUntil ?? this.hiddenUntil,
      interventionShownAt: interventionShownAt ?? this.interventionShownAt,
      tags: tags ?? this.tags,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      project: project ?? this.project,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      subtasks: subtasks ?? this.subtasks,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
      lastTimerStart: lastTimerStart ?? this.lastTimerStart,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}