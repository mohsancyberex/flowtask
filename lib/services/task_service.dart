import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

class TaskService extends ChangeNotifier {
  List<Task> _tasks = [];
  Task? _currentTask;
  bool _isLoading = true;
  TaskEnergy _userEnergy = TaskEnergy.medium; // Default user energy
  
  // Behavioral state (private, persisted via SharedPreferences)
  DateTime? _silentUntil; // Professional Silence Mode
  DateTime? _lastInteractionAt;
  String? _lastShownTaskId;
  double _trust = 0.5; // 0..1
  int _consecutiveActionDays = 0; // silent streaks, hidden
  bool _sponsorEnabled = false; // user-chosen ad flag
  int _rapidAddsInWindow = 0;
  DateTime? _rapidWindowStart;
  String? _lastInterventionTaskId;
  
  // Derived user state (not persisted)
  final Random _rng = Random();
  int _consecutiveSkips = 0;
  bool _justCompletedMeaningful = false; // used to trigger sponsor prompt
  
  // Getters
  List<Task> get tasks => _tasks;
  Task? get currentTask => _currentTask;
  bool get isLoading => _isLoading;
  TaskEnergy get userEnergy => _userEnergy;
  bool get sponsorEnabled => _sponsorEnabled;
  DateTime? get silentUntil => _silentUntil;
  
  int get activeTaskCount => _tasks.where((t) => t.state != TaskState.completed).length;

  TaskService() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tasksJson = prefs.getString('flowtask_tasks');
      if (tasksJson != null) {
        final List<dynamic> decoded = json.decode(tasksJson);
        _tasks = decoded.map((item) => Task.fromMap(item)).toList();
      }
      
      // Load user energy preference if saved, or default
      final int? energyIndex = prefs.getInt('flowtask_user_energy');
      if (energyIndex != null) {
        _userEnergy = TaskEnergy.values[energyIndex];
      }

      // Behavioral persistence
      final String? silentUntilIso = prefs.getString('flowtask_silent_until');
      if (silentUntilIso != null) _silentUntil = DateTime.tryParse(silentUntilIso);
      final String? lastInteractionIso = prefs.getString('flowtask_last_interaction');
      if (lastInteractionIso != null) _lastInteractionAt = DateTime.tryParse(lastInteractionIso);
      _lastShownTaskId = prefs.getString('flowtask_last_shown_id');
      _trust = prefs.getDouble('flowtask_trust') ?? 0.5;
      _consecutiveActionDays = prefs.getInt('flowtask_streak_hidden') ?? 0;
      _sponsorEnabled = prefs.getBool('flowtask_sponsor_enabled') ?? false;

