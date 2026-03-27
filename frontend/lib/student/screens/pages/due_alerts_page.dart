import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";

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
            AppPageHeader(
              title: "Due alerts",
              subtitle:
                  "Stay ahead of return deadlines and spot overdue books before fines stack up.",
              icon: Icons.notifications_active_outlined,
              badges: [
                AppHeaderBadge(
                  label: "Due today",
                  value: "${_toInt(summary["num_due_today"])}",
                ),
                AppHeaderBadge(
                  label: "Due soon",
                  value: "${_toInt(summary["num_due_soon"])}",
                ),
                AppHeaderBadge(
                  label: "Overdue",
                  value: "${_toInt(summary["num_overdue"])}",
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppErrorCard(
                title: "Failed to load due alerts",
                message: _error!.replaceFirst("Exception: ", ""),
                onRetry: _loadAlerts,
              )
            else if (items.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.task_alt_outlined,
                title: "No due alerts at the moment",
                subtitle:
                    "You do not have any items nearing their due date right now.",
              )
            else
              ...items.map((item) {
                final detail =
                    (item["book_detail"] as Map<String, dynamic>?) ?? {};
                final dueText = _dueLabel(item["due_date"]);
                final isOverdue = dueText.toLowerCase().contains("overdue");
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withValues(alpha: 0.08)
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule,
                            color: isOverdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${detail["title"] ?? "Untitled"}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  isOverdue
                                      ? "Needs return now"
                                      : "Upcoming due date",
                                ),
                                backgroundColor: isOverdue
                                    ? Colors.red.withValues(alpha: 0.08)
                                    : Colors.orange.withValues(alpha: 0.12),
                              ),
                              const SizedBox(height: 8),
                              Text(dueText),
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
