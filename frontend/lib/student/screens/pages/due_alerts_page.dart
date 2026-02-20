import "package:flutter/material.dart";

class DueAlertsPage extends StatelessWidget {
  const DueAlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dueItems = const [
      ("Distributed Systems", "Due in 1 day"),
      ("Operating Systems", "Due in 3 days"),
      ("Compiler Design", "Due in 5 days"),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Due Alerts")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text("Reminder Preferences"),
              subtitle: const Text("Push + Email reminders enabled"),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ),
          const SizedBox(height: 12),
          ...dueItems.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text("Renew"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
