import "package:flutter/widgets.dart";

mixin ResumeRefreshStateMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  DateTime? _lastResumeRefreshAt;

  Duration get minResumeRefreshGap => const Duration(seconds: 10);

  Future<void> refreshOnResume();

  @protected
  void startResumeRefresh() {
    _lastResumeRefreshAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }

    final now = DateTime.now();
    final lastRefreshAt = _lastResumeRefreshAt;
    if (lastRefreshAt != null &&
        now.difference(lastRefreshAt) < minResumeRefreshGap) {
      return;
    }

    _lastResumeRefreshAt = now;
    refreshOnResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
