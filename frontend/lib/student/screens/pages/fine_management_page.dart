import "package:flutter/material.dart";
import "../../../core/services/library_api.dart";
import "../../../core/services/upi_payment_service.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";
import "../../../core/widgets/app_ui.dart";

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
  final Set<int> _payingFineIds = <int>{};

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

  Future<bool> _confirmPaymentResult({
    required String title,
    required String subtitle,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(subtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Not yet"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Mark as paid"),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _payFine(Map<String, dynamic> fine) async {
    final id = _toInt(fine["id"]);
    final amount = _toDouble(fine["amount"]);
    if (id == 0 || amount <= 0) return;

    setState(() {
      _payingFineIds.add(id);
    });
    try {
      final launched = await UpiPaymentService.launchDemoPayment(
        amount: amount,
        note: "Library fine for ${fine["book_title"] ?? "book"}",
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No UPI app was found on this device.")),
        );
        return;
      }

      final shouldMarkPaid = await _confirmPaymentResult(
        title: "Payment completed?",
        subtitle:
            "After finishing the demo UPI payment and returning here, mark this fine as paid.",
      );
      if (!mounted || !shouldMarkPaid) return;

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
    } finally {
      if (mounted) {
        setState(() {
          _payingFineIds.remove(id);
        });
      }
    }
  }

  Future<void> _payOutstanding() async {
    final unpaid = _fines.where((fine) => !_toBool(fine["is_paid"])).toList();
    if (unpaid.isEmpty) return;

    setState(() {
      _isPayingAll = true;
    });
    try {
      final totalAmount = unpaid.fold<double>(
        0,
        (sum, fine) => sum + _toDouble(fine["amount"]),
      );
      final launched = await UpiPaymentService.launchDemoPayment(
        amount: totalAmount,
        note: "Library outstanding fine payment",
      );
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No UPI app was found on this device.")),
        );
        return;
      }

      final shouldMarkPaid = await _confirmPaymentResult(
        title: "Outstanding payment completed?",
        subtitle:
            "If you completed the demo UPI payment, we will mark all current unpaid fines as paid.",
      );
      if (!mounted || !shouldMarkPaid) return;

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
    final unpaidCount = _fines
        .where((fine) => !_toBool(fine["is_paid"]))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text("Fine Management")),
      bottomNavigationBar: AppActionDock(
        title: "Outstanding: Rs ${outstanding.toStringAsFixed(0)}",
        subtitle: unpaidCount == 0
            ? "You are all caught up."
            : "$unpaidCount fine(s) still need attention.",
        child: FilledButton.icon(
          onPressed: (_isPayingAll || outstanding <= 0)
              ? null
              : _payOutstanding,
          icon: _isPayingAll
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.account_balance_wallet_outlined),
          label: Text(
            _isPayingAll ? "Opening UPI..." : "Pay Outstanding Fine",
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            AppPageHeader(
              title: "Fine overview",
              subtitle:
                  "Review every due amount here and clear your outstanding balance without hunting for the action button.",
              icon: Icons.account_balance_wallet_outlined,
              badges: [
                AppHeaderBadge(
                  label: "Outstanding",
                  value: "Rs ${outstanding.toStringAsFixed(0)}",
                ),
                AppHeaderBadge(label: "Records", value: "$totalRecords"),
              ],
            ),
            const SizedBox(height: 18),
            AppSectionHeader(
              title: "Fine records",
              subtitle: unpaidCount == 0
                  ? "No unpaid fines right now."
                  : "$unpaidCount unpaid fine(s) need action.",
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: "Outstanding",
                    value: "Rs ${outstanding.toStringAsFixed(0)}",
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: "Total Records",
                    value: "$totalRecords",
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AppErrorCard(
                title: "Failed to load fines",
                message: _error!.replaceFirst("Exception: ", ""),
                onRetry: _loadData,
              )
            else if (_fines.isEmpty)
              const AppEmptyStateCard(
                icon: Icons.verified_outlined,
                title: "No fine records found",
                subtitle:
                    "This page will show overdue and penalty charges whenever they are raised.",
              )
            else
              ..._fines.map((fine) {
                final unpaid = !_toBool(fine["is_paid"]);
                final amount = _toDouble(fine["amount"]).toStringAsFixed(0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: unpaid
                                ? Colors.red.withValues(alpha: 0.08)
                                : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            unpaid
                                ? Icons.warning_amber_rounded
                                : Icons.verified_outlined,
                            color: unpaid
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${fine["book_title"] ?? "Library fine"}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    label: Text(
                                      "${fine["fine_type"] ?? "fine"}",
                                    ),
                                  ),
                                  Chip(label: Text("Rs $amount")),
                                  Chip(
                                    label: Text(unpaid ? "Unpaid" : "Paid"),
                                    backgroundColor: unpaid
                                        ? Colors.red.withValues(alpha: 0.08)
                                        : Colors.green.withValues(alpha: 0.1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        unpaid
                            ? FilledButton.tonalIcon(
                                onPressed: _payingFineIds.contains(
                                      _toInt(fine["id"]),
                                    )
                                    ? null
                                    : () => _payFine(fine),
                                icon: _payingFineIds.contains(_toInt(fine["id"]))
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                label: Text(
                                  _payingFineIds.contains(_toInt(fine["id"]))
                                      ? "Opening..."
                                      : "Pay",
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text("Paid"),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
