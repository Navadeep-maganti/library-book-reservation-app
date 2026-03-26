import "package:flutter/material.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";

class FineManagementPage extends StatefulWidget {
  const FineManagementPage({super.key});

  @override
  State<FineManagementPage> createState() => _FineManagementPageState();
}

class _FineManagementPageState extends State<FineManagementPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<FineManagementPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _fines = const [];
  Map<String, dynamic> _summary = const {};
  bool _isPayingAll = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    startResumeRefresh();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final fines = await FineAPI.getFines();
      final summary = await FineAPI.getFineSummary();
      if (!mounted) return;
      setState(() {
        _error = null;
        _fines = fines;
        _summary = summary;
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
  Future<void> refreshOnResume() => _loadData(silent: true);

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    return "$value".toLowerCase() == "true";
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse("$value") ?? 0;
  }

  Future<void> _payFine(Map<String, dynamic> fine) async {
    final id = _toInt(fine["id"]);
    final amount = _toDouble(fine["amount"]);
    if (id == 0 || amount <= 0) return;

    try {
      await FineAPI.payFine(id, amountPaid: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Fine payment successful.")));
      _loadData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<void> _payOutstanding() async {
    final unpaid = _fines.where((fine) => !_toBool(fine["is_paid"])).toList();
    if (unpaid.isEmpty) return;

    setState(() {
      _isPayingAll = true;
    });
    try {
      for (final fine in unpaid) {
        await FineAPI.payFine(
          _toInt(fine["id"]),
          amountPaid: _toDouble(fine["amount"]),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All outstanding fines paid.")),
      );
      _loadData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPayingAll = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = _toDouble(_summary["total_outstanding"]);
    final totalRecords = _toInt(_summary["num_total_fines"]);

    return Scaffold(
      appBar: AppBar(title: const Text("Fine Management")),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: "Outstanding",
                    value: "Rs ${outstanding.toStringAsFixed(0)}",
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: "Total Records",
                    value: "$totalRecords",
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text("Failed to load fines"),
                  subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadData,
                  ),
                ),
              )
            else if (_fines.isEmpty)
              const Card(child: ListTile(title: Text("No fine records found")))
            else
              ..._fines.map((fine) {
                final unpaid = !_toBool(fine["is_paid"]);
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text("${fine["book_title"] ?? "Library fine"}"),
                    subtitle: Text(
                      "${fine["fine_type"] ?? "fine"} | Rs ${_toDouble(fine["amount"]).toStringAsFixed(0)}",
                    ),
                    trailing: unpaid
                        ? FilledButton.tonal(
                            onPressed: () => _payFine(fine),
                            child: const Text("Pay"),
                          )
                        : Chip(
                            label: const Text("Paid"),
                            backgroundColor: Colors.green.shade50,
                          ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_isPayingAll || outstanding <= 0)
                  ? null
                  : _payOutstanding,
              child: _isPayingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Pay Outstanding Fine"),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
