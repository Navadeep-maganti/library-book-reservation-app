import "package:flutter/material.dart";
import "../../auth/services/auth_service.dart";
import "pages/book_availability_page.dart";
import "pages/book_renewal_page.dart";
import "pages/borrow_history_page.dart";
import "pages/due_alerts_page.dart";
import "pages/fine_management_page.dart";
import "pages/library_announcements_page.dart";
import "pages/notifications_page.dart";
import "pages/token_reservation_page.dart";

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  String _username = "Student";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final username = await AuthService.getUsername();
    if (!mounted) return;
    setState(() {
      _username = username;
    });
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Do you want to logout from this account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  void _openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildOverviewTab(),
      _buildMyBooksTab(),
      _buildFineTab(),
      _buildHistoryTab(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildServicesDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text("Welcome, $_username"),
        actions: [
          IconButton(
            onPressed: () => _openPage(const NotificationsPage()),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: tabs[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: "Overview",
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: "My Books",
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: "Fines",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: "History",
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final actions = [
      _StudentFeature(
        title: "Book Availability",
        subtitle: "Find books instantly",
        icon: Icons.search,
        onTap: () => _openPage(const BookAvailabilityPage()),
      ),
      _StudentFeature(
        title: "Token Reservation",
        subtitle: "Join issue queue",
        icon: Icons.confirmation_num_outlined,
        onTap: () => _openPage(const TokenReservationPage()),
      ),
      _StudentFeature(
        title: "Fine Management",
        subtitle: "Track and clear dues",
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => _openPage(const FineManagementPage()),
      ),
      _StudentFeature(
        title: "Due Alerts",
        subtitle: "See upcoming due dates",
        icon: Icons.notifications_active_outlined,
        onTap: () => _openPage(const DueAlertsPage()),
      ),
      _StudentFeature(
        title: "Book Renewal",
        subtitle: "Renew borrowed books",
        icon: Icons.autorenew,
        onTap: () => _openPage(const BookRenewalPage()),
      ),
      _StudentFeature(
        title: "Borrow History",
        subtitle: "View past borrows",
        icon: Icons.history,
        onTap: () => _openPage(const BorrowHistoryPage()),
      ),
      _StudentFeature(
        title: "Announcements",
        subtitle: "Latest library updates",
        icon: Icons.campaign_outlined,
        onTap: () => _openPage(const LibraryAnnouncementsPage()),
      ),
    ];

    return ListView(
      key: const ValueKey("overview"),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3D57), Color(0xFF3A6EA5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Library Services Hub",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Manage borrowing, renewals, dues, and updates from one place.",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: _MetricCard(label: "Books Issued", value: "3"),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricCard(label: "Due This Week", value: "2"),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MetricCard(label: "Pending Fine", value: "Rs 60"),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Quick Access",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) =>
              _FeatureCard(feature: actions[index]),
        ),
      ],
    );
  }

  Widget _buildMyBooksTab() {
    final activeBorrows = const [
      ("Operating Systems", "Due in 1 day"),
      ("Database Systems", "Due in 3 days"),
      ("Computer Networks", "Due in 5 days"),
    ];
    return ListView(
      key: const ValueKey("my_books"),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Current Borrowed Books",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...activeBorrows.map(
          (book) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(book.$1),
              subtitle: Text(book.$2),
              trailing: FilledButton.tonal(
                onPressed: () => _openPage(const BookRenewalPage()),
                child: const Text("Renew"),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _openPage(const DueAlertsPage()),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text("Due Alerts"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _openPage(const BorrowHistoryPage()),
                icon: const Icon(Icons.history),
                label: const Text("History"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFineTab() {
    final fines = const [
      ("Operating Systems", "3 days late", 45.0, "Unpaid"),
      ("Clean Architecture", "2 days late", 30.0, "Paid"),
      ("Data Warehousing", "1 day late", 15.0, "Unpaid"),
    ];
    final pending = fines
        .where((f) => f.$4 == "Unpaid")
        .fold<double>(0, (sum, item) => sum + item.$3);

    return ListView(
      key: const ValueKey("fines"),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Outstanding Fine: Rs ${pending.toStringAsFixed(0)}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        ...fines.map(
          (fine) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(fine.$1),
              subtitle: Text("${fine.$2}  •  Rs ${fine.$3.toStringAsFixed(0)}"),
              trailing: Chip(
                label: Text(fine.$4),
                backgroundColor: fine.$4 == "Unpaid"
                    ? Colors.red.shade50
                    : Colors.green.shade50,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _openPage(const FineManagementPage()),
          child: const Text("Open Fine Management"),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      key: const ValueKey("history"),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Borrow History",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...const [
          ("Clean Code", "Issued: 02 Jan 2026", "Returned: 15 Jan 2026"),
          ("Database Systems", "Issued: 10 Jan 2026", "Returned: 25 Jan 2026"),
          ("Operating Systems", "Issued: 11 Feb 2026", "Not Returned"),
        ].map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(item.$1),
              subtitle: Text("${item.$2}\n${item.$3}"),
              isThreeLine: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => _openPage(const BorrowHistoryPage()),
          child: const Text("Open Detailed History"),
        ),
      ],
    );
  }

  Widget _buildServicesDrawer() {
    final services = [
      ("Book Availability", Icons.search, const BookAvailabilityPage()),
      (
        "Token Reservation",
        Icons.confirmation_num_outlined,
        const TokenReservationPage(),
      ),
      (
        "Fine Management",
        Icons.account_balance_wallet_outlined,
        const FineManagementPage(),
      ),
      (
        "Due Alerts",
        Icons.notifications_active_outlined,
        const DueAlertsPage(),
      ),
      ("Book Renewal", Icons.autorenew, const BookRenewalPage()),
      ("Borrow History", Icons.history, const BorrowHistoryPage()),
      (
        "Library Announcements",
        Icons.campaign_outlined,
        const LibraryAnnouncementsPage(),
      ),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              accountName: Text(_username),
              accountEmail: const Text("Student Account"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _username.isNotEmpty ? _username[0].toUpperCase() : "S",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: services
                    .map(
                      (service) => ListTile(
                        leading: Icon(service.$2),
                        title: Text(service.$1),
                        onTap: () {
                          Navigator.pop(context);
                          _openPage(service.$3);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () async {
                Navigator.pop(context);
                await _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _StudentFeature {
  const _StudentFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _StudentFeature feature;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: feature.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEAF3FF),
                child: Icon(feature.icon, color: const Color(0xFF1A5D9D)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feature.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
