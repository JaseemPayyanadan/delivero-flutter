import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once the launcher splash animation has finished (3.5s).
/// [RouterNotifier] keeps the user on `/splash` until this is true.
final launcherAnimationCompleteProvider =
    NotifierProvider<LauncherAnimationNotifier, bool>(
  LauncherAnimationNotifier.new,
);

class LauncherAnimationNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markComplete() => state = true;
}
