import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// One line in the dialog's consequence panel: what the user is about to lose.
class DestructiveFact {
  final IconData icon;
  final String label;

  /// Set for facts that should stop the user — an unpaid balance, say. Renders
  /// the row in red.
  final bool warning;

  const DestructiveFact({
    required this.icon,
    required this.label,
    this.warning = false,
  });
}

/// Confirmation dialog for actions that cannot be undone. Leads with a red
/// icon, states the consequence plainly, spells out what is attached to the
/// thing being deleted, and makes the destructive button the visually heavy one
/// so it is never mistaken for the safe choice.
///
/// Returns true only when the user confirms.
Future<bool> showDestructiveConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.delete_outline_rounded,

  /// Rendered bold inside [message] wherever it occurs — the name of the thing
  /// being destroyed, so the user can see exactly what they are about to lose.
  String? highlight,

  /// What is attached to the thing being deleted. Shown in a panel between the
  /// message and the buttons; omitted entirely when empty.
  List<DestructiveFact> facts = const [],
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.error, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          _Message(message: message, highlight: highlight),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < facts.length; i++) ...[
                    if (i != 0) const SizedBox(height: 10),
                    _FactRow(fact: facts[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  try {
                    HapticFeedback.mediumImpact();
                  } catch (_) {}
                  Navigator.pop(dialogContext, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _FactRow extends StatelessWidget {
  final DestructiveFact fact;
  const _FactRow({required this.fact});

  @override
  Widget build(BuildContext context) {
    final color = fact.warning ? AppColors.error : AppColors.textSecondary;
    return Row(
      children: [
        Icon(
          fact.icon,
          size: 16,
          color: fact.warning ? AppColors.error : AppColors.textLight,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fact.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: fact.warning ? FontWeight.w900 : FontWeight.w700,
              color: color,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// The dialog body, with [highlight] (if present) picked out in bold.
class _Message extends StatelessWidget {
  final String message;
  final String? highlight;

  const _Message({required this.message, this.highlight});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final bold = base.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.textPrimary,
    );

    final needle = highlight?.trim() ?? '';
    final at = needle.isEmpty ? -1 : message.indexOf(needle);
    if (at < 0) {
      return Text(message, textAlign: TextAlign.center, style: base);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: message.substring(0, at), style: base),
          TextSpan(text: needle, style: bold),
          TextSpan(text: message.substring(at + needle.length), style: base),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
