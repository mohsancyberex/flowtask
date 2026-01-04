import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../theme.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final theme = Theme.of(context);

    // Procrastination Intervention prompt when a heavy avoided task surfaces
    if (taskService.currentTask != null && taskService.needsIntervention(taskService.currentTask!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _showIntervention(context, taskService, taskService.currentTask!);
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Energy selector and Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _EnergyBadge(energy: taskService.userEnergy),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
  'What matters Now',
  style: theme.textTheme.titleSmall?.copyWith(
    color: theme.colorScheme.onSurface.withOpacity(0.55),
    fontWeight: FontWeight.w400,
  ),
),


              const Spacer(),

              // MAIN CARD AREA
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
                  onPanEnd: (details) async {
                    // Vertical swipe up => Skip
                    if (details.velocity.pixelsPerSecond.dy < -500) {
                      await _handleAction(context, taskService.skipTask);
                    }
                  },
                  child: Dismissible(
                    key: ValueKey('dismiss-${taskService.currentTask!.id}'),
                    direction: DismissDirection.horizontal,
                    background: const _SwipeBackground(
                      alignment: Alignment.centerLeft,
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      label: 'Done',
                    ),
                    secondaryBackground: const _SwipeBackground(
                      alignment: Alignment.centerRight,
                      icon: Icons.snooze_rounded,
                      color: Colors.orange,
                      label: 'Later',
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        await _handleAction(context, taskService.completeTask);
                      } else if (direction == DismissDirection.endToStart) {
                        await _handleAction(context, taskService.snoozeTask);
                      }
                      return true;
                    },
                    child: _TaskCard(
                      key: ValueKey(taskService.currentTask!.id),
                      task: taskService.currentTask!,
                      onDone: () => _handleAction(context, taskService.completeTask),
                      onSkip: () => _handleAction(context, taskService.skipTask),
                      onLater: () => _handleAction(context, taskService.snoozeTask),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Center(child: Text('Swipe → Done / Later', style: theme.textTheme.labelSmall)),

              const Spacer(),

              // Remaining summary and Add
              Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.1)),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _showRemaining(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Text('Remaining (${taskService.activeTaskCount})', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/add'),
                    child: const Text('+ Add task'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, Future<void> Function() action) async {
    HapticFeedback.lightImpact();
    await action();
    final taskService = Provider.of<TaskService>(context, listen: false);
    // Ethical Sponsor card only in positive moments
    if (taskService.shouldShowSponsorCard) {
      if (!context.mounted) return;
      _showSponsorCard(context, taskService);
    }
  }

  void _showSponsorCard(BuildContext context, TaskService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SponsorSheet(onDismiss: () {
        service.onSponsorShown();
        context.pop();
      }),
    );
  }

  void _showIntervention(BuildContext context, TaskService service, Task task) {
    service.markInterventionShown(task.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InterventionSheet(task: task, service: service),
    );
  }

  void _showTaskOptions(BuildContext context, TaskService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.check_rounded), title: const Text('Mark done'), onTap: () async { await _handleAction(context, service.completeTask); if (context.mounted) context.pop(); }),
            ListTile(leading: const Icon(Icons.snooze_rounded), title: const Text('Later'), onTap: () async { await _handleAction(context, service.snoozeTask); if (context.mounted) context.pop(); }),
            ListTile(leading: const Icon(Icons.fast_forward_rounded), title: const Text('Skip'), onTap: () async { await _handleAction(context, service.skipTask); if (context.mounted) context.pop(); }),
          ],
        ),
      ),
    );
  }

  void _showRemaining(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RemainingSheet(),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  const _TaskCard({
    required this.key,
    required this.task,
    required this.onDone,
    required this.onSkip,
    required this.onLater,
  }) : super(key: key);

  @override
  final Key key;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Task Text only (no metadata)
          Text(
            task.text,
            style: theme.textTheme.displayMedium?.copyWith(
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onLater;

  const _ActionButtons({
    required this.onDone,
    required this.onSkip,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: Icons.refresh_rounded, 
          label: "Later",
          onTap: onLater,
          color: Colors.orange.shade300,
        ),
        _CircleButton(
          icon: Icons.check_rounded, 
          label: "Done",
          onTap: onDone,
          color: Colors.green.shade400,
          isPrimary: true,
        ),
        _CircleButton(
          icon: Icons.fast_forward_rounded, 
          label: "Skip",
          onTap: onSkip,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isPrimary;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isPrimary ? 80.0 : 60.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: color.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              icon, 
              color: color,
              size: isPrimary ? 32 : 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
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
    return FadeIn(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasTasks ? Icons.spa_rounded : Icons.coffee_rounded,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hasTasks ? "Nothing needs your attention right now." : "Zero tasks.\nEnjoy the flow.",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasTasks) ...[
            Text(
              "Try a tiny reset:",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _RecoveryChip(label: 'Drink water 💧', onTap: () => taskService.completeRecoveryNudge()),
                _RecoveryChip(label: 'Stand up 🧍', onTap: () => taskService.completeRecoveryNudge()),
                _RecoveryChip(label: 'Close one tab 🗂️', onTap: () => taskService.completeRecoveryNudge()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final AlignmentGeometry alignment;
  final IconData icon;
  final Color color;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ] else ...[
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(icon, color: color),
          ],
        ],
      ),
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
      onTap: () {
        
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => const _EnergySelectorSheet(),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;

  const _Tag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? theme.disabledColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ?? theme.disabledColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _EnergySelectorSheet extends StatelessWidget {
  const _EnergySelectorSheet();

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "How are you feeling?",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _EnergyOption(
            icon: "⚡",
            title: "High Energy",
            subtitle: "Ready to crush difficult tasks",
            onTap: () {
              taskService.setUserEnergy(TaskEnergy.high);
              context.pop();
            },
          ),
          _EnergyOption(
            icon: "🔋",
            title: "Medium Energy",
            subtitle: "Steady flow state",
            onTap: () {
              taskService.setUserEnergy(TaskEnergy.medium);
              context.pop();
            },
          ),
          _EnergyOption(
            icon: "💤",
            title: "Low Energy",
            subtitle: "Need easy wins",
            onTap: () {
              taskService.setUserEnergy(TaskEnergy.low);
              context.pop();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _EnergyOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EnergyOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(icon, style: const TextStyle(fontSize: 24)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SponsorSheet extends StatelessWidget {
  final VoidCallback onDismiss;
  const _SponsorSheet({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = Provider.of<TaskService>(context, listen: false);
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thank you for the win ✨', style: theme.textTheme.titleLarge),
              IconButton(onPressed: onDismiss, icon: const Icon(Icons.close))
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.favorite_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text('Support FlowTask with a single, tasteful sponsor card. No tracking, ever.', style: theme.textTheme.bodyMedium)),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: onDismiss,
                child: const Text('Why Not'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () { service.setSponsorEnabled(false); onDismiss(); },
              child: const Text('Disable Sponsor'),
            ),
          ])
        ],
      ),
    );
  }
}

class _InterventionSheet extends StatefulWidget {
  final Task task;
  final TaskService service;
  const _InterventionSheet({required this.task, required this.service});

  @override
  State<_InterventionSheet> createState() => _InterventionSheetState();
}

class _InterventionSheetState extends State<_InterventionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg, top: AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: AppSpacing.md),
          Text('This feels heavy. What should we do?', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: "Option: a smaller first step",
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.call_split_rounded),
              label: const Text('Break into smaller'),
              onPressed: () async {
                if (_controller.text.trim().isNotEmpty) {
                  await widget.service.addTask(_controller.text.trim(), context: const [], energy: TaskEnergy.low);
                }
                if (context.mounted) context.pop();
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.visibility_off_rounded),
              label: const Text('Hide for 7 days'),
              onPressed: () async { await widget.service.hideTask(widget.task.id, const Duration(days: 7)); if (context.mounted) context.pop(); },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove completely'),
              onPressed: () async { await widget.service.deleteTask(widget.task.id); if (context.mounted) context.pop(); },
            ),
          ]),
        ],
      ),
    );
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
      onTap: () { onTap(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nice. $label'))); },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface)),
      ),
    );
  }
}

