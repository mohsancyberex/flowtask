import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskService with ChangeNotifier {
  List<Task> _tasks = [];
  Task? _currentTask;
  TaskEnergy _userEnergy = TaskEnergy.medium;
  bool _isLoading = false;
  List<String> _completedToday = [];
  bool _showMotivationalQuote = true;
  bool _sponsorEnabled = false;
  DateTime? _silentUntil;
  Timer? _globalTimer;
  
  // Pomodoro State
  int _pomodoroSeconds = 25 * 60;
  bool _isPomodoroRunning = false;
  bool _isPomodoroWorkMode = true;

  int get pomodoroSeconds => _pomodoroSeconds;
  bool get isPomodoroRunning => _isPomodoroRunning;
  bool get isPomodoroWorkMode => _isPomodoroWorkMode;
  
  List<Task> get tasks => _tasks;
  Task? get currentTask => _currentTask;
  TaskEnergy get userEnergy => _userEnergy;
  bool get isLoading => _isLoading;
  bool get showMotivationalQuote => _showMotivationalQuote;
  bool get sponsorEnabled => _sponsorEnabled;
  DateTime? get silentUntil => _silentUntil;
  
  int get activeTaskCount => _tasks.where((t) => t.state == TaskState.pending).length;
  int get completedToday => _completedToday.length;
  int get highPriorityCount => _tasks.where((t) => t.priority == TaskPriority.high && t.state != TaskState.completed).length;
  
  final SharedPreferences _prefs;
  
  TaskService(this._prefs) {
    _loadTasks();
    _loadSettings();
    _startGlobalTimer();
  }
  
  void _startGlobalTimer() {
    _globalTimer?.cancel();
    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool changed = false;
      
      // Pomodoro Logic
      if (_isPomodoroRunning && _pomodoroSeconds > 0) {
        _pomodoroSeconds--;
        changed = true;
        if (_pomodoroSeconds == 0) {
          _isPomodoroRunning = false;
          _handlePomodoroEnd();
        }
      }

      // Task Timer Logic
      for (int i = 0; i < _tasks.length; i++) {
        if (_tasks[i].isTimerRunning && _tasks[i].lastTimerStart != null) {
          final now = DateTime.now();
          final diff = now.difference(_tasks[i].lastTimerStart!).inSeconds;
          if (diff > 0) {
            _tasks[i] = _tasks[i].copyWith(
              durationSeconds: _tasks[i].durationSeconds + diff,
              lastTimerStart: now,
            );
            changed = true;
          }
        }
      }
      if (changed) {
        notifyListeners();
      }
    });
  }

  void _handlePomodoroEnd() {
    // Toggle mode and reset time
    _isPomodoroWorkMode = !_isPomodoroWorkMode;
    _pomodoroSeconds = (_isPomodoroWorkMode ? 25 : 5) * 60;
    notifyListeners();
  }

  void startPomodoro() {
    _isPomodoroRunning = true;
    notifyListeners();
  }

  void pausePomodoro() {
    _isPomodoroRunning = false;
    notifyListeners();
  }

  void resetPomodoro() {
    _isPomodoroRunning = false;
    _pomodoroSeconds = (_isPomodoroWorkMode ? 25 : 5) * 60;
    notifyListeners();
  }

  void togglePomodoroMode() {
    _isPomodoroWorkMode = !_isPomodoroWorkMode;
    resetPomodoro();
  }

  @override
  void dispose() {
    _globalTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadTasks() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final tasksJson = _prefs.getStringList('tasks') ?? [];
      _tasks = tasksJson.map((json) {
        try {
          final map = jsonDecode(json);
          return Task.fromMap(map);
        } catch (e) {
          return Task(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            text: 'Sample task',
            createdAt: DateTime.now(),
          );
        }
      }).toList();
      
      _currentTask = _getNextTask();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading tasks: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> _saveTasks() async {
    try {
      final tasksJson = _tasks.map((task) => jsonEncode(task.toMap())).toList();
      await _prefs.setStringList('tasks', tasksJson);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving tasks: $e');
      }
    }
  }
  
  Future<void> _loadSettings() async {
    final energyIndex = _prefs.getInt('userEnergy') ?? 1;
    _userEnergy = TaskEnergy.values[energyIndex];
    _showMotivationalQuote = _prefs.getBool('showMotivationalQuote') ?? true;
    _sponsorEnabled = _prefs.getBool('sponsorEnabled') ?? false;
    final silentUntilStr = _prefs.getString('silentUntil');
    if (silentUntilStr != null) {
      _silentUntil = DateTime.tryParse(silentUntilStr);
    }
  }
  
  Task? _getNextTask() {
    if (_tasks.isEmpty) return null;
    
    var filteredTasks = _tasks.where((task) {
      if (task.state == TaskState.completed) return false;
      if (task.hiddenUntil != null && DateTime.now().isBefore(task.hiddenUntil!)) return false;
      return true;
    }).toList();
    
    if (filteredTasks.isEmpty) return null;
    
    filteredTasks.sort((a, b) {
      final aEnergyMatch = a.energy == _userEnergy ? 2 : (a.energy?.index == _userEnergy.index ? 1 : 0);
      final bEnergyMatch = b.energy == _userEnergy ? 2 : (b.energy?.index == _userEnergy.index ? 1 : 0);
      
      if (aEnergyMatch != bEnergyMatch) {
        return bEnergyMatch.compareTo(aEnergyMatch);
      }
      
      if (a.priority != b.priority) {
        final priorityOrder = {TaskPriority.high: 3, TaskPriority.medium: 2, TaskPriority.low: 1, TaskPriority.none: 0};
        return priorityOrder[b.priority]!.compareTo(priorityOrder[a.priority]!);
      }
      
      return a.createdAt.compareTo(b.createdAt);
    });
    
    return filteredTasks.first;
  }
  
  Future<void> addTask(
    String text, {
    TaskEnergy energy = TaskEnergy.medium,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    int? estimatedMinutes,
    List<String>? tags,
    String? project,
    DateTime? hiddenUntil,
    List<String>? context, // Mapped to tags for now
    bool isRecurring = false,
    String? recurrencePattern,
    List<String>? initialSubtasks,
  }) async {
    // Merge context into tags if provided
    final finalTags = [...?tags, ...?context];
    
    final task = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      createdAt: DateTime.now(),
      energy: energy,
      priority: priority,
      dueDate: dueDate,
      estimatedMinutes: estimatedMinutes,
      tags: finalTags.isNotEmpty ? finalTags : null,
      project: project,
      hiddenUntil: hiddenUntil,
      isRecurring: isRecurring,
      recurrencePattern: recurrencePattern,
      subtasks: initialSubtasks?.map((s) => Subtask(
        id: DateTime.now().microsecondsSinceEpoch.toString() + s.hashCode.toString(),
        text: s,
      )).toList() ?? [],
    );
    
    _tasks.add(task);
    await _saveTasks();
    
    if (_currentTask == null) {
      _currentTask = task;
    }
    
    notifyListeners();
  }
  
  // REMOVED: Old completeTask() method without parameters
  
  // REMOVED: Old snoozeTask() method without parameters
  
  // REMOVED: Old skipTask() method without parameters
  
  // NEW: Complete a specific task
  Future<void> completeTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    
    var updatedTask = _tasks[index].copyWith(
      state: TaskState.completed,
      isTimerRunning: false,
      completedAt: DateTime.now(), // Store completion time for stats
    );
    _tasks[index] = updatedTask;
    
    // Handle Recurrence
    if (updatedTask.isRecurring) {
      _handleRecurrence(updatedTask);
    }
    
    final today = DateTime.now().toIso8601String().split('T')[0];
    _completedToday.add(task.id);
    await _prefs.setStringList('completed_$today', _completedToday);
    
    await _saveTasks();
    
    // Update current task if the completed one was current
    if (_currentTask?.id == task.id) {
      _currentTask = _getNextTask();
    }
    
    notifyListeners();
  }

  void _handleRecurrence(Task task) {
    if (task.recurrencePattern == null) return;

    DateTime? nextDate;
    final now = task.dueDate ?? DateTime.now();

    switch (task.recurrencePattern) {
      case 'daily':
        nextDate = now.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextDate = now.add(const Duration(days: 7));
        break;
      case 'monthly':
        nextDate = DateTime(now.year, now.month + 1, now.day);
        break;
    }

    if (nextDate != null) {
      final newTask = Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: task.text,
        createdAt: DateTime.now(),
        dueDate: nextDate,
        priority: task.priority,
        energy: task.energy,
        project: task.project,
        tags: task.tags,
        isRecurring: true,
        recurrencePattern: task.recurrencePattern,
        subtasks: task.subtasks.map((s) => Subtask(id: '${DateTime.now().microsecondsSinceEpoch}_${s.id}', text: s.text)).toList(),
      );
      _tasks.add(newTask);
    }
  }

  Future<void> startTaskTimer(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    // Stop other running timers? Usually only one task at a time.
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].isTimerRunning) {
        _tasks[i] = _tasks[i].copyWith(isTimerRunning: false, lastTimerStart: null);
      }
    }

    _tasks[index] = _tasks[index].copyWith(
      isTimerRunning: true,
      lastTimerStart: DateTime.now(),
    );
    notifyListeners();
    await _saveTasks();
  }

  Future<void> stopTaskTimer(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _tasks[index] = _tasks[index].copyWith(
      isTimerRunning: false,
      lastTimerStart: null,
    );
    notifyListeners();
    await _saveTasks();
  }

  Future<void> addSubtask(String taskId, String text) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final subtask = Subtask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
    );

    final updatedSubtasks = List<Subtask>.from(_tasks[index].subtasks)..add(subtask);
    _tasks[index] = _tasks[index].copyWith(subtasks: updatedSubtasks);
    
    notifyListeners();
    await _saveTasks();
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final subtaskIndex = _tasks[index].subtasks.indexWhere((s) => s.id == subtaskId);
    if (subtaskIndex == -1) return;

    final subtasks = List<Subtask>.from(_tasks[index].subtasks);
    subtasks[subtaskIndex] = Subtask(
      id: subtasks[subtaskIndex].id,
      text: subtasks[subtaskIndex].text,
      isDone: !subtasks[subtaskIndex].isDone,
    );

    _tasks[index] = _tasks[index].copyWith(subtasks: subtasks);
    
    notifyListeners();
    await _saveTasks();
  }
  
  // NEW: Complete the current task (for backward compatibility)
  Future<void> completeCurrentTask() async {
    if (_currentTask == null) return;
    await completeTask(_currentTask!);
  }
  
  // NEW: Snooze a specific task
  Future<void> snoozeTask(Task task, {DateTime? until}) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    
    var updatedTask = _tasks[index];
    final snoozeUntil = until ?? DateTime.now().add(const Duration(hours: 2));
    
    updatedTask = updatedTask.copyWith(
      state: TaskState.snoozed,
      hiddenUntil: snoozeUntil,
      lastShown: DateTime.now(),
      avoidanceCount: updatedTask.avoidanceCount + 1,
      isTimerRunning: false,
    );
    _tasks[index] = updatedTask;
    
    await _saveTasks();
    
    // Update current task if the snoozed one was current
    if (_currentTask?.id == task.id) {
      _currentTask = _getNextTask();
    }
    
    notifyListeners();
  }
  
  // NEW: Skip a specific task
  Future<void> skipTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) return;
    
    var updatedTask = _tasks[index].copyWith(
      avoidanceCount: task.avoidanceCount + 1,
      lastShown: DateTime.now(),
    );
    _tasks[index] = updatedTask;
    
    await _saveTasks();
    
    // Update current task if the skipped one was current
    if (_currentTask?.id == task.id) {
      _currentTask = _getNextTask();
    }
    
    notifyListeners();
  }
  
  Future<void> updateTaskText(String taskId, String newText) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    
    final task = _tasks[index];
    _tasks[index] = task.copyWith(text: newText);
    
    await _saveTasks();
    notifyListeners();
  }
  
  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveTasks();
    
    if (_currentTask?.id == taskId) {
      _currentTask = _getNextTask();
    }
    notifyListeners();
  }
  
  Future<void> hideTask(String taskId, Duration duration) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    
    final task = _tasks[index];
    final hiddenUntil = DateTime.now().add(duration);
    
    _tasks[index] = task.copyWith(
      hiddenUntil: hiddenUntil,
      interventionShownAt: DateTime.now(),
    );
    
    await _saveTasks();
    if (_currentTask?.id == taskId) {
      _currentTask = _getNextTask();
    }
    notifyListeners();
  }
  
  void setUserEnergy(TaskEnergy energy) {
    _userEnergy = energy;
    _prefs.setInt('userEnergy', energy.index);
    _currentTask = _getNextTask();
    notifyListeners();
  }
  
  void completeRecoveryNudge() {
    notifyListeners();
  }
  
  void toggleMotivationalQuote(bool show) {
    _showMotivationalQuote = show;
    _prefs.setBool('showMotivationalQuote', show);
    notifyListeners();
  }
  
  String getDailyQuote() {
    final quotes = [
      "The secret of getting ahead is getting started.",
      "Don't watch the clock; do what it does. Keep going.",
      "The only way to do great work is to love what you do.",
      "It always seems impossible until it's done.",
      "Your future is created by what you do today, not tomorrow.",
    ];
    
    final random = Random();
    return quotes[random.nextInt(quotes.length)];
  }
  
  // REMOVE or comment out this method for production
  void addSampleTasks() {
    // Comment out for production
    /*
    addTask('Review project proposal', energy: TaskEnergy.high, priority: TaskPriority.high);
    addTask('Email team about meeting', energy: TaskEnergy.medium, priority: TaskPriority.medium);
    addTask('Organize desk', energy: TaskEnergy.low, priority: TaskPriority.low, tags: ['home']);
    addTask('Plan next week', priority: TaskPriority.medium, estimatedMinutes: 30);
    addTask('Learn new Flutter feature', energy: TaskEnergy.high, tags: ['learning', 'work']);
    notifyListeners();
    */
  }
  
  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.state == TaskState.completed);
    await _saveTasks();
    _currentTask = _getNextTask();
    notifyListeners();
  }

  void setSponsorEnabled(bool enabled) {
    _sponsorEnabled = enabled;
    _prefs.setBool('sponsorEnabled', enabled);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _tasks.clear();
    await _prefs.remove('tasks');
    _currentTask = null;
    notifyListeners();
  }

  // ========== STATISTICS LOGIC ==========

  Map<DateTime, int> getWeeklyStats() {
    final stats = <DateTime, int>{};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      stats[date] = 0;
    }

    for (final task in _tasks) {
      if (task.state == TaskState.completed && task.completedAt != null) {
        final date = DateTime(task.completedAt!.year, task.completedAt!.month, task.completedAt!.day);
        if (stats.containsKey(date)) {
          stats[date] = stats[date]! + 1;
        }
      }
    }
    return stats;
  }

  Map<String, int> getProjectStats() {
    final stats = <String, int>{};
    for (final task in _tasks) {
      final projectName = task.project ?? 'Inbox';
      stats[projectName] = (stats[projectName] ?? 0) + (task.state == TaskState.completed ? 1 : 0);
    }
    return stats;
  }

  Map<String, double> getProjectProgress() {
    final projectTasks = <String, List<Task>>{};
    for (final task in _tasks) {
      final p = task.project ?? 'Inbox';
      projectTasks[p] ??= [];
      projectTasks[p]!.add(task);
    }
    
    return projectTasks.map((name, tasks) {
      final done = tasks.where((t) => t.state == TaskState.completed).length;
      return MapEntry(name, done / tasks.length);
    });
  }

  int getTotalSecondsThisWeek() {
    int total = 0;
    for (final task in _tasks) {
      total += task.durationSeconds;
    }
    return total;
  }
}