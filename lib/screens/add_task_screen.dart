import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../theme.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _textController = TextEditingController();
  final List<String> _selectedContexts = [];
  TaskEnergy _selectedEnergy = TaskEnergy.medium;
  bool _showDetails = false;
  String? _delayChoice; // 'today' | 'tomorrow' | 'someday'

  final List<String> _availableContexts = [
    '🧠 Focus', '📱 Phone', '💻 Laptop', '🚶 Outside', '🏠 Home', '🏢 Work'
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_textController.text.trim().isEmpty) return;

    final taskService = Provider.of<TaskService>(context, listen: false);
    
    if (taskService.activeTaskCount >= 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Flow limited to 7 tasks. Finish one first!"),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String raw = _textController.text.trim();
    _maybeAmbiguityPrompt(raw).then((finalText) {
      if (!mounted) return;
      // Compute hidden until from delay choice
      DateTime? hiddenUntil;
      final now = DateTime.now();
      if (_delayChoice == 'today') {
        hiddenUntil = now.add(const Duration(hours: 6));
      } else if (_delayChoice == 'tomorrow') {
        hiddenUntil = now.add(const Duration(days: 1));
      } else if (_delayChoice == 'someday') {
        hiddenUntil = now.add(const Duration(days: 7));
      }

      taskService.addTask(
        finalText,
        context: _selectedContexts,
        energy: _selectedEnergy,
        hiddenUntil: hiddenUntil,
      );

    context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text("New Task"),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Input
              TextField(
                controller: _textController,
                autofocus: true,
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: "What needs doing?",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              // Details toggle
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(_showDetails ? Icons.expand_less : Icons.expand_more, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text('Add details (optional)', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: AppSpacing.md),
                // Energy choices (icons only)
                Text('Energy', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('⚡ High'),
                      selected: _selectedEnergy == TaskEnergy.high,
                      onSelected: (_) => setState(() => _selectedEnergy = TaskEnergy.high),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🔋 Medium'),
                      selected: _selectedEnergy == TaskEnergy.medium,
                      onSelected: (_) => setState(() => _selectedEnergy = TaskEnergy.medium),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('💤 Low'),
                      selected: _selectedEnergy == TaskEnergy.low,
                      onSelected: (_) => setState(() => _selectedEnergy = TaskEnergy.low),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                // Context chips
                Text('Context', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableContexts.map((ctx) {
                    final isSelected = _selectedContexts.contains(ctx);
                    return FilterChip(
                      label: Text(ctx),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedContexts.add(ctx);
                          } else {
                            _selectedContexts.remove(ctx);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Delay choices
                Text('Delay', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('Later today'), selected: _delayChoice == 'today', onSelected: (_) => setState(() => _delayChoice = 'today')),
                  ChoiceChip(label: const Text('Tomorrow'), selected: _delayChoice == 'tomorrow', onSelected: (_) => setState(() => _delayChoice = 'tomorrow')),
                  ChoiceChip(label: const Text('Someday'), selected: _delayChoice == 'someday', onSelected: (_) => setState(() => _delayChoice = 'someday')),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on _AddTaskScreenState {
  Future<String> _maybeAmbiguityPrompt(String raw) async {
    final lower = raw.toLowerCase();
    final isAmbiguous = lower.contains('work on') || lower.contains('think about') || lower.contains('start ');
    if (!isAmbiguous) return raw;
    String clarified = raw;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final controller = TextEditingController();
        return Container(
          padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg, top: AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("What does 'done' look like?", style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g., Send X, Publish Y, Decide Z'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () {
                  final def = controller.text.trim();
                  if (def.isNotEmpty) clarified = def; 
                  Navigator.of(ctx).pop();
                },
                child: const Text('Use This As Done'),
              ),
            ],
          ),
        );
      },
    );
    return clarified;
  }
}

class _EnergyRadio extends StatelessWidget {
  final String title;
  final TaskEnergy value;
  final TaskEnergy groupValue;
  final ValueChanged<TaskEnergy?> onChanged;

  const _EnergyRadio({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<TaskEnergy>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
