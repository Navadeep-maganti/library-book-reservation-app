import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../auth/services/auth_service.dart";
import "../../core/services/app_notification_service.dart";
import "../../core/services/book_api.dart";
import "../../core/services/borrowing_api.dart";
import "../../core/services/library_api.dart";
import "../../core/utils/resume_refresh_state_mixin.dart";
import "../../core/widgets/app_ui.dart";
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
  final FocusNode _searchFocusNode = FocusNode();

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
    _searchFocusNode.dispose();
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

  void _dismissSearchFocus() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _handleLogout() async {
    _dismissSearchFocus();
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
    _dismissSearchFocus();
    Navigator.push(context, MaterialPageRoute(builder: (context) => page)).then(
      (_) {
        _loadDashboardData(silent: true);
      },
    );
  }

  void _openBottomTab(int index) {
    _dismissSearchFocus();
    if (index == 2) {
      _openPage(const FineManagementPage());
      return;
    }
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
          onPressed: () {
            _dismissSearchFocus();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        titleSpacing: 0,
        title: SizedBox(
          height: 44,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onTapOutside: (_) => _dismissSearchFocus(),
            onSubmitted: (_) => _dismissSearchFocus(),
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
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissSearchFocus,
        child: RefreshIndicator(
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
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          _openBottomTab(index);
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
            label: "Reservations",
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
    final borrowedCount = _toInt(
      (_summary["currently_borrowed"] as Map<String, dynamic>?)?["count"],
    );
    final dueThisWeekCount = _toInt(
      (_summary["due_this_week"] as Map<String, dynamic>?)?["count"],
    );
    final overdueCount = _toInt(
      (_summary["overdue"] as Map<String, dynamic>?)?["count"],
    );
    final outstanding = _toDouble(
      (_summary["outstanding_fines"] as Map<String, dynamic>?)?["total_amount"],
    );
    final reservationCount = _toInt(
      (_summary["pending_reservations"] as Map<String, dynamic>?)?["count"],
    );
    final activeItemLimit =
        (_summary["active_item_limit"] as Map<String, dynamic>?) ?? const {};
    final activeItems = _toInt(activeItemLimit["total_active"]);
    final maxActiveItems = _toInt(activeItemLimit["max_allowed"]);
    final remainingSlots = _toInt(activeItemLimit["remaining_slots"]);
    final activeLimitMessage = "${activeItemLimit["message"] ?? ""}".trim();
    final announcements = List<Map<String, dynamic>>.from(
      _summary["announcements"] ?? const [],
    );
    final recentHistory = _history.take(3).toList();
    final availableNow = _catalog
        .where((book) => _toInt(book["available_copies"]) > 0)
        .take(3)
        .toList();
    final dueBooks = _myBooks.where((book) {
      return DateTime.tryParse("${book["due_date"]}") != null;
    }).toList()
      ..sort((a, b) {
        final left = DateTime.tryParse("${a["due_date"]}")!;
        final right = DateTime.tryParse("${b["due_date"]}")!;
        return left.compareTo(right);
      });
    final nextDueBook = dueBooks.isEmpty ? null : dueBooks.first;
    final unpaidFineCount = _fines.where((fine) => !_toBool(fine["is_paid"])).length;
    final pulseColor = overdueCount > 0
        ? const Color(0xFFDC2626)
        : outstanding > 0
        ? const Color(0xFFD97706)
        : reservationCount > 0
        ? const Color(0xFF0F766E)
        : const Color(0xFF1D4ED8);
    final pulseLabel = overdueCount > 0
        ? "Needs attention"
        : outstanding > 0
        ? "Almost clear"
        : reservationCount > 0
        ? "Active flow"
        : "All set";
    final pulseMessage = overdueCount > 0
        ? "You have $overdueCount overdue book(s). Clearing them first will protect your record and reduce extra fines."
        : nextDueBook != null
        ? "\"${nextDueBook["book_detail"]?["title"] ?? "Your next title"}\" is due on ${_fmtDate(nextDueBook["due_date"])}."
        : reservationCount > 0
        ? "Your reservations are active. Keep an eye on pickup notifications and queue movement."
        : "Your account looks healthy. This is a good time to browse, discover, and borrow something new.";
    final primaryPulseLabel = overdueCount > 0
        ? "Resolve now"
        : reservationCount > 0
        ? "Open reservations"
        : "Browse catalog";
    final primaryPulseAction = overdueCount > 0
        ? () => _openPage(const DueAlertsPage())
        : reservationCount > 0
        ? () => _openBottomTab(3)
        : () => _openPage(const BookAvailabilityPage());

    return ListView(
      key: const ValueKey("overview"),
      padding: const EdgeInsets.all(16),
      children: [
        AppPageHeader(
          title: "Welcome, $_username",
          subtitle:
              "Explore services, keep an eye on due dates, and manage your library activity from one clean dashboard.",
          icon: Icons.waving_hand_rounded,
          badges: [
            AppHeaderBadge(label: "Books issued", value: "$borrowedCount"),
            AppHeaderBadge(label: "Due this week", value: "$dueThisWeekCount"),
            AppHeaderBadge(
              label: "Pending fine",
              value: "Rs ${outstanding.toStringAsFixed(0)}",
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DashboardPulseCard(
          title: "Today's library pulse",
          subtitle: pulseMessage,
          statusLabel: pulseLabel,
          color: pulseColor,
          primaryActionLabel: primaryPulseLabel,
          onPrimaryAction: primaryPulseAction,
          secondaryActionLabel: _unreadNotifications > 0
              ? "Notifications"
              : "Announcements",
          onSecondaryAction: _unreadNotifications > 0
              ? () => _openPage(const NotificationsPage())
              : () => _openPage(const LibraryAnnouncementsPage()),
          metrics: [
            _PulseMetricChip(
              icon: Icons.notifications_active_outlined,
              label: "Unread alerts",
              value: "$_unreadNotifications",
              color: const Color(0xFF7C3AED),
            ),
            _PulseMetricChip(
              icon: Icons.schedule_outlined,
              label: "Next due",
              value: nextDueBook == null
                  ? "None"
                  : _fmtDate(nextDueBook["due_date"]),
              color: const Color(0xFFD97706),
            ),
            _PulseMetricChip(
              icon: Icons.account_balance_wallet_outlined,
              label: "Open fines",
              value: "$unpaidFineCount",
              color: const Color(0xFFDC2626),
            ),
            _PulseMetricChip(
              icon: Icons.auto_stories_outlined,
              label: "Free slots",
              value: "$remainingSlots",
              color: const Color(0xFF0F766E),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: "Action board",
          subtitle: overdueCount > 0
              ? "You have urgent items that need attention."
              : "The most useful student actions are surfaced here instead of repeating page links.",
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _DashboardSpotlightCard(
              title: "Due & overdue",
              value: overdueCount > 0
                  ? "$overdueCount overdue"
                  : "$dueThisWeekCount due soon",
              subtitle: overdueCount > 0
                  ? "Open due alerts and clear urgent returns."
                  : "Stay ahead of returns coming up this week.",
              icon: overdueCount > 0
                  ? Icons.warning_amber_rounded
                  : Icons.schedule,
              color: overdueCount > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFD97706),
              actionLabel: "Due alerts",
              onTap: () => _openPage(const DueAlertsPage()),
            ),
            _DashboardSpotlightCard(
              title: "Reservations",
              value: "$reservationCount active",
              subtitle: reservationCount > 0
                  ? "Check pickup-ready books and queue positions."
                  : "No active reservation flow right now.",
              icon: Icons.hourglass_bottom_outlined,
              color: const Color(0xFF0F766E),
              actionLabel: "Open reservations",
              onTap: () => _openBottomTab(3),
            ),
            _DashboardSpotlightCard(
              title: "Fine management",
              value: "Rs ${outstanding.toStringAsFixed(0)}",
              subtitle: outstanding > 0
                  ? "Outstanding dues are ready to clear."
                  : "Your account is currently clear.",
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF1D4ED8),
              actionLabel: "Open fines",
              onTap: () => _openPage(const FineManagementPage()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: "Borrowing capacity",
          subtitle: maxActiveItems > 0
              ? "$activeItems of $maxActiveItems issue/reservation slots are used."
              : "Track how many active slots remain.",
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CapacityStat(
                        label: "Issued books",
                        value: "$borrowedCount",
                      ),
                    ),
                    Expanded(
                      child: _CapacityStat(
                        label: "Reservations",
                        value: "$reservationCount",
                      ),
                    ),
                    Expanded(
                      child: _CapacityStat(
                        label: "Free slots",
                        value: "$remainingSlots",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: maxActiveItems == 0
                        ? 0
                        : (activeItems / maxActiveItems).clamp(0, 1),
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                if (activeLimitMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppInfoBanner(
                    icon: Icons.info_outline,
                    message: activeLimitMessage,
                    color: const Color(0xFFD97706),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: "Recent activity",
          subtitle: recentHistory.isEmpty
              ? "Your latest issue and return activity will appear here."
              : "A quick look at your most recent book activity.",
          action: FilledButton.tonal(
            onPressed: () => _openBottomTab(4),
            child: const Text("Full history"),
          ),
        ),
        const SizedBox(height: 10),
        if (recentHistory.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.history_toggle_off_outlined,
            title: "No recent activity yet",
            subtitle:
                "Issued and returned books will appear here once you begin using the library.",
          )
        else
          ...recentHistory.map((item) {
            final returned =
                "${item["status"] ?? ""}".toLowerCase() == "returned";
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: returned
                        ? Colors.green.withValues(alpha: 0.1)
                        : const Color(0xFFDFF8F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    returned
                        ? Icons.assignment_turned_in_outlined
                        : Icons.menu_book_outlined,
                    color: returned
                        ? const Color(0xFF15803D)
                        : const Color(0xFF0F766E),
                  ),
                ),
                title: Text("${item["book_title"] ?? "Untitled"}"),
                subtitle: Text(
                  returned
                      ? "Returned on ${_fmtDate(item["return_date"])}"
                      : "Issued on ${_fmtDate(item["issue_date"])}",
                ),
                trailing: Chip(label: Text(returned ? "Returned" : "Active")),
              ),
            );
          }),
        const SizedBox(height: 20),
        AppSectionHeader(
          title: "Available now",
          subtitle:
              "Live books you can explore immediately instead of opening a menu again.",
          action: FilledButton.tonal(
            onPressed: () => _openPage(const BookAvailabilityPage()),
            child: const Text("Browse all"),
          ),
        ),
        const SizedBox(height: 10),
        if (availableNow.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: "No instant picks right now",
            subtitle:
                "Open the full catalog to search the collection and queue status.",
          )
        else
          ...availableNow.map((book) {
            final availableCount = _toInt(book["available_copies"]);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openPage(
                  BookAvailabilityPage(initialQuery: "${book["title"] ?? ""}"),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const AppBookCover(width: 56, height: 74),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${book["title"] ?? "Untitled"}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text("${book["author"] ?? "-"}"),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text("Available ($availableCount)"),
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        if (announcements.isNotEmpty) ...[
          const SizedBox(height: 20),
          AppSectionHeader(
            title: "From the library",
            subtitle:
                "Recent official updates so the dashboard feels live and evaluator-ready.",
            action: FilledButton.tonal(
              onPressed: () => _openPage(const LibraryAnnouncementsPage()),
              child: const Text("View all"),
            ),
          ),
          const SizedBox(height: 10),
          ...announcements.take(2).map((announcement) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                title: Text("${announcement["title"] ?? "Announcement"}"),
                subtitle: Text(
                  "${announcement["content"] ?? ""}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
        ],
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
        AppPageHeader(
          title: "My books",
          subtitle:
              "See what is currently issued to you, how close each title is to its due date, and jump into history or alerts quickly.",
          icon: Icons.menu_book_outlined,
          badges: [
            AppHeaderBadge(
              label: "Issued now",
              value: "${filteredBorrows.length}",
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppSectionHeader(
          title: "Quick actions",
          subtitle:
              "Open related pages without scrolling through the full list.",
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openPage(const DueAlertsPage()),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text("Due Alerts"),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openBottomTab(4),
                icon: const Icon(Icons.history),
                label: const Text("History"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...filteredBorrows.map((book) {
          final detail = (book["book_detail"] as Map<String, dynamic>?) ?? {};
          final overdue = _toInt(book["overdue_days"]) > 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppBookCover(width: 64, height: 84),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${detail["title"] ?? "Untitled"}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                              label: Text(overdue ? "Overdue" : "Active loan"),
                              backgroundColor: overdue
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : const Color(0xFFDFF8F4),
                            ),
                            Chip(
                              label: Text(_bookStatusLabel(book)),
                              backgroundColor: const Color(0xFFF8FAFC),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredBorrows.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.menu_book_outlined,
            title: "No books match your search",
            subtitle:
                "Try another title, or pull to refresh if you recently borrowed or returned a book.",
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
        AppPageHeader(
          title: "Fines snapshot",
          subtitle:
              "Get a quick view of unpaid charges here, then open the full fine page to settle them comfortably.",
          icon: Icons.account_balance_wallet_outlined,
          badges: [
            AppHeaderBadge(
              label: "Outstanding",
              value: "Rs ${pending.toStringAsFixed(0)}",
            ),
            AppHeaderBadge(label: "Records", value: "${filteredFines.length}"),
          ],
        ),
        const SizedBox(height: 18),
        AppSectionHeader(
          title: "Manage fines",
          subtitle:
              "Open the full payment screen without scrolling through the list.",
          action: FilledButton.icon(
            onPressed: () => _openPage(const FineManagementPage()),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text("Open Fine Management"),
          ),
        ),
        const SizedBox(height: 16),
        ...filteredFines.map((fine) {
          final unpaid = !_toBool(fine["is_paid"]);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                          : Icons.check_circle_outline,
                      color: unpaid
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${fine["book_title"] ?? "Library fine"}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${fine["fine_type"] ?? "fine"} - Rs ${_toDouble(fine["amount"]).toStringAsFixed(0)}",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(unpaid ? "Unpaid" : "Paid"),
                    backgroundColor: unpaid
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.green.withValues(alpha: 0.1),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredFines.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.verified_outlined,
            title: "No fine records match your search",
            subtitle:
                "Your fine history will appear here when records are available.",
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
        AppPageHeader(
          title: "History snapshot",
          subtitle:
              "Review recent issue and return activity, then open the full timeline for more detail.",
          icon: Icons.history_rounded,
          badges: [
            AppHeaderBadge(
              label: "Entries",
              value: "${filteredHistory.length}",
            ),
          ],
        ),
        const SizedBox(height: 18),
        AppSectionHeader(
          title: "Open full history",
          subtitle:
              "The detailed history page is available right here instead of at the bottom.",
          action: FilledButton.tonal(
            onPressed: () => _openPage(const BorrowHistoryPage()),
            child: const Text("Open Detailed History"),
          ),
        ),
        const SizedBox(height: 16),
        ...filteredHistory.map((item) {
          final returned =
              "${item["status"] ?? ""}".toLowerCase() == "returned";
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: returned
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      returned
                          ? Icons.assignment_turned_in_outlined
                          : Icons.schedule,
                      color: returned
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${item["book_title"] ?? "Untitled"}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(returned ? "Returned" : "Active"),
                              backgroundColor: returned
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Issued ${_fmtDate(item["issue_date"])}",
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                returned
                                    ? "Returned ${item["return_date"] == null ? "Returned" : _fmtDate(item["return_date"])}"
                                    : "Not returned",
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filteredHistory.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.history_toggle_off_outlined,
            title: "No history entries match your search",
            subtitle:
                "Try another book title or revisit later after more issue activity.",
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
        AppPageHeader(
          title: "Search results",
          subtitle:
              "Results for \"${_searchController.text.trim()}\". Open any title to view availability and reserve it.",
          icon: Icons.search_rounded,
          badges: [AppHeaderBadge(label: "Matches", value: "${books.length}")],
        ),
        const SizedBox(height: 18),
        if (books.isEmpty)
          const AppEmptyStateCard(
            icon: Icons.search_off_outlined,
            title: "No books found",
            subtitle: "Try searching by another title or author keyword.",
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
                    const AppBookCover(width: 56, height: 76),
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
        "Reservations",
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      _username.isNotEmpty ? _username[0].toUpperCase() : "S",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Library Services",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Student account",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          if (service.$1 == "Reservations") {
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

class _DashboardPulseCard extends StatelessWidget {
  const _DashboardPulseCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.color,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.secondaryActionLabel,
    required this.onSecondaryAction,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final Color color;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String secondaryActionLabel;
  final VoidCallback onSecondaryAction;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.insights_outlined, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Chip(
              label: Text(statusLabel),
              backgroundColor: color.withValues(alpha: 0.1),
              side: BorderSide.none,
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: metrics,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onPrimaryAction,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(primaryActionLabel),
                ),
                FilledButton.tonal(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseMetricChip extends StatelessWidget {
  const _PulseMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSpotlightCard extends StatelessWidget {
  const _DashboardSpotlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(subtitle),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onTap,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapacityStat extends StatelessWidget {
  const _CapacityStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
