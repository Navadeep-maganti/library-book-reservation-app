import "package:flutter/material.dart";
import "../../../core/services/library_api.dart";

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({super.key, required this.book});

  final Map<String, dynamic> book;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  bool _submitting = false;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  Future<void> _reserveBook() async {
    if (_submitting) return;
    final id = _toInt(widget.book["id"]);
    final title = "${widget.book["title"] ?? "book"}";

    setState(() {
      _submitting = true;
    });
    try {
      final response = await ReservationAPI.makeReservation(id);
      if (!mounted) return;
      final status = "${response["status"] ?? ""}".toLowerCase();
      final message = status == "notified"
          ? "\"$title\" reserved. You have 30 minutes to collect it."
          : "\"$title\" added to waiting list.";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.book["title"] ?? "Untitled"}";
    final author = "${widget.book["author"] ?? "-"}";
    final shelf = "${widget.book["shelf"] ?? "-"}";
    final category = "${widget.book["category"] ?? "-"}";
    final isbn = "${widget.book["isbn"] ?? "-"}";
    final description = "${widget.book["description"] ?? "No description available."}";
    final totalCopies = _toInt(widget.book["total_copies"]);
    final availableCopies = _toInt(widget.book["available_copies"]);
    final available = availableCopies > 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Book Details")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: const Color(0xFF0F3D57),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 84),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(author, style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text("Shelf: $shelf")),
              Chip(label: Text("Category: $category")),
              Chip(label: Text("ISBN: $isbn")),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Availability",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                available ? Icons.check_circle : Icons.hourglass_bottom,
                color: available ? Colors.green : Colors.orange,
              ),
              title: Text(available ? "Available now" : "Currently unavailable"),
              subtitle: Text("Copies: $availableCopies / $totalCopies"),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Description",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _reserveBook,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_clock_outlined),
            label: Text(
              available
                  ? "Reserve for 30 minutes"
                  : "Join waiting list",
            ),
          ),
        ],
      ),
    );
  }
}
