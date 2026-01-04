import 'dart:convert';

enum TaskEnergy {
  high,
  medium,
  low,
}

enum TaskState {
  now,
  next,
  later,
  completed, // For tracking history if needed, though app hides them
}

class Task {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime lastShown;
  final int skips; // historical skip count (aka skip_count)
  final List<String> context;
  final TaskEnergy energy;
  final TaskState state;
  
  // Advanced behavioral metrics (invisible to user)
  final int shownCount; // times surfaced
  final int completeCount; // times completed (usually 0/1)
  final double emotionalResistance; // 0..1 higher = harder emotionally
  final double gravity; // 0..1 higher floats earlier
  final bool safeWin; // marked when completed easily
  final DateTime? hiddenUntil; // e.g., hide for 7 days

  Task({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.lastShown,
    this.skips = 0,
    this.context = const [],
    this.energy = TaskEnergy.medium,
    this.state = TaskState.next,
    this.shownCount = 0,
    this.completeCount = 0,
    this.emotionalResistance = 0.2,
    this.gravity = 0.5,
    this.safeWin = false,
    this.hiddenUntil,
  });

  Task copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? lastShown,
    int? skips,
    List<String>? context,
    TaskEnergy? energy,
    TaskState? state,
    int? shownCount,
    int? completeCount,
    double? emotionalResistance,
    double? gravity,
    bool? safeWin,
    DateTime? hiddenUntil,
  }) {
    return Task(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      lastShown: lastShown ?? this.lastShown,
      skips: skips ?? this.skips,
      context: context ?? this.context,
      energy: energy ?? this.energy,
      state: state ?? this.state,
      shownCount: shownCount ?? this.shownCount,
      completeCount: completeCount ?? this.completeCount,
      emotionalResistance: emotionalResistance ?? this.emotionalResistance,
      gravity: gravity ?? this.gravity,
      safeWin: safeWin ?? this.safeWin,
      hiddenUntil: hiddenUntil ?? this.hiddenUntil,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'lastShown': lastShown.toIso8601String(),
      'skips': skips,
      'context': context,
      'energy': energy.index,
      'state': state.index,
      'shownCount': shownCount,
      'completeCount': completeCount,
      'emotionalResistance': emotionalResistance,
      'gravity': gravity,
      'safeWin': safeWin,
      'hiddenUntil': hiddenUntil?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
      lastShown: DateTime.parse(map['lastShown']),
      skips: map['skips'] ?? 0,
      context: List<String>.from(map['context'] ?? []),
      energy: TaskEnergy.values[map['energy'] ?? 1],
      state: TaskState.values[map['state'] ?? 1],
      shownCount: map['shownCount'] ?? 0,
      completeCount: map['completeCount'] ?? 0,
      emotionalResistance: (map['emotionalResistance'] is int)
          ? (map['emotionalResistance'] as int).toDouble()
          : (map['emotionalResistance'] ?? 0.2),
      gravity: (map['gravity'] is int)
          ? (map['gravity'] as int).toDouble()
          : (map['gravity'] ?? 0.5),
      safeWin: map['safeWin'] ?? false,
      hiddenUntil: map['hiddenUntil'] != null ? DateTime.tryParse(map['hiddenUntil']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));

  // Logic for aging
  String get ageStatus {
    final now = DateTime.now();
    final difference = now.difference(createdAt).inDays;
    if (difference < 2) return 'Fresh 🌱';
    if (difference < 7) return 'Warm 🔥';
    return 'Old 🪨';
  }
}
