import "package:flutter/material.dart";

class BookAvailabilityPage extends StatelessWidget {
  const BookAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final books = const [
      ("Operating Systems", "Silberschatz", "CS-A12", 6),
      ("Database Systems", "Ramakrishnan", "CS-B08", 2),
      ("Computer Networks", "Tanenbaum", "CS-A04", 5),
      ("Clean Code", "Robert C. Martin", "SE-C11", 1),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Book Availability")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search by title, author, or ISBN",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...books.map((book) {
            final available = book.$4 > 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(book.$1),
                subtitle: Text("${book.$2}  •  Shelf ${book.$3}"),
                trailing: Chip(
                  label: Text(available ? "Available (${book.$4})" : "Issued"),
                  backgroundColor: available
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
