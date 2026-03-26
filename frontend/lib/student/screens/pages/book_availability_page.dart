import "dart:async";
import "package:flutter/material.dart";
import "../../../core/services/book_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "book_details_page.dart";

class BookAvailabilityPage extends StatefulWidget {
  const BookAvailabilityPage({super.key, this.initialQuery = ""});

  final String initialQuery;

  @override
  State<BookAvailabilityPage> createState() => _BookAvailabilityPageState();
}

class _BookAvailabilityPageState extends State<BookAvailabilityPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<BookAvailabilityPage> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  bool _isLoading = true;
  String? _error;
  String _query = "";
  List<Map<String, dynamic>> _books = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim();
    _loadBooks();
    startResumeRefresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Future<void> refreshOnResume() => _loadBooks(silent: true);

  Future<void> _loadBooks({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      if (_query.isEmpty) {
        final books = await BookAPI.getBooks();
        if (!mounted) return;
        setState(() {
          _error = null;
          _books = books;
        });
      } else {
        final result = await BookAPI.searchBooks(title: _query);
        final books = List<Map<String, dynamic>>.from(result["books"] ?? []);
        if (!mounted) return;
        setState(() {
          _error = null;
          _books = books;
        });
      }
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _query = value.trim();
    _debounce = Timer(const Duration(milliseconds: 350), _loadBooks);
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  Future<void> _openBookDetails(Map<String, dynamic> book) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookDetailsPage(book: book)),
    );
    if (updated == true) {
      _loadBooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book Availability")),
      body: RefreshIndicator(
        onRefresh: _loadBooks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Browse books and open details to reserve instantly.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search by title",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _query = "";
                          _loadBooks();
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isLoading && _error == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "${_books.length} book(s) found",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text("Failed to load books"),
                  subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadBooks,
                  ),
                ),
              )
            else if (_books.isEmpty)
              const Card(
                child: ListTile(
                  title: Text("No books found"),
                  subtitle: Text("Try a different search term."),
                ),
              )
            else
              ..._books.map((book) {
                final available = _toInt(book["available_copies"]) > 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openBookDetails(book),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 90,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F3D57),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${book["title"] ?? "Untitled"}",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${book["author"] ?? "-"}",
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Shelf ${book["shelf"] ?? "-"}",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 10),
                                Chip(
                                  label: Text(
                                    available
                                        ? "Available (${_toInt(book["available_copies"])})"
                                        : "Waiting only",
                                  ),
                                  backgroundColor: available
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