class _RemainingSheet extends StatelessWidget {
  const _RemainingSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Consumer<TaskService>(
        builder: (context, service, _) {
          final items = service.tasks
              .where((t) => t.state != TaskState.completed && t.id != service.currentTask?.id)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))) ,
              const SizedBox(height: AppSpacing.md),
              Text('Remaining', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('All clear ✨', style: theme.textTheme.bodyMedium))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.08)),
                        itemBuilder: (context, index) {
                          final t = items[index];
                          return Dismissible(
                            key: ValueKey('rem-${t.id}'),
                            background: const _SwipeBackground(
                              alignment: Alignment.centerLeft,
                              icon: Icons.check_rounded,
                              color: Colors.green,
                              label: 'Done',
                            ),
                            secondaryBackground: const _SwipeBackground(
                              alignment: Alignment.centerRight,
                              icon: Icons.snooze_rounded,
                              color: Colors.orange,
                              label: 'Later',
                            ),
                            confirmDismiss: (direction) async {
                              final svc = Provider.of<TaskService>(context, listen: false);
                              if (direction == DismissDirection.startToEnd) {
                                await svc.completeTaskById(t.id);
                              } else {
                                await svc.snoozeTaskById(t.id);
                              }
                              return true;
                            },
                            child: ListTile(
                              title: Text(t.text, style: theme.textTheme.bodyLarge),
                              onLongPress: () async {
                                final svc = Provider.of<TaskService>(context, listen: false);
                                await showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => Container(
                                    padding: AppSpacing.paddingLg,
                                    decoration: BoxDecoration(
                                      color: theme.scaffoldBackgroundColor,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit text'), onTap: () async {
                                          final controller = TextEditingController(text: t.text);
                                          await showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Edit task'),
                                              content: TextField(controller: controller, autofocus: true),
                                              actions: [
                                                TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
                                                TextButton(onPressed: () { svc.updateTaskText(t.id, controller.text.trim()); ctx.pop(); }, child: const Text('Save')),
                                              ],
                                            ),
                                          );
                                          if (context.mounted) context.pop();
                                        }),
                                        ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Delete'), onTap: () async { await svc.deleteTask(t.id); if (context.mounted) context.pop(); }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
