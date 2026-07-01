import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_button.dart';
import 'widgets/otp_illustration.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _resendCooldown = 60;
  static const _codeLength = 6;
  static const _maxAttempts = 3;

  final _codeController = TextEditingController();
  final _errorController = StreamController<ErrorAnimationType>();
  final _formKey = GlobalKey<FormState>();
  Timer? _resendTimer;
  int _secondsLeft = _resendCooldown;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _errorController.close();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _handleVerify() async {
    if (_failedAttempts >= _maxAttempts) return;
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    if (code.length < _codeLength) {
      _errorController.add(ErrorAnimationType.shake);
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    await ref.read(authProvider.notifier).verifyOtp(code);
    if (!mounted) return;
    final state = ref.read(authProvider);
    if (state.error != null) {
      _codeController.clear();
      _errorController.add(ErrorAnimationType.shake);
      setState(() => _failedAttempts++);
    }
  }

  Future<void> _handleResend() async {
    if (_secondsLeft > 0) return;
    final phone = ref.read(authProvider).pendingPhone;
    if (phone == null) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    await ref.read(authProvider.notifier).sendOtp(phone, forceResend: true);
    if (!mounted) return;
    _codeController.clear();
    setState(() => _failedAttempts = 0);
    _startResendTimer();
  }

  void _goBack() {
    ref.read(authProvider.notifier).cancelPendingOtp();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildHeader({required String phone, required bool isLoading}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Center(
          child: Hero(
            tag: 'app_logo',
            child: SvgPicture.asset(
              'assets/images/delivro-logo.svg',
              height: 28,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Enter verification code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            children: [
              const TextSpan(text: "We've sent a 6-digit code to\n"),
              TextSpan(
                text: phone.isEmpty ? 'your number' : phone,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: isLoading ? null : _goBack,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Change number'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLighter,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField({required bool isLoading, required bool hasError}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const separatorWidth = 8.0;
        const totalSeparators = (_codeLength - 1) * separatorWidth;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final available = (maxWidth - totalSeparators) / _codeLength;
        final fieldWidth = available.clamp(36.0, 48.0);
        final fieldHeight = (fieldWidth * 1.2).clamp(48.0, 58.0);

        return PinCodeTextField(
          appContext: context,
          length: _codeLength,
          controller: _codeController,
          errorAnimationController: _errorController,
          autoDisposeControllers: false,
          autoFocus: true,
          enabled: !isLoading,
          keyboardType: TextInputType.number,
          enableActiveFill: true,
          enablePinAutofill: true,
          mainAxisAlignment: MainAxisAlignment.center,
          separatorBuilder: (_, _) => const SizedBox(width: separatorWidth),
          animationType: AnimationType.scale,
          animationDuration: const Duration(milliseconds: 200),
          cursorColor: AppColors.primary,
          cursorHeight: 22,
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(14),
            fieldHeight: fieldHeight,
            fieldWidth: fieldWidth,
            activeFillColor: AppColors.surface,
            selectedFillColor:
                AppColors.primaryLighter.withValues(alpha: 0.35),
            inactiveFillColor: AppColors.surface,
            activeColor: hasError ? AppColors.error : AppColors.primary,
            selectedColor: hasError ? AppColors.error : AppColors.primary,
            inactiveColor: hasError ? AppColors.error : AppColors.border,
            errorBorderColor: AppColors.error,
            borderWidth: 1.6,
            fieldOuterPadding: EdgeInsets.zero,
          ),
          onChanged: (_) {
            if (ref.read(authProvider).error != null) {
              ref.read(authProvider.notifier).clearError();
            }
          },
          onCompleted: (_) => _handleVerify(),
        );
      },
    );
  }

  Widget _buildResendRow({required bool isLoading}) {
    final canResend = _secondsLeft == 0;

    if (!canResend) {
      return _CountdownPill(
        seconds: _secondsLeft,
        label: _formatCountdown(_secondsLeft),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        const Text(
          "Didn't receive the code?",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: isLoading ? null : _handleResend,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Resend',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final phone = authState.pendingPhone ?? '';
    final hasError = authState.error != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final imageHeight = otpImageHeightFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              AppColors.primary50,
            ],
            stops: [0.0, 0.72, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: const IgnorePointer(
                child: OtpIllustration(),
              ),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  imageHeight + 12 + keyboardInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(phone: phone, isLoading: authState.isLoading),
                    Form(
                      key: _formKey,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (authState.error case final String message) ...[
                              _buildErrorBanner(message),
                              const SizedBox(height: 18),
                            ],
                            _buildPinField(
                              isLoading: authState.isLoading,
                              hasError: hasError,
                            ),
                            const SizedBox(height: 22),
                            if (_failedAttempts >= _maxAttempts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Too many wrong attempts — tap "Resend" to get a new code.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              DeliveroButton(
                                label: 'Verify & continue',
                                onPressed:
                                    authState.isLoading ? null : _handleVerify,
                                isLoading: authState.isLoading,
                                icon: Icons.verified_outlined,
                                borderRadius: 12,
                              ),
                            const SizedBox(height: 20),
                            _buildResendRow(isLoading: authState.isLoading),
                            const SizedBox(height: 6),
                            const _AutofillHint(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final int seconds;
  final String label;

  const _CountdownPill({required this.seconds, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Resend code in $label',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutofillHint extends StatelessWidget {
  const _AutofillHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.sms_outlined,
            size: 13,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 6),
          const Flexible(
            child: Text(
              "We'll fill the code automatically when it arrives.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
