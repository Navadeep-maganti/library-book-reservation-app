import "package:flutter/material.dart";

class WaitingListPage extends StatelessWidget {
  const WaitingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Waiting List")),
      body: const WaitingListPageBody(),
    );
  }
}

class WaitingListPageBody extends StatelessWidget {
  const WaitingListPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final waitingItems = const [
      ("Distributed Systems", 4, "Estimated: 2 days"),
      ("Introduction to Algorithms", 7, "Estimated: 5 days"),
      ("Data Mining Concepts", 2, "Estimated: 1 day"),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: const Text(
            "Books that are unavailable can be tracked here. You will be notified when your turn is reached.",
          ),
        ),
        const SizedBox(height: 12),
        ...waitingItems.map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.hourglass_bottom_outlined),
              title: Text(item.$1),
              subtitle: Text("Position: ${item.$2} - ${item.$3}"),
              trailing: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Removed ${item.$1} from waiting list."),
                    ),
                  );
                },
                child: const Text("Leave"),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
