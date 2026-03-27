import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../core/widgets/app_ui.dart';

class LibrarianDashboard extends StatelessWidget {
  const LibrarianDashboard({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Do you want to logout from this account?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Librarian Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppPageHeader(
            title: "Librarian workspace",
            subtitle:
                "Circulation, inventory updates, and student support tools will live here in a more polished operational dashboard.",
            icon: Icons.local_library_outlined,
            badges: [
              AppHeaderBadge(label: "Role", value: "Librarian"),
              AppHeaderBadge(label: "Mode", value: "Operations"),
            ],
          ),
          SizedBox(height: 18),
          AppInfoBanner(
            icon: Icons.construction_outlined,
            message:
                "This area is ready for the next round of librarian-focused UI work. The student-facing redesign has been applied first so the app already feels more cohesive.",
            color: Color(0xFF1D4ED8),
          ),
          SizedBox(height: 18),
          AppEmptyStateCard(
            icon: Icons.dashboard_customize_outlined,
            title: "Librarian modules coming here",
            subtitle:
                "Issue workflows, returns, reservation processing, and catalog management can now be styled on top of this improved base.",
          ),
        ],
      ),
    );
  }
}
