import "package:flutter/material.dart";

class LibraryAnnouncementsPage extends StatelessWidget {
  const LibraryAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = const [
      (
        "Extended Library Hours",
        "Library will remain open until 11:00 PM during mid-semester exams.",
        "Info",
      ),
      (
        "Digital Access Maintenance",
        "E-journal portal maintenance on Saturday, 8:00 AM to 10:00 AM.",
        "Scheduled",
      ),
      (
        "Fine Waiver Window",
        "50% fine waiver available for returns completed before March 5.",
        "Important",
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Library Announcements")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: announcements.map((announcement) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          announcement.$1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Chip(label: Text(announcement.$3)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement.$2,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
