import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<NotificationsPage> {
  bool _isLoading = true;
  bool _isMarkingAllRead = false;
  String? _error;
  List<Map<String, dynamic>> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    startResumeRefresh();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final items = await NotificationAPI.getNotifications();
      if (!mounted) return;
      setState(() {
        _error = null;
        _notifications = items;
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
  Future<void> refreshOnResume() => _loadNotifications(silent: true);

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    return "$value".toLowerCase() == "true";
  }

  String _formatTime(dynamic value) {
    final dt = DateTime.tryParse("$value");
    if (dt == null) return "";
    return DateFormat("dd MMM, hh:mm a").format(dt.toLocal());
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    if (_toBool(item["is_read"])) return;
    final id = int.tryParse("${item["id"]}") ?? 0;
    if (id == 0) return;
    try {
      await NotificationAPI.markRead(id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) {
          if ("${n["id"]}" == "$id") {
            return {...n, "is_read": true};
          }
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead ||
        _notifications.every((item) => _toBool(item["is_read"]))) {
      return;
    }

    setState(() {
      _isMarkingAllRead = true;
    });
    try {
      await NotificationAPI.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => {...item, "is_read": true})
            .toList();
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAllRead = false;
        });
      }
    }
  }

  int get _unreadCount =>
      _notifications.where((item) => !_toBool(item["is_read"])).length;

  Color _typeColor(String type) {
    switch (type) {
      case "overdue_alert":
      case "fine_alert":
        return Colors.red.shade700;
      case "reservation_ready":
      case "waiting_list":
        return Colors.orange.shade800;
      case "announcement":
        return Colors.indigo.shade700;
      case "book_issued":
      case "book_returned":
        return Colors.green.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case "announcement":
        return Icons.campaign_outlined;
      case "reservation_ready":
      case "waiting_list":
        return Icons.hourglass_bottom_outlined;
      case "due_reminder":
      case "overdue_alert":
        return Icons.schedule;
      case "fine_alert":
        return Icons.account_balance_wallet_outlined;
      case "book_returned":
        return Icons.assignment_turned_in_outlined;
      case "book_issued":
        return Icons.menu_book_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          TextButton(
            onPressed: _isMarkingAllRead ? null : _markAllAsRead,
            child: _isMarkingAllRead
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Mark all read"),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isLoading && _error == null) ...[
              AppPageHeader(
                title: "Notifications",
                subtitle:
                    "Library activity, reservation updates, reminders, and announcements all land here.",
                icon: Icons.notifications_active_outlined,
                badges: [
                  AppHeaderBadge(
                    label: "Total",
                    value: "${_notifications.length}",
                  ),
                  AppHeaderBadge(label: "Unread", value: "$_unreadCount"),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (!_isLoading && _error == null)
              AppSectionHeader(
                title: "Recent updates",
                subtitle: _unreadCount == 0
                    ? "Everything has been read."
                    : "$_unreadCount unread notification(s) still need attention.",
              ),
            if (!_isLoading && _error == null) const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppErrorCard(
                title: "Failed to load notifications",
                message: _error!.replaceFirst("Exception: ", ""),
                onRetry: _loadNotifications,
              )
            else if (_notifications.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.notifications_off_outlined,
                title: "No notifications available",
                subtitle:
                    "Once the library sends updates or reminders, they will show up here.",
              )
            else
              ..._notifications.map((item) {
                final isRead = _toBool(item["is_read"]);
                final type = "${item["notification_type"] ?? "system"}";
                final typeLabel =
                    "${item["notification_type_display"] ?? "Update"}";
                final chipColor = _typeColor(type);
                final bookTitle = "${item["book_title"] ?? ""}".trim();
                return Card(
                  color: isRead ? null : Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _markAsRead(item),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: chipColor.withValues(alpha: 0.1),
                      child: Icon(_typeIcon(type), color: chipColor),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${item["title"] ?? "Notification"}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  color: chipColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (bookTitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              bookTitle,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text("${item["message"] ?? ""}"),
                    ),
                    trailing: Text(
                      _formatTime(item["created_at"]),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
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
