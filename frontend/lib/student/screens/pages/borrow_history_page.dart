import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";

class BorrowHistoryPage extends StatefulWidget {
  const BorrowHistoryPage({super.key});

  @override
  State<BorrowHistoryPage> createState() => _BorrowHistoryPageState();
}

class _BorrowHistoryPageState extends State<BorrowHistoryPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<BorrowHistoryPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    startResumeRefresh();
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await BorrowHistoryAPI.getBorrowHistory();
      if (!mounted) return;
      setState(() {
        _error = null;
        _history = data;
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

  @override
  Future<void> refreshOnResume() => _loadHistory(silent: true);

  String _fmtDate(dynamic value) {
    final dt = DateTime.tryParse("$value");
    if (dt == null) return "-";
    return DateFormat("dd MMM yyyy").format(dt.toLocal());
  }

  String _returnedLabel(Map<String, dynamic> item) {
    final hasReturnDate = item["return_date"] != null;
    final isReturned = "${item["status"] ?? ""}".toLowerCase() == "returned";
    if (!isReturned) {
      return "Not Returned";
    }
    if (hasReturnDate) {
      return _fmtDate(item["return_date"]);
    }
    return "Returned";
  }

  @override
  Widget build(BuildContext context) {
    final returnedCount = _history
        .where((item) => "${item["status"] ?? ""}".toLowerCase() == "returned")
        .length;
    final activeCount = _history.length - returnedCount;

    return Scaffold(
      appBar: AppBar(title: const Text("Borrow History")),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppPageHeader(
              title: "Borrow history",
              subtitle:
                  "Track your active issues and previously returned books in one timeline.",
              icon: Icons.history_rounded,
              badges: [
                AppHeaderBadge(label: "Active", value: "$activeCount"),
                AppHeaderBadge(label: "Returned", value: "$returnedCount"),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppErrorCard(
                title: "Failed to load history",
                message: _error!.replaceFirst("Exception: ", ""),
                onRetry: _loadHistory,
              )
            else if (_history.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.history_toggle_off_outlined,
                title: "No borrow history found",
                subtitle:
                    "Borrowed and returned books will start appearing here once you begin using the library.",
              )
            else
              ..._history.map((item) {
                final status = "${item["status"] ?? ""}";
                final isReturned = status.toLowerCase() == "returned";
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isReturned
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isReturned
                                ? Icons.check_circle_outline
                                : Icons.schedule,
                            color: isReturned
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${item["book_title"] ?? "Untitled"}",
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Chip(
                                    label: Text(
                                      isReturned ? "Returned" : "Active",
                                    ),
                                    backgroundColor: isReturned
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Issued: ${_fmtDate(item["issue_date"])}",
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Return: ${_returnedLabel(item)}",
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
