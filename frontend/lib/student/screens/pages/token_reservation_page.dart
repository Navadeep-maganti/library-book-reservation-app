import "package:flutter/material.dart";

class TokenReservationPage extends StatelessWidget {
  const TokenReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Token Reservation")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Current Token",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text("Token #A-27  •  Queue position: 4"),
                  SizedBox(height: 4),
                  Text("Counter: Circulation Desk 1"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reservation Requests",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ...const [
                    "Distributed Systems",
                    "Introduction to Algorithms",
                    "Data Mining Concepts",
                  ].map(
                    (title) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bookmark_added_outlined),
                      title: Text(title),
                      subtitle: Text("Status: Waiting"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("New token request submitted.")),
              );
            },
            icon: const Icon(Icons.confirmation_num_outlined),
            label: const Text("Generate New Token"),
          ),
        ],
      ),
    );
  }
}
