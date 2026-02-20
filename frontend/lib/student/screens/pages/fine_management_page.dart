import "package:flutter/material.dart";

class FineManagementPage extends StatelessWidget {
  const FineManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fines = const [
      ("Operating Systems", "3 days late", 45.0, "Unpaid"),
      ("Clean Architecture", "2 days late", 30.0, "Paid"),
      ("Data Warehousing", "1 day late", 15.0, "Unpaid"),
    ];

    final pending = fines
        .where((f) => f.$4 == "Unpaid")
        .fold<double>(0, (sum, item) => sum + item.$3);

    return Scaffold(
      appBar: AppBar(title: const Text("Fine Management")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: "Outstanding",
                  value: "Rs ${pending.toStringAsFixed(0)}",
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _SummaryCard(
                  title: "Total Records",
                  value: "3",
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...fines.map((fine) {
            final unpaid = fine.$4 == "Unpaid";
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(fine.$1),
                subtitle: Text(
                  "${fine.$2}  •  Rs ${fine.$3.toStringAsFixed(0)}",
                ),
                trailing: Chip(
                  label: Text(fine.$4),
                  backgroundColor: unpaid
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {},
            child: const Text("Pay Outstanding Fine"),
          ),
        ],
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
