import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

/// `true` when the device has a usable network connection.
class ConnectivityNotifier extends Notifier<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  bool build() {
    ref.onDispose(() => _subscription?.cancel());
    _subscription = _connectivity.onConnectivityChanged.listen(_applyResults);
    unawaited(_refresh());
    return true;
  }

  Future<void> _refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (_) {
      state = true;
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      state = false;
      return;
    }
    state = results.any((r) => r != ConnectivityResult.none);
  }
}
