import "package:flutter/material.dart";

class BookAvailabilityPage extends StatefulWidget {
  const BookAvailabilityPage({super.key, this.initialQuery = ""});

  final String initialQuery;

  @override
  State<BookAvailabilityPage> createState() => _BookAvailabilityPageState();
}

class _BookAvailabilityPageState extends State<BookAvailabilityPage> {
  late final TextEditingController _searchController;

  final List<_BookItem> _books = const [
    _BookItem(
      title: "Operating Systems",
      author: "Silberschatz",
      shelf: "CS-A12",
      isbn: "978-1119800368",
      availableCount: 6,
      description: "Core concepts of process, memory, and file management.",
    ),
    _BookItem(
      title: "Database Systems",
      author: "Ramakrishnan",
      shelf: "CS-B08",
      isbn: "978-0072465631",
      availableCount: 2,
      description: "Relational design, SQL, indexing, and query optimization.",
    ),
    _BookItem(
      title: "Computer Networks",
      author: "Tanenbaum",
      shelf: "CS-A04",
      isbn: "978-0132126953",
      availableCount: 5,
      description: "Architecture and protocols for modern network systems.",
    ),
    _BookItem(
      title: "Clean Code",
      author: "Robert C. Martin",
      shelf: "SE-C11",
      isbn: "978-0132350884",
      availableCount: 1,
      description: "Practical guidance for readable and maintainable code.",
    ),
    _BookItem(
      title: "Distributed Systems",
      author: "Coulouris",
      shelf: "CS-D02",
      isbn: "978-0132143011",
      availableCount: 0,
      description:
          "System models, communication, and distributed coordination.",
    ),
    _BookItem(
      title: "Introduction to Algorithms",
      author: "Cormen",
      shelf: "CS-AL09",
      isbn: "978-0262046305",
      availableCount: 0,
      description: "Comprehensive algorithm design and analysis reference.",
    ),
    _BookItem(
      title: "Data Mining Concepts",
      author: "Han and Kamber",
      shelf: "CS-DM05",
      isbn: "978-0123814791",
      availableCount: 0,
      description: "Classification, clustering, and pattern discovery methods.",
    ),
  ];

  String _query = "";

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim().toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = _books
        .where(
          (book) =>
              book.title.toLowerCase().contains(_query) ||
              book.author.toLowerCase().contains(_query) ||
              book.isbn.toLowerCase().contains(_query),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Book Availability")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: "Search by title, author, or ISBN",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = "";
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredBooks.isEmpty)
            const Card(
              child: ListTile(
                title: Text("No books found"),
                subtitle: Text("Try a different title, author, or ISBN."),
              ),
            ),
          ...filteredBooks.map((book) {
            final available = book.availableCount > 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _showBookDetails(book),
                title: Text(book.title),
                subtitle: Text("${book.author} - Shelf ${book.shelf}"),
                trailing: Chip(
                  label: Text(
                    available
                        ? "Available (${book.availableCount})"
                        : "Unavailable",
                  ),
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

  void _showBookDetails(_BookItem book) {
    final available = book.availableCount > 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text("Author: ${book.author}"),
            Text("ISBN: ${book.isbn}"),
            Text("Shelf: ${book.shelf}"),
            Text(
              available
                  ? "Copies available: ${book.availableCount}"
                  : "Currently unavailable",
            ),
            const SizedBox(height: 10),
            Text(book.description),
            const SizedBox(height: 16),
            if (available)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Issue request sent for ${book.title}.",
                            ),
                          ),
                        );
                      },
                      child: const Text("Issue Book"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text("Reserved ${book.title} for pickup."),
                          ),
                        );
                      },
                      child: const Text("Reserve"),
                    ),
                  ),
                ],
              ),
            if (!available)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text("Added to waiting list for ${book.title}."),
                    ),
                  );
                },
                icon: const Icon(Icons.hourglass_bottom),
                label: const Text("Join Waiting List"),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookItem {
  const _BookItem({
    required this.title,
    required this.author,
    required this.shelf,
    required this.isbn,
    required this.availableCount,
    required this.description,
  });

  final String title;
  final String author;
  final String shelf;
  final String isbn;
  final int availableCount;
  final String description;
}
