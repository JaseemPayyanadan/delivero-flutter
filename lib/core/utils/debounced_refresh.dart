import 'dart:async';

/// Prevents rapid repeated refresh calls (e.g. pull-to-refresh spam).
class DebouncedRefresh {
  DebouncedRefresh({this.cooldown = const Duration(seconds: 2)});

  final Duration cooldown;
  DateTime? _lastRefreshAt;
  Future<void>? _inFlight;

  Future<void> run(Future<void> Function() action) async {
    final now = DateTime.now();
    if (_lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < cooldown) {
      return _inFlight ?? Future.value();
    }

    _lastRefreshAt = now;
    _inFlight = action();
    try {
      await _inFlight;
    } finally {
      _inFlight = null;
    }
  }
}