      _refreshCurrentTask();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_tasks.map((t) => t.toMap()).toList());
      await prefs.setString('flowtask_tasks', encoded);
      await prefs.setInt('flowtask_user_energy', _userEnergy.index);
      await prefs.setString('flowtask_last_interaction', (_lastInteractionAt ?? DateTime.now()).toIso8601String());
      if (_silentUntil != null) {
        await prefs.setString('flowtask_silent_until', _silentUntil!.toIso8601String());
      } else {
        await prefs.remove('flowtask_silent_until');
      }
      if (_lastShownTaskId != null) await prefs.setString('flowtask_last_shown_id', _lastShownTaskId!);
      await prefs.setDouble('flowtask_trust', _trust);
      await prefs.setInt('flowtask_streak_hidden', _consecutiveActionDays);
      await prefs.setBool('flowtask_sponsor_enabled', _sponsorEnabled);
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  void setUserEnergy(TaskEnergy energy) {
    _userEnergy = energy;
    _saveTasks();
    _refreshCurrentTask();
    notifyListeners();
  }

  void setSponsorEnabled(bool enabled) {
    _sponsorEnabled = enabled;
    _saveTasks();
    notifyListeners();
  }

  // Smart Logic to pick the ONE task
  void _refreshCurrentTask() {
    // If in Professional Silence Mode, keep UI calm (still allow core flow)
    final bool isSilent = _silentUntil != null && DateTime.now().isBefore(_silentUntil!);

    // 1) Filter eligible tasks
    final now = DateTime.now();
    final List<Task> pool = _tasks.where((t) => t.state != TaskState.completed).toList();
    if (pool.isEmpty) {
      _currentTask = null;
      return;
    }

    // Remove tasks by eligibility
    final List<Task> eligible = pool.where((t) {
      // Energy mismatch removal (hard filter): only allow when equal or task.energy lower than user energy
      final energyMismatch = _energyMismatch(t.energy, _userEnergy) > 0;
      final bool energyAllowed = !energyMismatch || t.energy == TaskEnergy.low; // low tasks ok anytime

      // Last shown too recent (cooldown 45 minutes)
      // Allow brand-new tasks (never shown) to surface immediately
      final bool notTooRecent = (t.shownCount == 0) || now.difference(t.lastShown).inMinutes > 45;

      // Hidden window (e.g., snoozed via intervention)
      final bool notHidden = t.hiddenUntil == null || now.isAfter(t.hiddenUntil!);

      // Repeated resistance (3+ skips) are removed unless user has high energy and not silent
      final bool notResisted = t.skips < 3 || (_userEnergy == TaskEnergy.high && !isSilent);

      // Never show the same task twice in a row
      final bool notSameAsLast = t.id != _lastShownTaskId;

      return energyAllowed && notTooRecent && notHidden && notResisted && notSameAsLast;
    }).toList();

    if (eligible.isEmpty) {
      _currentTask = null; // Nothing Mode
      return;
    }

    // 2) Score by friction (lower is easier)
    final scored = eligible
        .map((t) => MapEntry(t, _friction(t)))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Occasionally surface medium friction to avoid stagnation (20% chance)
    Task selected = scored.first.key;
    if (scored.length > 2) {
      final mediumIndex = min(2, scored.length - 1);
      final double bestF = scored.first.value;
      final double medF = scored[mediumIndex].value;
      final bool hasMedium = medF < (bestF + 0.5) && medF > (bestF + 0.15);
      if (hasMedium && _rng.nextDouble() < 0.2) {
        selected = scored[mediumIndex].key;
      }
    }

    // If all high friction (>1.2) show Nothing Mode
    if (scored.isNotEmpty && scored.first.value > 1.2) {
      _currentTask = null;
      return;
    }

    // Promote selected to 'now' and increment shown
    _promoteToNow(selected);
  }

  // Friction score per spec (lower is easier)
  double _friction(Task t) {
    final ageDays = max(0, DateTime.now().difference(t.createdAt).inDays);
    final energyMismatch = _energyMismatch(t.energy, _userEnergy);
    final base = (t.skips * 0.4) + (ageDays * 0.2) + (t.shownCount * 0.2) + (energyMismatch * 0.5) + (t.emotionalResistance * 0.6);
    // Task gravity reduces friction (floats up)
    final gravityBonus = max(0, 0.3 * t.gravity);
    // Small trust-based easing on good streaks
    final trustEasing = (_trust - 0.5) * 0.2;
    return max(0, base - gravityBonus - trustEasing);
  }

  int _energyMismatch(TaskEnergy taskEnergy, TaskEnergy userEnergy) {
    if (taskEnergy == userEnergy) return 0;
    if (taskEnergy == TaskEnergy.low && userEnergy == TaskEnergy.high) return 0; // ok
    if (taskEnergy == TaskEnergy.medium && userEnergy == TaskEnergy.high) return 0; // ok
    return 1;
  }

  void _promoteToNow(Task task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      final updated = _tasks[index].copyWith(
        state: TaskState.now,
        shownCount: _tasks[index].shownCount + 1,
        lastShown: DateTime.now(),
      );
      _tasks[index] = updated;
      _currentTask = updated;
      _lastShownTaskId = updated.id;
      _saveTasks();
    } else {
      _currentTask = task; // fallback
    }
  }

  // Actions

  Future<void> addTask(String text, {List<String> context = const [], TaskEnergy energy = TaskEnergy.medium, DateTime? hiddenUntil}) async {
    if (activeTaskCount >= 7) {
       debugPrint('Decision fatigue protection: max 7 active tasks.');
       return;
    }

    // Decision fatigue: rate-limit rapid adds
    final now = DateTime.now();
    if (_rapidWindowStart == null || now.difference(_rapidWindowStart!).inSeconds > 60) {
      _rapidWindowStart = now;
      _rapidAddsInWindow = 0;
    }
    _rapidAddsInWindow++;

    final newTask = Task(
      id: const Uuid().v4(),
      text: text,
      createdAt: DateTime.now(),
      lastShown: DateTime.now(),
      context: context,
      energy: energy,
      state: TaskState.next, // Start in queue
      hiddenUntil: hiddenUntil,
    );

    _tasks.add(newTask);
    _saveTasks();
    // Always refresh selection so new task can surface immediately
    _refreshCurrentTask();
    notifyListeners();
  }

  Future<void> completeTask() async {
    if (_currentTask == null) return;
    
    // Mark as completed
    final id = _currentTask!.id;
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      // Learning: completing reduces emotional resistance, increases gravity, may mark safe win
      final t = _tasks[idx];
      final timeSinceShown = DateTime.now().difference(t.lastShown).inMinutes;
      final double easeDelta = timeSinceShown <= 10 ? 0.15 : 0.08;
      final bool safe = timeSinceShown <= 10 && _friction(t) < 0.8;
      final updated = t.copyWith(
        state: TaskState.completed,
        completeCount: t.completeCount + 1,
        emotionalResistance: (t.emotionalResistance - easeDelta).clamp(0.0, 1.0),
        gravity: (t.gravity + 0.1).clamp(0.0, 1.0),
        safeWin: t.safeWin || safe,
      );
      _tasks[idx] = updated;
    }
    _justCompletedMeaningful = true;
    _consecutiveSkips = 0; // reset
    _bumpTrust(0.03);
    _touchInteraction();
    
    // Find next
    _refreshCurrentTask();
    notifyListeners();
  }

  Future<void> skipTask() async {
    if (_currentTask == null) return;

    final task = _currentTask!;
    final newSkips = task.skips + 1;
    
    // Update task
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task.copyWith(
        skips: newSkips,
        state: TaskState.later, // Move to back of line
        lastShown: DateTime.now(),
        emotionalResistance: (task.emotionalResistance + 0.08).clamp(0.0, 1.0),
        gravity: (task.gravity - 0.05).clamp(0.0, 1.0),
      );
    }
    
    _saveTasks();
    _consecutiveSkips++;
    if (_consecutiveSkips >= 5) {
      _enterSilence();
    }
    _bumpTrust(-0.02);
    _touchInteraction();
    _refreshCurrentTask();
    notifyListeners();
  }

  Future<void> snoozeTask() async {
    // Like skip but explicit "Later" intention
    await skipTask(); 
  }

  void _updateTaskState(String id, TaskState newState) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(state: newState);
      _saveTasks();
    }
  }

  Future<void> completeTaskById(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = _tasks[idx];
    final updated = t.copyWith(
      state: TaskState.completed,
      completeCount: t.completeCount + 1,
      emotionalResistance: (t.emotionalResistance - 0.08).clamp(0.0, 1.0),
      gravity: (t.gravity + 0.1).clamp(0.0, 1.0),
      lastShown: DateTime.now(),
    );
    _tasks[idx] = updated;
    _justCompletedMeaningful = true;
    _consecutiveSkips = 0;
    _bumpTrust(0.02);
    _touchInteraction();
    await _saveTasks();
    _refreshCurrentTask();
    notifyListeners();
  }

  Future<void> snoozeTaskById(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = _tasks[idx];
    _tasks[idx] = t.copyWith(
      state: TaskState.later,
      lastShown: DateTime.now(),
      emotionalResistance: (t.emotionalResistance + 0.05).clamp(0.0, 1.0),
      gravity: (t.gravity - 0.03).clamp(0.0, 1.0),
    );
    await _saveTasks();
    _refreshCurrentTask();
    notifyListeners();
  }
  
  Future<void> hideTask(String id, Duration duration) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(
        state: TaskState.later,
        hiddenUntil: DateTime.now().add(duration),
      );
      await _saveTasks();
      _refreshCurrentTask();
      notifyListeners();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _saveTasks();
    _refreshCurrentTask();
    notifyListeners();
  }

  Future<void> updateTaskText(String id, String newText) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(text: newText);
      await _saveTasks();
      notifyListeners();
    }
  }
  
  void _enterSilence() {
    _silentUntil = DateTime.now().add(const Duration(hours: 24));
    debugPrint('Entering Professional Silence Mode until: $_silentUntil');
    _saveTasks();
  }

  void _touchInteraction() {
    _lastInteractionAt = DateTime.now();
  }

  void _bumpTrust(double delta) {
    _trust = (_trust + delta).clamp(0.0, 1.0);
  }
  
  bool get shouldShowSponsorCard {
    if (!_sponsorEnabled) return false;
    if (_silentUntil != null && DateTime.now().isBefore(_silentUntil!)) return false;
    if (!_justCompletedMeaningful) return false;
    // require recent low skip mood
    final lowSkipMood = _consecutiveSkips == 0;
    final confident = _trust > 0.55;
    return lowSkipMood && confident;
  }

  void onSponsorShown() {
    _justCompletedMeaningful = false;
  }
  
  bool needsIntervention(Task t) {
    final ageDays = DateTime.now().difference(t.createdAt).inDays;
    final neverCompleted = t.completeCount == 0;
    if (_lastInterventionTaskId == t.id) return false;
    return t.skips >= 3 && ageDays >= 7 && neverCompleted;
  }

  void markInterventionShown(String id) {
    _lastInterventionTaskId = id;
  }

  void completeRecoveryNudge() {
    _bumpTrust(0.01);
    _touchInteraction();
    notifyListeners();
  }
  
  // For debugging/reset
  Future<void> clearAll() async {
    _tasks.clear();
    _currentTask = null;
    _silentUntil = null;
    _lastInteractionAt = null;
    _lastShownTaskId = null;
    _trust = 0.5;
    _consecutiveActionDays = 0;
    _consecutiveSkips = 0;
    _sponsorEnabled = false;
    await _saveTasks();
    notifyListeners();
  }
}
