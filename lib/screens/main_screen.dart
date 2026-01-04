import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/task.dart';
import '../services/task_service.dart';
import '../components/ad_banner.dart';
import '../utils/date_parser.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  late ConfettiController _confettiController;
  bool _showCompletionAnimation = false;
  bool _isFocusMode = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          if (!_isFocusMode)
            SafeArea(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildTodayView(context, taskService),
                  _buildUpcomingView(context, taskService),
                  _buildProjectsView(context, taskService),
                  _buildSearchView(context, taskService),
                  _buildProfileView(context, taskService),
                ],
              ),
            ),
          
          if (_isFocusMode)
            _FocusOverlay(
              onExit: () => setState(() => _isFocusMode = false),
            ),

          // Confetti (overlay on top of content)
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -pi / 2,
            emissionFrequency: 0.01,
            numberOfParticles: 20,
            gravity: 0.1,
          ),

          // Completion Animation (overlay on top of content)
          if (_showCompletionAnimation)
            Positioned.fill(
              child: Container(
                color: Colors.green.withOpacity(0.1),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isFocusMode ? null : Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.4),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.today_rounded), label: 'Today'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Upcoming'),
            BottomNavigationBarItem(icon: Icon(Icons.folder_shared_rounded), label: 'Projects'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
      floatingActionButton: (_isFocusMode || _currentIndex != 0)
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddTaskDialog(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTodayView(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Text(
              'What matters Now',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(context, taskService),
            const SizedBox(height: 16),
            _buildTaskStats(context, taskService),
            const SizedBox(height: 40),
            _buildTaskSection(context, taskService),
            const SizedBox(height: 24),
            const AdBanner(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search tasks...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) {
                      setState(() => _currentIndex = 3);
                      // TODO: Implement search logic
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _EnergyBadge(energy: Provider.of<TaskService>(context).userEnergy),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.center_focus_strong_rounded, 
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          onPressed: () => setState(() => _isFocusMode = true),
          tooltip: 'Focus Mode',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showSettings(context),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSection(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (taskService.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (taskService.currentTask == null)
          _EmptyState(hasTasks: taskService.tasks.isNotEmpty)
        else
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showTaskOptions(context, taskService);
            },
            onDoubleTap: () => _showEditTaskDialog(context, taskService.currentTask!),
            child: Dismissible(
              key: ValueKey('dismiss-${taskService.currentTask!.id}'),
              direction: DismissDirection.horizontal,
              background: Container(
                color: Colors.green.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Done',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              secondaryBackground: Container(
                color: Colors.orange.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Later',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.snooze_rounded, color: Colors.orange),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  HapticFeedback.lightImpact();
                  setState(() => _showCompletionAnimation = true);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await taskService.completeTask(taskService.currentTask!);
                  _confettiController.play();
                  setState(() => _showCompletionAnimation = false);
                } else if (direction == DismissDirection.endToStart) {
                  HapticFeedback.lightImpact();
                  final result = await _showScheduleDialog(context, taskService.currentTask!);
                  return result ?? false;
                }
                return true;
              },
              child: _TaskCard(
                key: ValueKey(taskService.currentTask!.id),
                task: taskService.currentTask!,
                onDone: () async {
                  HapticFeedback.lightImpact();
                  setState(() => _showCompletionAnimation = true);
                  await Future.delayed(const Duration(milliseconds: 300));
                  await taskService.completeTask(taskService.currentTask!);
                  _confettiController.play();
                  setState(() => _showCompletionAnimation = false);
                },
                onSkip: () async {
                  HapticFeedback.lightImpact();
                  await taskService.skipTask(taskService.currentTask!);
                },
                onLater: () async {
                  HapticFeedback.lightImpact();
                  await _showScheduleDialog(context, taskService.currentTask!);
                },
              ),
            ),
          ),
        const SizedBox(height: 24),
        Center(child: Text('Swipe → Done / Later', style: theme.textTheme.labelSmall)),
        const SizedBox(height: 32),
        // Remaining summary and Add
        Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => _showRemaining(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text('Remaining (${taskService.activeTaskCount})',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
              ),
            ),
            TextButton(
              onPressed: () => _showAddTaskDialog(context),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 4),
                  Text('Add task'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark 
        ? Colors.grey[400]! 
        : Colors.grey[600]!;
  }

  // ========== WIDGET BUILDERS ==========

  Widget _buildProgressBar(BuildContext context, TaskService service) {
  final total = service.tasks.length;
  final completed = service.tasks.where((t) => t.state == TaskState.completed).length;
  final progress = total > 0 ? completed / total : 0;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${(progress * 100).round()}% Complete',
            style: TextStyle(
              color: _getSecondaryTextColor(context),
            ),
          ),
          Text(
            '$completed/$total',
            style: TextStyle(
              color: _getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: progress.toDouble(),
        backgroundColor: isDarkMode ? Colors.grey[800] : const Color.fromARGB(255, 235, 217, 217),
        color: Theme.of(context).primaryColor,
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
    ],
  );
}

  Widget _buildTaskStats(BuildContext context, TaskService service) {
  final completed = service.completedToday;
  final pending = service.activeTaskCount;
  final highPriority = service.highPriorityCount;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
      ),
      boxShadow: isDarkMode
          ? []
          : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: 'Done', value: '$completed', color: Colors.green),
        _StatItem(label: 'Pending', value: '$pending', color: Colors.blue),
        _StatItem(label: 'High', value: '$highPriority', color: Colors.red),
      ],
    ),
  );
}

  // ========== DIALOGS & SHEETS ==========

  void _showSettings(BuildContext context) {
  final taskService = Provider.of<TaskService>(context, listen: false);
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    builder: (_) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
      
          // SwitchListTile(
          //   title: const Text('Dark Mode'),
          //   value: isDarkMode,
          //   onChanged: (value) {
              
          //     Navigator.pop(context);
          //   },
          // ),
          SwitchListTile(
            title: const Text('Show Motivational Quotes'),
            value: taskService.showMotivationalQuote,
            onChanged: (value) => taskService.toggleMotivationalQuote(value),
          ),
          ListTile(
            title: const Text('Energy Level'),
            subtitle: Text(_getEnergyText(taskService.userEnergy)),
            onTap: () => _showEnergySelector(context),
          ),       
          ListTile(
            title: const Text('Clear Completed Tasks'),
            textColor: Colors.red,
            onTap: () {
              taskService.clearCompleted();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleared completed tasks')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

  void _showEnergySelector(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('⚡'),
              title: const Text('High Energy'),
              subtitle: const Text('Ready to crush difficult tasks'),
              onTap: () {
                taskService.setUserEnergy(TaskEnergy.high);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🔋'),
              title: const Text('Medium Energy'),
              subtitle: const Text('Steady flow state'),
              onTap: () {
                taskService.setUserEnergy(TaskEnergy.medium);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('💤'),
              title: const Text('Low Energy'),
              subtitle: const Text('Need easy wins'),
              onTap: () {
                taskService.setUserEnergy(TaskEnergy.low);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final textController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.none;
    TaskEnergy selectedEnergy = TaskEnergy.medium;
    DateTime? selectedDate;
    int? estimatedMinutes;
    final List<String> selectedTags = [];
    final List<String> subtasks = [];
    bool isRecurring = false;
    String? recurrencePattern = 'daily';
    
    final tagController = TextEditingController();
    final projectController = TextEditingController();
    final subtaskController = TextEditingController();
    final dateInputController = TextEditingController();

    final suggestedTags = ['work', 'personal', 'urgent', 'home', 'health', 'learning'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Task'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: textController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'What needs to be done?',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Project/Category
                      TextField(
                        controller: projectController,
                        decoration: const InputDecoration(
                          labelText: 'Project/Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder_open),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Estimated Time
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimated minutes (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            estimatedMinutes = int.tryParse(value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tags:'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final tag in selectedTags)
                                Chip(
                                  label: Text('#$tag'),
                                  onDeleted: () {
                                    setState(() => selectedTags.remove(tag));
                                  },
                                ),
                              ActionChip(
                                label: const Text('+ Add Tag'),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (tagContext) => AlertDialog(
                                      title: const Text('Add Tag'),
                                      content: TextField(
                                        controller: tagController,
                                        autofocus: true,
                                        decoration: const InputDecoration(hintText: 'Enter tag'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(tagContext),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (tagController.text.trim().isNotEmpty) {
                                              setState(() => selectedTags.add(tagController.text.trim()));
                                              tagController.clear();
                                              Navigator.pop(tagContext);
                                            }
                                          },
                                          child: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quick tags:',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Wrap(
                            spacing: 4,
                            children: suggestedTags.map((tag) {
                              return FilterChip(
                                label: Text(tag),
                                selected: selectedTags.contains(tag),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedTags.add(tag);
                                    } else {
                                      selectedTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Priority Selection
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Priority'),
                          const SizedBox(height: 8),
                          SegmentedButton<TaskPriority>(
                            segments: const [
                              ButtonSegment(value: TaskPriority.none, label: Text('None')),
                              ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                              ButtonSegment(value: TaskPriority.medium, label: Text('Medium')),
                              ButtonSegment(value: TaskPriority.high, label: Text('High')),
                            ],
                            selected: {selectedPriority},
                            onSelectionChanged: (Set<TaskPriority> newSelection) {
                              setState(() => selectedPriority = newSelection.first);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Energy Level
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Energy Required'),
                          const SizedBox(height: 8),
                          SegmentedButton<TaskEnergy>(
                            segments: const [
                              ButtonSegment(value: TaskEnergy.low, label: Text('Low')),
                              ButtonSegment(value: TaskEnergy.medium, label: Text('Medium')),
                              ButtonSegment(value: TaskEnergy.high, label: Text('High')),
                            ],
                            selected: {selectedEnergy},
                            onSelectionChanged: (Set<TaskEnergy> newSelection) {
                              setState(() => selectedEnergy = newSelection.first);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Due Date & Natural Language
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due Date / Schedule'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                               Expanded(
                                 child: TextField(
                                   controller: dateInputController,
                                   decoration: const InputDecoration(
                                     hintText: 'e.g. "tomorrow", "next Monday"',
                                     prefixIcon: Icon(Icons.auto_awesome),
                                     isDense: true,
                                   ),
                                   onChanged: (val) {
                                     final parsed = DateParser.parse(val);
                                     if (parsed != null) {
                                       setState(() => selectedDate = parsed);
                                     }
                                   },
                                 ),
                               ),
                               const SizedBox(width: 8),
                               IconButton.filledTonal(
                                 icon: const Icon(Icons.calendar_month),
                                 onPressed: () async {
                                   final date = await showDatePicker(
                                     context: context,
                                     initialDate: DateTime.now(),
                                     firstDate: DateTime.now(),
                                     lastDate: DateTime.now().add(const Duration(days: 365)),
                                   );
                                   if (date != null) {
                                     setState(() {
                                       selectedDate = date;
                                       dateInputController.text = _formatDate(date);
                                     });
                                   }
                                 },
                               ),
                            ],
                          ),
                          if (selectedDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Selected: ${_formatDate(selectedDate!)}', 
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recurring Tasks
                      SwitchListTile(
                        title: const Text('Recurring Task'),
                        subtitle: const Text('Auto-create on completion'),
                        value: isRecurring,
                        onChanged: (val) => setState(() => isRecurring = val),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isRecurring)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'daily', label: Text('Daily')),
                            ButtonSegment(value: 'weekly', label: Text('Weekly')),
                            ButtonSegment(value: 'monthly', label: Text('Monthly')),
                          ],
                          selected: {recurrencePattern ?? 'daily'},
                          onSelectionChanged: (val) => setState(() => recurrencePattern = val.first),
                        ),
                      
                      const SizedBox(height: 24),

                      // Subtasks section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Subtasks'),
                          const SizedBox(height: 8),
                          ...subtasks.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.subdirectory_arrow_right, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(entry.value)),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                                  onPressed: () => setState(() => subtasks.removeAt(entry.key)),
                                ),
                              ],
                            ),
                          )),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: subtaskController,
                                  decoration: const InputDecoration(hintText: 'Add subtask'),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      setState(() => subtasks.add(val.trim()));
                                      subtaskController.clear();
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: () {
                                  if (subtaskController.text.trim().isNotEmpty) {
                                    setState(() => subtasks.add(subtaskController.text.trim()));
                                    subtaskController.clear();
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      taskService.addTask(
                        textController.text.trim(),
                        energy: selectedEnergy,
                        priority: selectedPriority,
                        dueDate: selectedDate,
                        estimatedMinutes: estimatedMinutes,
                        tags: selectedTags.isNotEmpty ? selectedTags : null,
                        project: projectController.text.trim().isNotEmpty
                            ? projectController.text.trim()
                            : null,
                        isRecurring: isRecurring,
                        recurrencePattern: isRecurring ? recurrencePattern : null,
                        initialSubtasks: subtasks.isNotEmpty ? subtasks : null,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final textController = TextEditingController(text: task.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Edit task text',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                taskService.updateTaskText(task.id, textController.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTaskOptions(BuildContext context, TaskService service) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(context);
                _showEditTaskDialog(context, service.currentTask!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_rounded),
              title: const Text('Mark done'),
              onTap: () async {
                HapticFeedback.lightImpact();
                setState(() => _showCompletionAnimation = true);
                await Future.delayed(const Duration(milliseconds: 300));
                await service.completeTask(service.currentTask!); // FIXED
                _confettiController.play();
                setState(() => _showCompletionAnimation = false);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.snooze_rounded),
              title: const Text('Later'),
              onTap: () async {
                HapticFeedback.lightImpact();
                await service.snoozeTask(service.currentTask!); // FIXED
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fast_forward_rounded),
              title: const Text('Skip'),
              onTap: () async {
                HapticFeedback.lightImpact();
                await service.skipTask(service.currentTask!); // FIXED
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                await service.deleteTask(service.currentTask!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRemaining(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Remaining Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: taskService.tasks.where((t) => t.state != TaskState.completed).isEmpty
                  ? const Center(child: Text('All tasks completed! 🎉'))
                  : ListView.builder(
                      itemCount: taskService.tasks.where((t) => t.state != TaskState.completed).length,
                      itemBuilder: (context, index) {
                        final activeTasks = taskService.tasks.where((t) => t.state != TaskState.completed).toList();
                        final task = activeTasks[index];
                        
                        return Dismissible(
                          key: Key(task.id),
                          background: Container(color: Colors.green.withOpacity(0.1)),
                          secondaryBackground: Container(color: Colors.orange.withOpacity(0.1)),
                          onDismissed: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await taskService.completeTask(task);
                            } else {
                              await taskService.snoozeTask(task); 
                            }
                          },
                          child: ListTile(
                            title: Text(task.text),
                            subtitle: task.priority != TaskPriority.none
                                ? Text(task.priorityText, style: TextStyle(color: task.priorityColor))
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () async {
                                await taskService.completeTask(task);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== HELPER METHODS ==========

  String _getEnergyText(TaskEnergy energy) {
    switch (energy) {
      case TaskEnergy.high: return 'High Energy ⚡';
      case TaskEnergy.medium: return 'Medium Energy 🔋';
      case TaskEnergy.low: return 'Low Energy 💤';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    if (date.year == now.year && date.month == now.month && date.day == now.day + 1) {
      return 'Tomorrow';
    }
    if (difference.inDays < 7) {
      return 'in ${difference.inDays} days';
    }
    return 'on ${date.day}/${date.month}/${date.year}';
  }

  Widget _buildUpcomingView(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Group tasks by date
    final upcomingTasks = taskService.tasks.where((t) => t.state == TaskState.pending && t.dueDate != null && t.dueDate!.isAfter(today)).toList();
    upcomingTasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final groups = <DateTime, List<Task>>{};
    for (final t in upcomingTasks) {
      final date = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      groups[date] ??= [];
      groups[date]!.add(t);
    }

    if (upcomingTasks.isEmpty) {
      return _EmptyState(hasTasks: false);
    }

    final dates = groups.keys.toList()..sort();

    return FadeInUp(
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final tasks = groups[date]!;
          final isTomorrow = date.difference(today).inDays == 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isTomorrow ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isTomorrow ? 'TOMORROW' : DateFormat('EEEE, MMM d').format(date).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isTomorrow ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(indent: 12)),
                ],
              ),
              const SizedBox(height: 16),
              ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 24),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        color: _getPriorityColor(t.priority).withOpacity(0.3),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.text,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (t.project != null) ...[
                                  Icon(Icons.folder_open_rounded, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  const SizedBox(width: 4),
                                  Text(t.project!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4))),
                                  const SizedBox(width: 12),
                                ],
                                Icon(Icons.bolt_rounded, size: 12, color: _getEnergyColor(t.energy!)),
                                const SizedBox(width: 4),
                                Text(t.energy!.name, style: theme.textTheme.labelSmall?.copyWith(color: _getEnergyColor(t.energy!))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProjectsView(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    final progress = taskService.getProjectProgress();
    final projects = progress.keys.toList();

    if (projects.isEmpty) {
      return _EmptyState(hasTasks: false);
    }

    return FadeInUp(
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: projects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final name = projects[index];
          final percent = progress[name] ?? 0.0;
          final taskCount = taskService.tasks.where((t) => (t.project ?? 'Inbox') == name).length;
          final doneCount = taskService.tasks.where((t) => (t.project ?? 'Inbox') == name && t.state == TaskState.completed).length;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    _MetadataItem(
                      icon: Icons.task_alt_rounded,
                      text: '$doneCount/$taskCount',
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(percent * 100).round()}% Completed',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchView(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    final query = _searchController.text.toLowerCase();
    
    final filteredTasks = taskService.tasks.where((t) {
      final matchesQuery = t.text.toLowerCase().contains(query) || 
                          (t.project?.toLowerCase().contains(query) ?? false) ||
                          (t.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false);
      return matchesQuery;
    }).toList();

    return Column(
      children: [
        // Search bar is in header, but we can add filter chips here
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Priority'),
                  onSelected: (val) {},
                  selected: false,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('High Energy'),
                  onSelected: (val) {},
                  selected: false,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  onSelected: (val) {},
                  selected: false,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filteredTasks.isEmpty
              ? _EmptyState(hasTasks: false)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final t = filteredTasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(t.priority),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.text,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: t.state == TaskState.completed ? TextDecoration.lineThrough : null,
                                      color: t.state == TaskState.completed ? theme.colorScheme.onSurface.withOpacity(0.4) : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.project ?? 'Inbox',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  ),
                                ],
                              ),
                            ),
                            if (t.state == TaskState.completed)
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<bool?> _showScheduleDialog(BuildContext context, Task task) async {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final controller = TextEditingController();
    DateTime? snoozeUntil;

    return showDialog<dynamic>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Schedule for later'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. "tomorrow", "next Monday"',
                  prefixIcon: Icon(Icons.auto_awesome),
                ),
                onChanged: (val) {
                  final parsed = DateParser.parse(val);
                  setModalState(() => snoozeUntil = parsed);
                },
              ),
              if (snoozeUntil != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Will show again ${_formatDate(snoozeUntil!)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Or pick a quick option:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('2 hours'), onPressed: () => Navigator.pop(ctx, DateTime.now().add(const Duration(hours: 2)))),
                  ActionChip(label: const Text('Tomorrow'), onPressed: () => Navigator.pop(ctx, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1))),
                  ActionChip(label: const Text('Weekend'), onPressed: () => Navigator.pop(ctx, DateParser.parse('saturday'))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: snoozeUntil == null ? null : () => Navigator.pop(ctx, snoozeUntil),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    ).then((val) async {
      if (val is DateTime) {
        await taskService.snoozeTask(task, until: val);
        return true;
      }
      return false;
    });
  }

  Widget _buildProfileView(BuildContext context, TaskService taskService) {
    final theme = Theme.of(context);
    final stats = taskService.getWeeklyStats();
    final totalSeconds = taskService.getTotalSecondsThisWeek();
    final completedToday = taskService.tasks.where((t) => t.state == TaskState.completed && _isToday(t.completedAt)).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productivity', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            
            // Highlight Cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'DONE TODAY',
                    value: '$completedToday',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    label: 'FOCUS TIME',
                    value: _formatDurationShort(totalSeconds),
                    icon: Icons.timer_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Text('Last 7 Days', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Bar Chart
            Container(
              height: 200,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _SimpleBarChart(data: stats),
            ),
            
            const SizedBox(height: 32),
            Text('Badges', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BadgeIcon(icon: Icons.bolt_rounded, label: 'Early Bird', active: true),
                _BadgeIcon(icon: Icons.timer_3_select_rounded, label: 'Deep Focus', active: totalSeconds > 3600),
                _BadgeIcon(icon: Icons.auto_awesome_rounded, label: 'Consistency', active: false),
                _BadgeIcon(icon: Icons.workspace_premium_rounded, label: 'Elite', active: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatDurationShort(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final Map<DateTime, int> data;

  const _SimpleBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedKeys = data.keys.toList()..sort();
    final maxValue = data.values.fold(1, (prev, curr) => curr > prev ? curr : prev);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: sortedKeys.map((date) {
        final val = data[date] ?? 0;
        final heightFactor = val / maxValue;
        final isToday = date.day == DateTime.now().day;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$val', style: theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: 120 * heightFactor + 4,
              decoration: BoxDecoration(
                color: isToday ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('E').format(date)[0],
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BadgeIcon({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Container(
        width: 60,
        height: 60, // intentionally fixed
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.2)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  const _TaskCard({
    required Key key,
    required this.task,
    required this.onDone,
    required this.onSkip,
    required this.onLater,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (task.project != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.project!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const Spacer(),
                if (task.priority != TaskPriority.none)
                  Text(
                    task.priorityText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: task.priorityColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              task.text,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: _calculateFontSize(task.text.length),
                color: theme.colorScheme.onSurface,
              ),
            ),
            
            // Timer Display (Focus Mode Light)
            if (task.durationSeconds > 0 || task.isTimerRunning) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: task.isTimerRunning ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(task.durationSeconds),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: task.isTimerRunning ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5),
                      fontWeight: task.isTimerRunning ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (task.isTimerRunning) ...[
                    const SizedBox(width: 8),
                    _BlinkingDot(),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 24),
            
            // Subtask Progress
            if (task.subtasks.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.subtaskProgress,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(task.subtaskProgress * 100).round()}%',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                if (task.dueDate != null)
                  _MetadataItem(
                    icon: Icons.calendar_today_rounded,
                    text: _formatDueDate(task.dueDate!),
                    color: _getDueDateColor(task.dueDate!),
                  ),
                if (task.energy != null) ...[
                  if (task.dueDate != null) const SizedBox(width: 16),
                  _MetadataItem(
                    icon: _getEnergyIcon(task.energy!),
                    text: task.energy!.name.toUpperCase(),
                    color: _getEnergyColor(task.energy!),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            
            // Quick Controls
            Row(
              children: [
                _QuickControlButton(
                  icon: task.isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: task.isTimerRunning ? 'Pause' : 'Start',
                  onTap: () {
                    final taskService = Provider.of<TaskService>(context, listen: false);
                    if (task.isTimerRunning) {
                      taskService.stopTaskTimer(task.id);
                    } else {
                      taskService.startTaskTimer(task.id);
                    }
                  },
                ),
                const SizedBox(width: 12),
                _QuickControlButton(
                  icon: Icons.checklist_rounded,
                  label: 'Subtasks',
                  onTap: () => _showSubtasks(context, task),
                ),
              ],
            ),
            
            if (task.tags != null && task.tags!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: task.tags!.map((t) => _buildTag(t, context)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  void _showSubtasks(BuildContext context, Task task) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentTask = taskService.tasks.firstWhere((t) => t.id == task.id);
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subtasks', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (currentTask.subtasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No subtasks yet.')),
                  )
                else
                  ...currentTask.subtasks.map((s) => CheckboxListTile(
                    title: Text(s.text, style: TextStyle(
                      decoration: s.isDone ? TextDecoration.lineThrough : null,
                      color: s.isDone ? Colors.grey : null,
                    )),
                    value: s.isDone,
                    onChanged: (val) async {
                      await taskService.toggleSubtask(task.id, s.id);
                      setModalState(() {});
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Add a subtask...',
                          isDense: true,
                        ),
                        onSubmitted: (val) async {
                          if (val.trim().isNotEmpty) {
                            await taskService.addSubtask(task.id, val.trim());
                            controller.clear();
                            setModalState(() {});
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        if (controller.text.trim().isNotEmpty) {
                          await taskService.addSubtask(task.id, controller.text.trim());
                          controller.clear();
                          setModalState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTag(String tag, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        '#$tag',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMetadataRow(BuildContext context, Task task) {
    final metadataItems = <Widget>[];
    final theme = Theme.of(context);

    // Energy indicator
    if (task.energy != null) {
      metadataItems.add(
        _MetadataItem(
          icon: _getEnergyIcon(task.energy!),
          text: task.energy!.name.toUpperCase(),
          color: _getEnergyColor(task.energy!),
        ),
      );
    }

    // Due date
    if (task.dueDate != null) {
      metadataItems.add(
        _MetadataItem(
          icon: Icons.access_time,
          text: _formatDueDate(task.dueDate!),
          color: _getDueDateColor(task.dueDate!),
        ),
      );
    }

    // Time estimate
    if (task.estimatedMinutes != null && task.estimatedMinutes! > 0) {
      metadataItems.add(
        _MetadataItem(
          icon: Icons.timer,
          text: '${task.estimatedMinutes}m',
          color: Colors.deepPurple,
        ),
      );
    }

    // Project
    if (task.project != null && task.project!.isNotEmpty) {
      metadataItems.add(
        _MetadataItem(
          icon: Icons.folder_open,
          text: task.project!,
          color: Colors.teal,
        ),
      );
    }

    if (metadataItems.isEmpty) return const SizedBox(height: 16);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < metadataItems.length; i++) ...[
          metadataItems[i],
          if (i < metadataItems.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ),
        ]
      ],
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: "Later",
          color: Colors.orange,
          onTap: onLater,
          isPrimary: false,
        ),
        _ActionButton(
          icon: Icons.check_rounded,
          label: "Done",
          color: Colors.green,
          onTap: onDone,
          isPrimary: true,
        ),
        _ActionButton(
          icon: Icons.fast_forward_rounded,
          label: "Skip",
          color: Colors.grey,
          onTap: onSkip,
          isPrimary: false,
        ),
      ],
    );
  }

  IconData _getEnergyIcon(TaskEnergy energy) {
    switch (energy) {
      case TaskEnergy.high:
        return Icons.bolt;
      case TaskEnergy.medium:
        return Icons.battery_std;
      case TaskEnergy.low:
        return Icons.battery_alert;
    }
  }

  Color _getEnergyColor(TaskEnergy energy) {
    switch (energy) {
      case TaskEnergy.high:
        return Colors.amber;
      case TaskEnergy.medium:
        return Colors.blue;
      case TaskEnergy.low:
        return Colors.purple;
    }
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (dueDate.isBefore(now)) {
      return Colors.red;
    } else if (difference.inDays == 0) {
      return Colors.orange;
    } else if (difference.inDays < 3) {
      return Colors.blue;
    } else {
      return Colors.green;
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (dueDate.year == now.year && dueDate.month == now.month && dueDate.day == now.day) {
      return 'TODAY';
    } else if (difference.inDays == 1) {
      return 'TOMORROW';
    } else if (difference.inDays < 0) {
      return 'OVERDUE';
    } else if (difference.inDays < 7) {
      return 'IN ${difference.inDays}D';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return 'IN ${weeks}W';
    }
  }

  double _calculateFontSize(int textLength) {
    if (textLength > 100) return 20.0;
    if (textLength > 60) return 22.0;
    if (textLength > 30) return 24.0;
    return 28.0;
  }
}

class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isPrimary ? 60.0 : 48.0;
    final iconSize = isPrimary ? 24.0 : 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(isPrimary ? 0.1 : 0.05),
              border: Border.all(
                color: color.withOpacity(isPrimary ? 0.3 : 0.2),
                width: isPrimary ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  final TaskEnergy energy;

  const _EnergyBadge({required this.energy});

  @override
  Widget build(BuildContext context) {
    String text;
    String icon;
    Color color;

    switch (energy) {
      case TaskEnergy.high:
        text = "High Energy";
        icon = "⚡";
        color = Colors.amber;
        break;
      case TaskEnergy.medium:
        text = "Medium Energy";
        icon = "🔋";
        color = Colors.blue;
        break;
      case TaskEnergy.low:
        text = "Low Energy";
        icon = "💤";
        color = Colors.purple;
        break;
    }

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
class _EmptyState extends StatelessWidget {
  final bool hasTasks;

  const _EmptyState({required this.hasTasks});

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ZoomIn(
      duration: const Duration(milliseconds: 600),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasTasks ? Icons.auto_awesome_rounded : Icons.spa_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            hasTasks ? "All settled." : "Your mind is clear.",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasTasks ? "Take a breath before the next one." : "Add a task when you're ready to flow.",
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (hasTasks) ...[
            Text(
              "Recharge with a tiny action:",
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _RecoveryChip(label: 'Drink water', onTap: () => taskService.completeRecoveryNudge()),
                _RecoveryChip(label: 'Stand up', onTap: () => taskService.completeRecoveryNudge()),
                _RecoveryChip(label: 'Deep breath', onTap: () => taskService.completeRecoveryNudge()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FocusOverlay extends StatelessWidget {
  final VoidCallback onExit;

  const _FocusOverlay({required this.onExit});

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final theme = Theme.of(context);
    final currentTask = taskService.currentTask;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FOCUS MODE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onExit,
                  ),
                ],
              ),
              const Spacer(flex: 1),
              
              // Pomodoro Timer
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      taskService.isPomodoroWorkMode ? 'WORK' : 'BREAK',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: taskService.isPomodoroWorkMode ? theme.colorScheme.primary : theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatPomodoroTime(taskService.pomodoroSeconds),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(taskService.isPomodoroRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                          iconSize: 48,
                          color: theme.colorScheme.primary,
                          onPressed: () {
                            if (taskService.isPomodoroRunning) {
                              taskService.pausePomodoro();
                            } else {
                              taskService.startPomodoro();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => taskService.resetPomodoro(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 1),
              
              if (currentTask != null) ...[
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      Text(
                        currentTask.text,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (currentTask.subtasks.isNotEmpty)
                        Text(
                          '${currentTask.subtasks.where((s) => s.isDone).length}/${currentTask.subtasks.length} subtasks done',
                          style: theme.textTheme.labelMedium,
                        ),
                    ],
                  ),
                ),
              ] else 
                const Text('No active task. Flow on.'),

              const Spacer(flex: 2),
              
              if (currentTask != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => taskService.completeCurrentTask(),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    child: const Text('COMPLETE TASK'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPomodoroTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

Color _getPriorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high: return const Color(0xFFF43F5E);
    case TaskPriority.medium: return const Color(0xFFF59E0B);
    case TaskPriority.low: return const Color(0xFF3B82F6);
    default: return Colors.grey;
  }
}

Color _getEnergyColor(TaskEnergy energy) {
  switch (energy) {
    case TaskEnergy.high: return Colors.amber;
    case TaskEnergy.medium: return Colors.blue;
    case TaskEnergy.low: return Colors.purple;
  }
}

class _RecoveryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RecoveryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nice. $label')),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
      ),
    );
  }
}

class _QuickControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickControlButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}