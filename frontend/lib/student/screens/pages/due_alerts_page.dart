import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";

class DueAlertsPage extends StatefulWidget {
  const DueAlertsPage({super.key});

  @override
  State<DueAlertsPage> createState() => _DueAlertsPageState();
}

class _DueAlertsPageState extends State<DueAlertsPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<DueAlertsPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = const {};

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    startResumeRefresh();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final result = await DueAlertsAPI.getDueAlerts(days: 7);
      if (!mounted) return;
      setState(() {
        _error = null;
        _data = result;
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
  Future<void> refreshOnResume() => _loadAlerts(silent: true);

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  String _dueLabel(dynamic value) {
    final dt = DateTime.tryParse("$value");
    if (dt == null) return "Due date unavailable";
    final local = dt.toLocal();
    final days = local.difference(DateTime.now()).inDays;
    if (days < 0) return "Overdue by ${days.abs()} day(s)";
    if (days == 0) return "Due today";
    return "Due in $days day(s) (${DateFormat("dd MMM yyyy").format(local)})";
  }

  List<Map<String, dynamic>> _combineItems() {
    final dueSoon = List<Map<String, dynamic>>.from(
      _data["due_this_week"] ?? const [],
    );
    final overdue = List<Map<String, dynamic>>.from(
      _data["overdue"] ?? const [],
    );
    return [...overdue, ...dueSoon];
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_data["summary"] as Map<String, dynamic>?) ?? {};
    final items = _combineItems();

    return Scaffold(
      appBar: AppBar(title: const Text("Due Alerts")),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text("This Week Summary"),
                subtitle: Text(
                  "Due today: ${_toInt(summary["num_due_today"])}  |  "
                  "Due soon: ${_toInt(summary["num_due_soon"])}  |  "
                  "Overdue: ${_toInt(summary["num_overdue"])}",
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text("Failed to load due alerts"),
                  subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadAlerts,
                  ),
                ),
              )
            else if (items.isEmpty)
              const Card(
                child: ListTile(title: Text("No due alerts at the moment")),
              )
            else
              ...items.map((item) {
                final detail =
                    (item["book_detail"] as Map<String, dynamic>?) ?? {};
                final dueText = _dueLabel(item["due_date"]);
                final isOverdue = dueText.toLowerCase().contains("overdue");
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOverdue
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                      child: Icon(
                        isOverdue
                            ? Icons.warning_amber_rounded
                            : Icons.schedule,
                        color: isOverdue ? Colors.red : Colors.orange.shade800,
                      ),
                    ),
                    title: Text("${detail["title"] ?? "Untitled"}"),
                    subtitle: Text(dueText),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
