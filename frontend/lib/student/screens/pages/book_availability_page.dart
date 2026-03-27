import "dart:async";
import "package:flutter/material.dart";
import "../../../core/services/book_api.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";
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
  Map<String, dynamic> _activeItemLimit = const {};

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
      final results = await Future.wait<Object>([
        _query.isEmpty
            ? BookAPI.getBooks()
            : BookAPI.searchBooks(title: _query),
        DashboardAPI.getDashboardSummary().catchError(
          (_) => const <String, dynamic>{},
        ),
      ]);
      final booksResult = results[0];
      final books = booksResult is List<Map<String, dynamic>>
          ? booksResult
          : List<Map<String, dynamic>>.from(
              (booksResult as Map<String, dynamic>)["books"] ?? const [],
            );
      final summary = Map<String, dynamic>.from(results[1] as Map);
      final activeItemLimit = Map<String, dynamic>.from(
        (summary["active_item_limit"] as Map<String, dynamic>?) ?? const {},
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _books = books;
        _activeItemLimit = activeItemLimit;
      });
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

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    return "$value".toLowerCase() == "true";
  }

  bool get _canReserveMore {
    if (_activeItemLimit.isEmpty) {
      return true;
    }
    return _toBool(_activeItemLimit["can_reserve_more"]);
  }

  String? get _reservationDisabledMessage {
    if (_canReserveMore) {
      return null;
    }
    final message = "${_activeItemLimit["message"] ?? ""}".trim();
    if (message.isNotEmpty) {
      return message;
    }
    final totalActive = _toInt(_activeItemLimit["total_active"]);
    final maxAllowed = _toInt(_activeItemLimit["max_allowed"]);
    return "You already have $totalActive active item(s). The limit is $maxAllowed.";
  }

  Future<void> _openBookDetails(Map<String, dynamic> book) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailsPage(
          book: book,
          reservationDisabledMessage: _reservationDisabledMessage,
        ),
      ),
    );
    if (updated == true) {
      _loadBooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _books
        .where((book) => _toInt(book["available_copies"]) > 0)
        .length;
    final waitingCount = _books.length - availableCount;

    return Scaffold(
      appBar: AppBar(title: const Text("Book Availability")),
      body: RefreshIndicator(
        onRefresh: _loadBooks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppPageHeader(
              title: "Browse the catalog",
              subtitle:
                  "Search by title, inspect availability, and open any book to reserve it or join the waiting list.",
              icon: Icons.library_books_outlined,
              badges: [
                AppHeaderBadge(label: "Results", value: "${_books.length}"),
                AppHeaderBadge(label: "Ready now", value: "$availableCount"),
              ],
            ),
            const SizedBox(height: 14),
            if (!_isLoading && _error == null && !_canReserveMore) ...[
              AppInfoBanner(
                icon: Icons.info_outline,
                message: _reservationDisabledMessage!,
                color: const Color(0xFFB45309),
              ),
              const SizedBox(height: 14),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
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
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _CatalogSummaryCard(
                            title: "Ready now",
                            value: "$availableCount",
                            color: const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CatalogSummaryCard(
                            title: "Waiting only",
                            value: "$waitingCount",
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isLoading && _error == null)
              AppSectionHeader(
                title: "${_books.length} book(s) found",
                subtitle: _query.isEmpty
                    ? "Showing the full collection."
                    : "Filtered results for your search.",
              ),
            if (!_isLoading && _error == null) const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppErrorCard(
                title: "Failed to load books",
                message: _error!.replaceFirst("Exception: ", ""),
                onRetry: _loadBooks,
              )
            else if (_books.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.search_off_outlined,
                title: "No books found",
                subtitle: "Try another title keyword to see matching books.",
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
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const AppBookCover(width: 60, height: 82),
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
                                  "by ${book["author"] ?? "-"}",
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Shelf ${book["shelf"] ?? "-"}",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        available
                                            ? "Available (${_toInt(book["available_copies"])})"
                                            : "Waiting only",
                                      ),
                                      backgroundColor: available
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(
                                              alpha: 0.12,
                                            ),
                                    ),
                                    if (!_canReserveMore)
                                      Chip(
                                        label: const Text(
                                          "Reservation limit reached",
                                        ),
                                        backgroundColor: Colors.red.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF1D4ED8),
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

class _CatalogSummaryCard extends StatelessWidget {
  const _CatalogSummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
