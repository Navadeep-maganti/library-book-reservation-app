import "package:flutter/material.dart";

class BorrowHistoryPage extends StatelessWidget {
  const BorrowHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = const [
      ("Clean Code", "Issued: 02 Jan 2026", "Returned: 15 Jan 2026"),
      ("Database Systems", "Issued: 10 Jan 2026", "Returned: 25 Jan 2026"),
      ("Compiler Design", "Issued: 28 Jan 2026", "Returned: 10 Feb 2026"),
      ("Operating Systems", "Issued: 11 Feb 2026", "Not Returned"),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Borrow History")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final active = item.$3 == "Not Returned";
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(item.$1),
              subtitle: Text("${item.$2}\n${item.$3}"),
              isThreeLine: true,
              trailing: Chip(
                label: Text(active ? "Active" : "Closed"),
                backgroundColor: active
                    ? Colors.amber.shade100
                    : Colors.green.shade50,
              ),
            ),
          );
        },
      ),
    );
  }
}
