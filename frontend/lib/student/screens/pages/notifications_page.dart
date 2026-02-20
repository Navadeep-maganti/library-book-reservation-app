import "package:flutter/material.dart";

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = const [
      (
        "Due Reminder",
        "Operating Systems is due tomorrow. Renew now to avoid fines.",
        "10:30 AM",
      ),
      (
        "Reservation Update",
        "Your token #A-27 moved to position 3 in the queue.",
        "9:10 AM",
      ),
      (
        "Announcement",
        "Library extended hours this week till 11:00 PM.",
        "Yesterday",
      ),
      (
        "Fine Alert",
        "Outstanding fine of Rs 60 is pending for settlement.",
        "Yesterday",
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 8,
            ),
            leading: const CircleAvatar(child: Icon(Icons.notifications_none)),
            title: Text(
              item.$1,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(item.$2),
            trailing: Text(
              item.$3,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemCount: notifications.length,
      ),
    );
  }
}
