import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/user.dart';

/// Shows a blocking password change dialog for new driver accounts
/// ([User.mustChangePassword]) after they reach the delivery shell.
class DeliveryPasswordChangeGate extends ConsumerStatefulWidget {
  const DeliveryPasswordChangeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeliveryPasswordChangeGate> createState() =>
      _DeliveryPasswordChangeGateState();
}

class _DeliveryPasswordChangeGateState
    extends ConsumerState<DeliveryPasswordChangeGate> {
  var _dialogOpening = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    if (user != null &&
        user.role == UserRole.delivery &&
        user.mustChangePassword) {
      if (!_dialogOpening) {
        _dialogOpening = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final u = ref.read(authProvider).user;
          if (u == null ||
              u.role != UserRole.delivery ||
              !u.mustChangePassword) {
            _dialogOpening = false;
            return;
          }
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const _MandatoryPasswordChangeDialog(),
          );
          _dialogOpening = false;
        });
      }
    } else {
      _dialogOpening = false;
    }

    return widget.child;
  }
}

class _MandatoryPasswordChangeDialog extends ConsumerStatefulWidget {
  const _MandatoryPasswordChangeDialog();

  @override
  ConsumerState<_MandatoryPasswordChangeDialog> createState() =>
      _MandatoryPasswordChangeDialogState();
}

class _MandatoryPasswordChangeDialogState
    extends ConsumerState<_MandatoryPasswordChangeDialog> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  var _obscure1 = true;
  var _obscure2 = true;
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final a = _pw1.text;
    final b = _pw2.text;
    if (a.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).completeMandatoryPasswordChange(a);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : '$e';
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  OutlineInputBorder _border() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border, width: 1.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Set your password',
          style: context.appTextStyles.sectionHeader,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your account was created by your manager. Choose a new password that only you know before continuing.',
                style: context.appTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _pw1,
                obscureText: _obscure1,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: _border(),
                  enabledBorder: _border(),
                  focusedBorder: _border().copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.6,
                    ),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(
                      _obscure1
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw2,
                obscureText: _obscure2,
                enabled: !_loading,
                onSubmitted: (_) {
                  if (!_loading) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: _border(),
                  enabledBorder: _border(),
                  focusedBorder: _border().copyWith(
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.6,
                    ),
                  ),
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(
                      _obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save password',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }
}
