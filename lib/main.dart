import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/task_service.dart';
import 'package:flowtask/nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final taskService = TaskService(prefs);
  
  runApp(MyApp(taskService: taskService));
}

class MyApp extends StatelessWidget {
  final TaskService taskService;
  
  const MyApp({super.key, required this.taskService});
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => taskService,
      child: MaterialApp.router(
        routerConfig: AppRouter.router,
        title: 'FlowTask',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFF6366F1),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1),
            brightness: Brightness.light,
            primary: const Color(0xFF6366F1),
            secondary: const Color(0xFF8B5CF6),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6366F1),
            elevation: 0,
          ),
          // cardTheme: CardTheme(
          //   elevation: 1,
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          // ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF818CF8),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF818CF8),
            brightness: Brightness.dark,
            primary: const Color(0xFF818CF8),
            secondary: const Color(0xFFA78BFA),
            background: const Color(0xFF0F172A),
            surface: const Color(0xFF1E293B),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E293B),
            elevation: 0,
          ),
          // cardTheme: CardTheme(
          //   elevation: 2,
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   color: const Color(0xFF1E293B),
          // ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system, // Auto-detect system theme
      ),
    );
  }
}