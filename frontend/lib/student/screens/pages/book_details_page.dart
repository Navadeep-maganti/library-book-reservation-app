import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../../../core/services/book_api.dart";
import "../../../core/services/library_api.dart";
import "../../../core/widgets/app_ui.dart";

class BookDetailsPage extends StatefulWidget {
  const BookDetailsPage({
    super.key,
    required this.book,
    this.reservationDisabledMessage,
  });

  final Map<String, dynamic> book;
  final String? reservationDisabledMessage;

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  bool _submitting = false;
  bool _openingDigital = false;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse("$value") ?? 0;
  }

  Future<void> _reserveBook() async {
    if (_submitting) return;
    final id = _toInt(widget.book["id"]);
    final title = "${widget.book["title"] ?? "book"}";

    setState(() {
      _submitting = true;
    });
    try {
      final response = await ReservationAPI.makeReservation(id);
      if (!mounted) return;
      final status = "${response["status"] ?? ""}".toLowerCase();
      final message = status == "notified"
          ? "\"$title\" reserved. You have 30 minutes to collect it."
          : "\"$title\" added to waiting list.";
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    final normalized = "$value".trim().toLowerCase();
    return normalized == "true" || normalized == "1";
  }

  Future<void> _openDigitalCopy({required bool download}) async {
    if (_openingDigital) return;
    final id = _toInt(widget.book["id"]);
    final title = "${widget.book["title"] ?? "book"}";

    setState(() {
      _openingDigital = true;
    });
    try {
      final access = await BookAPI.getDigitalAccess(id);
      final url = "${access["access_url"] ?? ""}".trim();
      final canDownload = _toBool(access["can_download"]);
      if (url.isEmpty) {
        throw Exception("Digital copy is not configured yet.");
      }
      if (download && !canDownload) {
        throw Exception("Download is disabled for this title.");
      }

      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: download ? "_blank" : "ebook-viewer",
      );
      if (!launched) {
        throw Exception(
          download
              ? "Could not start the download for \"$title\"."
              : "Could not open the reader for \"$title\".",
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingDigital = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = "${widget.book["title"] ?? "Untitled"}";
    final author = "${widget.book["author"] ?? "-"}";
    final shelf = "${widget.book["shelf"] ?? "-"}";
    final category = "${widget.book["category"] ?? "-"}";
    final isbn = "${widget.book["isbn"] ?? "-"}";
    final description =
        "${widget.book["description"] ?? "No description available."}";
    final totalCopies = _toInt(widget.book["total_copies"]);
    final availableCopies = _toInt(widget.book["available_copies"]);
    final available = availableCopies > 0;
    final hasDigitalCopy = _toBool(widget.book["has_digital_copy"]);
    final allowDigitalDownload = _toBool(widget.book["allow_digital_download"]);
    final digitalFormat = "${widget.book["digital_format"] ?? ""}".trim();
    final reservationDisabledReason = widget.reservationDisabledMessage?.trim();
    final reservationDisabled =
        reservationDisabledReason != null &&
        reservationDisabledReason.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Book Details")),
      bottomNavigationBar: AppActionDock(
        title: reservationDisabled
            ? "Reservation temporarily disabled"
            : available
            ? "Copies available now"
            : "Join the queue",
        subtitle: reservationDisabled
            ? reservationDisabledReason
            : available
            ? "$availableCopies of $totalCopies copies can be reserved for the next 30 minutes."
            : "No copy is free right now, but you can still join the waiting list.",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasDigitalCopy) ...[
              OutlinedButton.icon(
                onPressed: _openingDigital
                    ? null
                    : () => _openDigitalCopy(download: false),
                icon: _openingDigital
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_stories_outlined),
                label: const Text("Read PDF"),
              ),
              const SizedBox(height: 10),
              if (allowDigitalDownload) ...[
                OutlinedButton.icon(
                  onPressed: _openingDigital
                      ? null
                      : () => _openDigitalCopy(download: true),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("Download PDF"),
                ),
                const SizedBox(height: 10),
              ],
            ],
            FilledButton.icon(
              onPressed: (_submitting || reservationDisabled) ? null : _reserveBook,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_clock_outlined),
              label: Text(
                reservationDisabled
                    ? "Reservation limit reached"
                    : available
                    ? "Reserve for 30 minutes"
                    : "Join waiting list",
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          AppPageHeader(
            title: title,
            subtitle:
                "Review metadata, check live availability, and place a reservation directly from this page.",
            icon: available ? Icons.menu_book_rounded : Icons.hourglass_bottom,
            badges: [
              AppHeaderBadge(label: "Author", value: author),
              AppHeaderBadge(label: "Shelf", value: shelf),
              if (hasDigitalCopy)
                AppHeaderBadge(
                  label: "Digital",
                  value: digitalFormat.isEmpty
                      ? "Available"
                      : digitalFormat.toUpperCase(),
                ),
            ],
            trailing: const AppBookCover(width: 76, height: 100),
          ),
          const SizedBox(height: 16),
          if (reservationDisabled) ...[
            AppInfoBanner(
              icon: Icons.info_outline,
              message: reservationDisabledReason,
              color: const Color(0xFFB45309),
            ),
            const SizedBox(height: 16),
          ],
          AppSectionHeader(
            title: "Catalog details",
            subtitle: "Everything you need before reserving this title.",
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text("Shelf: $shelf")),
              Chip(label: Text("Category: $category")),
              Chip(label: Text("ISBN: $isbn")),
            ],
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: "Availability",
            subtitle: "Live copy status from the library inventory.",
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                available ? Icons.check_circle : Icons.hourglass_bottom,
                color: available ? Colors.green : Colors.orange,
              ),
              title: Text(
                available ? "Available now" : "Currently unavailable",
              ),
              subtitle: Text("Copies: $availableCopies / $totalCopies"),
            ),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: "Digital access",
            subtitle: "Read online or download a soft copy when the title includes one.",
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                hasDigitalCopy ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: hasDigitalCopy ? Colors.teal : Colors.grey,
              ),
              title: Text(
                hasDigitalCopy ? "Soft copy available" : "Physical copy only",
              ),
              subtitle: Text(
                hasDigitalCopy
                    ? allowDigitalDownload
                        ? "Students can read online and download this title."
                        : "Students can read this title online, but downloads are disabled."
                    : "This title does not have a digital file attached yet.",
              ),
            ),
          ),
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: "Description",
            subtitle: "A quick summary of the book before you reserve it.",
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(description, style: const TextStyle(height: 1.55)),
            ),
          ),
        ],
      ),
    );
  }
}
