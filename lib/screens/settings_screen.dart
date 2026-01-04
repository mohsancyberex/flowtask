import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          _SectionHeader(title: "Preferences"),
          // Dark Mode is system handled for now, but we can show it's "Auto"
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text("Appearance"),
            subtitle: const Text("System Default"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Follows system settings")),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text("Haptics"),
            value: true, // Placeholder
            onChanged: (val) {},
            activeColor: theme.colorScheme.primary,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.favorite_rounded),
            title: const Text("Sponsor card after wins"),
            subtitle: const Text("One tasteful card. Your choice."),
            value: taskService.sponsorEnabled,
            onChanged: (val) => taskService.setSponsorEnabled(val),
            activeColor: theme.colorScheme.primary,
          ),

          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(title: "Data"),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            title: Text("Reset All Data", style: TextStyle(color: theme.colorScheme.error)),
            subtitle: const Text("Clear all tasks and preferences"),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Reset everything?"),
                  content: const Text("This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => ctx.pop(false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => ctx.pop(true),
                      child: Text("Reset", style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await taskService.clearAll();
                if (context.mounted) {
                  context.pop(); // Go back to main
                }
              }
            },
          ),
          if (taskService.silentUntil != null && DateTime.now().isBefore(taskService.silentUntil!))
            ListTile(
              leading: const Icon(Icons.volume_off_rounded),
              title: const Text('Professional Silence Mode'),
              subtitle: Text('Quiet until ${taskService.silentUntil}'),
            ),
          
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Column(
              children: [
                Text(
                  "FlowTask",
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "v1.0.0 • No Cloud • No Guilt",
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
