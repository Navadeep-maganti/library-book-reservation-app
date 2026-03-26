import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";

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
    return Scaffold(
      appBar: AppBar(title: const Text("Borrow History")),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text("Failed to load history"),
                  subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadHistory,
                  ),
                ),
              )
            else if (_history.isEmpty)
              const Card(
                child: ListTile(title: Text("No borrow history found")),
              )
            else
              ..._history.map((item) {
                final status = "${item["status"] ?? ""}";
                final isReturned = status.toLowerCase() == "returned";
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isReturned
                          ? Colors.green.shade50
                          : Colors.amber.shade100,
                      child: Icon(
                        isReturned ? Icons.check_circle_outline : Icons.schedule,
                        color: isReturned
                            ? Colors.green.shade700
                            : Colors.amber.shade800,
                      ),
                    ),
                    title: Text("${item["book_title"] ?? "Untitled"}"),
                    subtitle: Text(
                      "Issued: ${_fmtDate(item["issue_date"])}\n"
                      "Returned: ${_returnedLabel(item)}",
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(isReturned ? "Returned" : "Active"),
                      backgroundColor: isReturned
                          ? Colors.green.shade50
                          : Colors.amber.shade100,
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
