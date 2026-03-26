import "dart:async";

import "package:flutter/material.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";

class WaitingListPage extends StatelessWidget {
  const WaitingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Waiting List")),
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
    try {
      await ReservationAPI.cancelReservation(_toInt(item["id"]));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Removed ${(item["book_detail"] as Map<String, dynamic>?)?["title"] ?? "book"} from waiting list.",
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
    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: const Text(
              "When a reserved book becomes available, it is held for 30 minutes. If not collected, it returns to available stock.",
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Card(
              child: ListTile(
                title: const Text("Failed to load waiting list"),
                subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReservations,
                ),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              child: ListTile(title: Text("No active waiting list items")),
            )
          else
            ..._items.map((item) {
              final detail =
                  (item["book_detail"] as Map<String, dynamic>?) ?? {};
              final status = "${item["status"] ?? ""}".toLowerCase();
              final holdMinutes = _holdMinutesLeft(item) ?? 0;
              final estimatedDays = item["estimated_days"];
              final estimateText = status == "notified"
                  ? "Reserved for pickup: $holdMinutes minute(s) left"
                  : estimatedDays == null
                  ? "Estimated: unavailable"
                  : "Estimated: $estimatedDays day(s)";
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    status == "notified"
                        ? Icons.lock_clock_outlined
                        : Icons.hourglass_bottom_outlined,
                  ),
                  title: Text("${detail["title"] ?? "Untitled"}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text("Position: ${_toInt(item["queue_position"])}"),
                      Text(estimateText),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: () => _leaveReservation(item),
                    child: const Text("Leave"),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
