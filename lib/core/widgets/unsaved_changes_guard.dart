import 'package:flutter/material.dart';

/// Shows a confirmation dialog when the user tries to leave with unsaved edits.
Future<bool> confirmDiscardUnsavedChanges(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text(
        'You have unsaved changes. Leave without saving?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Wraps [child] and intercepts back navigation when [hasUnsavedChanges] is true.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.canPop = true,
  });

  final bool hasUnsavedChanges;
  final bool canPop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop && !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !hasUnsavedChanges) return;
        final discard = await confirmDiscardUnsavedChanges(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
