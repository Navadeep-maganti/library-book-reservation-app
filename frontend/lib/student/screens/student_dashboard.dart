import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String todayDate() {
  return DateFormat('EEEE, MMM d').format(DateTime.now());
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 👤 Profile Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),

                  const SizedBox(width: 12),

                  // 📅 Dynamic Date + Welcome Text
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayDate(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Welcome, Student",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: "Search books by title or author",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Book List Title
            const Text(
              "Available Books",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // Book List
            Expanded(
              child: ListView(
                children: const [
                  BookCard(
                    title: "Operating Systems",
                    author: "Silberschatz",
                    available: true,
                  ),
                  BookCard(
                    title: "Database Management Systems",
                    author: "Ramakrishnan",
                    available: false,
                  ),
                  BookCard(
                    title: "Computer Networks",
                    author: "Andrew S. Tanenbaum",
                    available: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookCard extends StatelessWidget {
  final String title;
  final String author;
  final bool available;

  const BookCard({
    super.key,
    required this.title,
    required this.author,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Author: $author"),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  available ? "Available" : "Not Available",
                  style: TextStyle(
                    color: available ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: available ? () {} : null,
                  child: const Text("Reserve"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
