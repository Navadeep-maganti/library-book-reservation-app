import "dart:async";

import "package:flutter/material.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";

class WaitingListPage extends StatelessWidget {
  const WaitingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reservations")),
      body: const WaitingListPageBody(),
    );
  }
}

class WaitingListPageBody extends StatefulWidget {
  const WaitingListPageBody({super.key});

  @override
  State<WaitingListPageBody> createState() => _WaitingListPageBodyState();
}

class _WaitingListPageBodyState extends State<WaitingListPageBody>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<WaitingListPageBody> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _loadReservations();
    startResumeRefresh();
  }

  Future<void> _loadReservations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final reservations = await ReservationAPI.getReservations();
      if (!mounted) return;
      setState(() {
        _error = null;
        _items = reservations.where((item) {
          final status = "${item["status"] ?? ""}".toLowerCase();
          return status == "pending" || status == "notified";
        }).toList();
      });
      _syncHoldTimer();
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
  Future<void> refreshOnResume() => _loadReservations(silent: true);

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse("$value")?.toLocal();
  }

  int? _holdMinutesLeft(Map<String, dynamic> item) {
    final expiresAt = _toDateTime(item["expected_available_date"]);
    if (expiresAt == null) return null;

    final secondsLeft = expiresAt.difference(DateTime.now()).inSeconds;
    if (secondsLeft <= 0) return 0;
    return (secondsLeft / 60).ceil();
  }

  bool _hasActiveHold(Map<String, dynamic> item) {
    return "${item["status"] ?? ""}".toLowerCase() == "notified" &&
        _toDateTime(item["expected_available_date"]) != null;
  }

  bool get _hasNotifiedReservations => _items.any(_hasActiveHold);

  bool get _hasExpiredNotifiedReservation => _items.any((item) {
    final expiresAt = _toDateTime(item["expected_available_date"]);
    return _hasActiveHold(item) &&
        expiresAt != null &&
        !expiresAt.isAfter(DateTime.now());
  });

  List<Map<String, dynamic>> get _pickupReservations =>
      _items.where((item) => _hasActiveHold(item)).toList();

  List<Map<String, dynamic>> get _queueEntries => _items.where((item) {
    final status = "${item["status"] ?? ""}".toLowerCase();
    return status == "pending";
  }).toList();

  void _syncHoldTimer() {
    _holdTimer?.cancel();
    if (!_hasNotifiedReservations) {
      return;
    }

    _holdTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_hasExpiredNotifiedReservation) {
        _loadReservations(silent: true);
        return;
      }
      setState(() {});
    });
  }

  Future<void> _leaveReservation(Map<String, dynamic> item) async {
    final status = "${item["status"] ?? ""}".toLowerCase();
    final title =
        (item["book_detail"] as Map<String, dynamic>?)?["title"] ?? "book";
    try {
      await ReservationAPI.cancelReservation(_toInt(item["id"]));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == "notified"
                ? 'Cancelled pickup reservation for "$title".'
                : 'Removed "$title" from the waiting list.',
          ),
        ),
      );
      _loadReservations(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeHolds = _pickupReservations.length;
    final queueEntries = _queueEntries.length;

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppPageHeader(
            title: "Reservations",
            subtitle:
                "Track pickup-ready reservations and waiting-list requests separately so each item shows the right status and action.",
            icon: Icons.hourglass_bottom_outlined,
            badges: [
              AppHeaderBadge(label: "All active", value: "${_items.length}"),
              AppHeaderBadge(label: "Ready to pick up", value: "$activeHolds"),
              AppHeaderBadge(label: "In queue", value: "$queueEntries"),
            ],
          ),
          const SizedBox(height: 14),
          const AppInfoBanner(
            icon: Icons.lock_clock_outlined,
            message:
                "When a reserved book becomes available, it is held for 30 minutes. If it is not issued in time, the hold expires and the next eligible reader is notified.",
            color: Color(0xFFD97706),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            AppErrorCard(
              title: "Failed to load reservations",
              message: _error!.replaceFirst("Exception: ", ""),
              onRetry: _loadReservations,
            )
          else if (_items.isEmpty)
            const AppEmptyStateCard(
              icon: Icons.library_add_check_outlined,
              title: "No active reservations",
              subtitle:
                  "Pickup-ready holds and waiting-list entries will appear here when you reserve a book.",
            )
          else ...[
            if (_pickupReservations.isNotEmpty) ...[
              const AppSectionHeader(
                title: "Ready for pickup",
                subtitle:
                    "These books are reserved for you right now. Collect them before the hold expires.",
              ),
              const SizedBox(height: 12),
              ..._pickupReservations.map((item) {
                final detail =
                    (item["book_detail"] as Map<String, dynamic>?) ?? {};
                final holdMinutes = _holdMinutesLeft(item) ?? 0;
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
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.lock_clock_outlined,
                            color: Color(0xFF15803D),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: const Text("Pickup hold active"),
                                    backgroundColor: Colors.green.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      "Reserved for $holdMinutes minute(s)",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Issue this book from the librarian before the timer ends.",
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _leaveReservation(item),
                                icon: const Icon(Icons.close),
                                label: const Text("Cancel reservation"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            if (_queueEntries.isNotEmpty) ...[
              const AppSectionHeader(
                title: "Waiting list",
                subtitle:
                    "These requests are still in queue and will move to pickup-ready once a copy becomes available.",
              ),
              const SizedBox(height: 12),
              ..._queueEntries.map((item) {
                final detail =
                    (item["book_detail"] as Map<String, dynamic>?) ?? {};
                final estimatedDays = item["estimated_days"];
                final estimateText = estimatedDays == null
                    ? "Estimated: unavailable"
                    : "Estimated: $estimatedDays day(s)";
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
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.hourglass_bottom_outlined,
                            color: Color(0xFFB45309),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: const Text("Queued"),
                                    backgroundColor: Colors.orange.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      "Position ${_toInt(item["queue_position"])}",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(estimateText),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _leaveReservation(item),
                                icon: const Icon(Icons.close),
                                label: const Text("Leave waiting list"),
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
          ],
        ],
      ),
    );
  }
}
