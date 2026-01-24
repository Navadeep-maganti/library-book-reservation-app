import 'package:flutter/material.dart';
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
      initialRoute: "/login",
      routes: {
        "/login": (context) => const LoginScreen(),
        "/student": (context) => const StudentDashboard(),
        "/librarian": (context) => const LibrarianDashboard(),
      },
    );
  }
}
