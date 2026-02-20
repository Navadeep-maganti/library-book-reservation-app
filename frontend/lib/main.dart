import 'package:flutter/material.dart';
import 'auth/services/auth_service.dart';
import 'auth/screens/login_screen.dart';
import 'student/screens/student_dashboard.dart';
import 'librarian/screens/librarian_dashboard.dart';

void main() {
  runApp(const LibraryApp());
}

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const StartupRouter(),
      routes: {
        "/login": (context) => const LoginScreen(),
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
