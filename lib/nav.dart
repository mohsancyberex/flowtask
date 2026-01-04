import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/main_screen.dart';
import 'screens/add_task_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'add',
            pageBuilder: (context, state) => const MaterialPage(
              fullscreenDialog: true,
              child: AddTaskScreen(),
            ),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}
