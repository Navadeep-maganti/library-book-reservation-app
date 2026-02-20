import "package:flutter/material.dart";

class BookRenewalPage extends StatelessWidget {
  const BookRenewalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final renewableBooks = const [
      ("Operating Systems", "Due: 24 Feb 2026", true),
      ("Computer Networks", "Due: 26 Feb 2026", true),
      ("DBMS", "Due: 18 Feb 2026", false),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Book Renewal")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Renewable Items",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...renewableBooks.map(
            (book) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(book.$1),
                subtitle: Text(book.$2),
                trailing: FilledButton.tonal(
                  onPressed: book.$3
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${book.$1} renewed.")),
                          );
                        }
                      : null,
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
