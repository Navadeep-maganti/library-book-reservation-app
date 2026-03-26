import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "../../../core/services/library_api.dart";
import "../../../core/utils/resume_refresh_state_mixin.dart";

class LibraryAnnouncementsPage extends StatefulWidget {
  const LibraryAnnouncementsPage({super.key});

  @override
  State<LibraryAnnouncementsPage> createState() =>
      _LibraryAnnouncementsPageState();
}

class _LibraryAnnouncementsPageState extends State<LibraryAnnouncementsPage>
    with WidgetsBindingObserver, ResumeRefreshStateMixin<LibraryAnnouncementsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _announcements = const [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    startResumeRefresh();
  }

  Future<void> _loadAnnouncements({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await AnnouncementAPI.getAnnouncements();
      if (!mounted) return;
      setState(() {
        _error = null;
        _announcements = data;
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
  Future<void> refreshOnResume() => _loadAnnouncements(silent: true);

  String _formatDate(dynamic value) {
    final dt = DateTime.tryParse("$value");
    if (dt == null) return "";
    return DateFormat("dd MMM yyyy").format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Library Announcements")),
      body: RefreshIndicator(
        onRefresh: _loadAnnouncements,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  title: const Text("Failed to load announcements"),
                  subtitle: Text(_error!.replaceFirst("Exception: ", "")),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadAnnouncements,
                  ),
                ),
              )
            else if (_announcements.isEmpty)
              const Card(child: ListTile(title: Text("No announcements found")))
            else
              ..._announcements.map((announcement) {
                final createdAt = _formatDate(announcement["created_at"]);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "${announcement["title"] ?? "Announcement"}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (createdAt.isNotEmpty)
                              Chip(label: Text(createdAt)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${announcement["content"] ?? ""}",
                          style: TextStyle(color: Colors.grey.shade700),
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
