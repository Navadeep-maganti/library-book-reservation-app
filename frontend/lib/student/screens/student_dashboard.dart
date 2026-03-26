import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../auth/services/auth_service.dart";
import "../../core/services/app_notification_service.dart";
import "../../core/services/book_api.dart";
import "../../core/services/borrowing_api.dart";
import "../../core/services/library_api.dart";
import "../../core/utils/resume_refresh_state_mixin.dart";
import "pages/book_availability_page.dart";
import "pages/borrow_history_page.dart";
import "pages/due_alerts_page.dart";
import "pages/fine_management_page.dart";
import "pages/library_announcements_page.dart";
import "pages/notifications_page.dart";
import "pages/waiting_list_page.dart";

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<StudentDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  int _currentIndex = 0;
  String _username = "Student";
  String _searchQuery = "";
  bool _isLoading = true;
  String? _error;
  int _unreadNotifications = 0;

  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _myBooks = const [];
  List<Map<String, dynamic>> _fines = const [];
  List<Map<String, dynamic>> _history = const [];
  List<Map<String, dynamic>> _catalog = const [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDashboardData();
    startResumeRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final username = await AuthService.getUsername();
    if (!mounted) return;
    setState(() {
      _username = username;
    });
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        DashboardAPI.getDashboardSummary().catchError((_) => _summary),
        BorrowingAPI.getMyBooks().catchError((_) => _myBooks),
        FineAPI.getFines().catchError((_) => _fines),
        BorrowHistoryAPI.getBorrowHistory().catchError((_) => _history),
        BookAPI.getBooks().catchError((_) => _catalog),
        NotificationAPI.getUnreadCount().catchError(
          (_) => {"unread_count": _unreadNotifications},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _error = null;
        _summary = results[0] as Map<String, dynamic>;
        _myBooks = results[1] as List<Map<String, dynamic>>;
        _fines = results[2] as List<Map<String, dynamic>>;
        _history = results[3] as List<Map<String, dynamic>>;
        _catalog = results[4] as List<Map<String, dynamic>>;
        _unreadNotifications = _toInt(
          (results[5] as Map<String, dynamic>)["unread_count"],
        );
      });
      await AppNotificationService.syncAndDisplayNotifications();
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
  Future<void> refreshOnResume() => _loadDashboardData(silent: true);

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
    Navigator.push(context, MaterialPageRoute(builder: (context) => page)).then(
      (_) {
        _loadDashboardData(silent: true);
      },
    );
  }

  void _openBottomTab(int index) {
    setState(() {
      _currentIndex = index;
    });
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

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    return "$value".toLowerCase() == "true";
  }

  String _dueLabel(dynamic dueDateValue) {
    final dt = DateTime.tryParse("$dueDateValue");
    if (dt == null) return "Due date unavailable";
    final days = dt.toLocal().difference(DateTime.now()).inDays;
    if (days < 0) return "Overdue by ${days.abs()} day(s)";
    if (days == 0) return "Due today";
    return "Due in $days day(s)";
  }

  String _fmtDate(dynamic value) {
    final dt = DateTime.tryParse("$value");
    if (dt == null) return "-";
    return DateFormat("dd MMM yyyy").format(dt.toLocal());
  }

  String _bookStatusLabel(Map<String, dynamic> book) {
    final overdueDays = _toInt(book["overdue_days"]);
    final overdueFine = _toDouble(book["current_overdue_fine"]);
    if (overdueDays > 0) {
      return "Overdue by $overdueDays day(s) | Fine: Rs ${overdueFine.toStringAsFixed(0)}";
    }
    return _dueLabel(book["due_date"]);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      _buildMyBooksTab(),
      _buildFineTab(),
      _buildWaitingListTab(),
      _buildHistoryTab(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildServicesDrawer(),
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Open menu",
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
                if (_searchQuery.isNotEmpty) {
                  _currentIndex = 0;
                }
              });
            },
            decoration: InputDecoration(
              hintText: "Search books",
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _openPage(const LibraryAnnouncementsPage()),
            icon: const Icon(Icons.campaign_outlined),
          ),
          IconButton(
            onPressed: () => _openPage(const NotificationsPage()),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_outlined),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        _unreadNotifications > 99
                            ? "99+"
                            : "$_unreadNotifications",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  children: [
                    ListTile(
                      title: const Text("Failed to load dashboard"),
                      subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDashboardData,
                      ),
                    ),
                  ],
                )
              : tabs[_currentIndex],
        ),
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
            icon: Icon(Icons.hourglass_bottom_outlined),
            selectedIcon: Icon(Icons.hourglass_bottom),
            label: "Waiting List",
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

  Widget _buildHomeTab() {
    if (_searchQuery.isNotEmpty) {
      final filteredBooks = _catalog.where((book) {
        final title = "${book["title"] ?? ""}".toLowerCase();
        final author = "${book["author"] ?? ""}".toLowerCase();
        return title.contains(_searchQuery) || author.contains(_searchQuery);
      }).toList();
      return _buildBookSearchResults(filteredBooks);
    }
    return _buildOverviewTab();
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
        title: "Waiting List",
        subtitle: "Track queue status",
        icon: Icons.hourglass_bottom_outlined,
        onTap: () => _openBottomTab(3),
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
        title: "Borrow History",
        subtitle: "View past borrows",
        icon: Icons.history,
        onTap: () => _openBottomTab(4),
      ),
    ];

    final borrowedCount = _toInt(
      (_summary["currently_borrowed"] as Map<String, dynamic>?)?["count"],
    );
    final dueThisWeekCount = _toInt(
      (_summary["due_this_week"] as Map<String, dynamic>?)?["count"],
    );
    final outstanding = _toDouble(
      (_summary["outstanding_fines"] as Map<String, dynamic>?)?["total_amount"],
    );

    return ListView(
      key: const ValueKey("overview"),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, $_username",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Explore services, track due dates, and manage your reading.",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: "Books Issued",
                value: "$borrowedCount",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: "Due This Week",
                value: "$dueThisWeekCount",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: "Pending Fine",
                value: "Rs ${outstanding.toStringAsFixed(0)}",
              ),
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
    final filteredBorrows = _searchQuery.isEmpty
        ? _myBooks
        : _myBooks.where((book) {
            final detail = (book["book_detail"] as Map<String, dynamic>?) ?? {};
            final title = "${detail["title"] ?? ""}".toLowerCase();
            return title.contains(_searchQuery);
          }).toList();
    return ListView(
      key: const ValueKey("my_books"),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Current Borrowed Books",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...filteredBorrows.map((book) {
          final detail = (book["book_detail"] as Map<String, dynamic>?) ?? {};
          final overdue = _toInt(book["overdue_days"]) > 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: overdue
                    ? Colors.red.shade50
                    : const Color(0xFFE6FFFA),
                child: Icon(
                  overdue
                      ? Icons.warning_amber_rounded
                      : Icons.menu_book_rounded,
                  color: overdue ? Colors.red : const Color(0xFF0F766E),
                ),
              ),
              title: Text("${detail["title"] ?? "Untitled"}"),
              subtitle: Text(_bookStatusLabel(book)),
            ),
          );
        }),
        if (filteredBorrows.isEmpty)
          const Card(
            child: ListTile(title: Text("No books match your search.")),
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
                onPressed: () => _openBottomTab(4),
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
    final filteredFines = _searchQuery.isEmpty
        ? _fines
        : _fines.where((fine) {
            final bookTitle = "${fine["book_title"] ?? ""}".toLowerCase();
            final fineType = "${fine["fine_type"] ?? ""}".toLowerCase();
            return bookTitle.contains(_searchQuery) ||
                fineType.contains(_searchQuery);
          }).toList();

    final pending = _fines
        .where((f) => !_toBool(f["is_paid"]))
        .fold<double>(0, (sum, item) => sum + _toDouble(item["amount"]));

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
        ...filteredFines.map((fine) {
          final unpaid = !_toBool(fine["is_paid"]);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text("${fine["book_title"] ?? "Library fine"}"),
              subtitle: Text(
                "${fine["fine_type"] ?? "fine"} - Rs ${_toDouble(fine["amount"]).toStringAsFixed(0)}",
              ),
              trailing: Chip(
                label: Text(unpaid ? "Unpaid" : "Paid"),
                backgroundColor: unpaid
                    ? Colors.red.shade50
                    : Colors.green.shade50,
              ),
            ),
          );
        }),
        if (filteredFines.isEmpty)
          const Card(
            child: ListTile(title: Text("No fine records match your search.")),
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
    final filteredHistory = _searchQuery.isEmpty
        ? _history
        : _history.where((item) {
            final title = "${item["book_title"] ?? ""}".toLowerCase();
            return title.contains(_searchQuery);
          }).toList();
    return ListView(
      key: const ValueKey("history"),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Borrow History",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...filteredHistory.map((item) {
          final returned =
              "${item["status"] ?? ""}".toLowerCase() == "returned";
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text("${item["book_title"] ?? "Untitled"}"),
              subtitle: Text(
                "Issued: ${_fmtDate(item["issue_date"])}\n"
                "Returned: ${returned ? (item["return_date"] == null ? "Returned" : _fmtDate(item["return_date"])) : "Not Returned"}",
              ),
              isThreeLine: true,
            ),
          );
        }),
        if (filteredHistory.isEmpty)
          const Card(
            child: ListTile(
              title: Text("No history entries match your search."),
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

  Widget _buildWaitingListTab() {
    return const WaitingListPageBody();
  }

  Widget _buildBookSearchResults(List<Map<String, dynamic>> books) {
    return ListView(
      key: const ValueKey("book_search"),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Book Results for \"${_searchController.text.trim()}\"",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (books.isEmpty)
          const Card(
            child: ListTile(
              title: Text("No books found."),
              subtitle: Text("Try searching by title or author."),
            ),
          ),
        ...books.map((book) {
          final availableCount = _toInt(book["available_copies"]);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _openPage(
                  BookAvailabilityPage(initialQuery: "${book["title"] ?? ""}"),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${book["title"] ?? "Untitled"}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text("${book["author"] ?? "-"}"),
                          Text(
                            "Shelf ${book["shelf"] ?? "-"}",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        availableCount > 0
                            ? "Available ($availableCount)"
                            : "Waiting",
                      ),
                      backgroundColor: availableCount > 0
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServicesDrawer() {
    final services = [
      ("Book Availability", Icons.search, const BookAvailabilityPage()),
      (
        "Waiting List",
        Icons.hourglass_bottom_outlined,
        const WaitingListPage(),
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
                          if (service.$1 == "Waiting List") {
                            _openBottomTab(3);
                          } else if (service.$1 == "Borrow History") {
                            _openBottomTab(4);
                          } else {
                            _openPage(service.$3);
                          }
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
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE6FFFA),
                child: Icon(feature.icon, color: const Color(0xFF0F766E)),
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
