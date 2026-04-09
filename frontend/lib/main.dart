import 'package:flutter/material.dart';
import 'auth/services/auth_service.dart';
import 'auth/screens/login_screen.dart';
import 'auth/screens/register_screen.dart';
import 'core/services/app_notification_service.dart';
import 'student/screens/student_dashboard.dart';
import 'librarian/screens/librarian_dashboard.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotificationService.ensureInitialized();
  runApp(const LibraryApp());
}

class LibraryApp extends StatefulWidget {
  const LibraryApp({super.key});

  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppNotificationService.refreshRemoteRegistration();
      AppNotificationService.syncAndDisplayNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const StartupRouter(),
        routes: {
          "/login": (context) => const LoginScreen(),
          "/register": (context) => const RegisterScreen(),
          "/student": (context) => const StudentDashboard(),
          "/librarian": (context) => const LibrarianDashboard(),
        },
    );
  }
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key});

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  @override
  void initState() {
    super.initState();
    _routeFromSession();
  }

  Future<void> _routeFromSession() async {
    final route = await AuthService.getInitialRoute();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const AppPageHeader(
              title: "Opening your library",
              subtitle:
                  "Checking your saved session and preparing the dashboard.",
              icon: Icons.auto_stories_rounded,
              badges: [AppHeaderBadge(label: "Status", value: "Loading")],
            ),
          ),
        ),
      ),
    );
  }
}
