import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_button.dart';
import 'widgets/login_illustration.dart';

const String _kPrivacyPolicyUrl = 'https://delivero.app/privacy';
const String _kTermsOfServiceUrl = 'https://delivero.app/terms';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  static const _inputRadius = 16.0;
  static const _defaultCountryCode = 'IN';

  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  PhoneNumber? _phone;

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    final number = _phone;
    if (number == null || number.number.trim().isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    final e164 = '+${number.countryCode.replaceAll('+', '')}${number.number}';

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    await ref.read(authProvider.notifier).sendOtp(e164);
    if (!mounted) return;

    final state = ref.read(authProvider);
    if (state.error == null && state.verificationId != null) {
      context.push('/otp');
    }
  }

  OutlineInputBorder _inputBorder({Color? color, double? width}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
      borderSide: BorderSide(
        color: color ?? AppColors.border,
        width: width ?? 1.2,
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
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
    );
  }

  Widget _buildOtpInfoBanner() {
    const message = "We'll send a 6-digit code to verify it's you.";
    final maxWidth = MediaQuery.sizeOf(context).width - 48;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildPhoneField({required bool isLoading}) {
    return IntlPhoneField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      initialCountryCode: _defaultCountryCode,
      disableLengthCheck: false,
      enabled: !isLoading,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      invalidNumberMessage: 'Please enter a valid mobile number',
      dropdownIconPosition: IconPosition.trailing,
      flagsButtonPadding: const EdgeInsets.only(left: 14, right: 4),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      dropdownTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      dropdownIcon: const Icon(
        Icons.expand_more_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        hintText: '9876543210',
        hintStyle: const TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: AppColors.primary, width: 1.6),
        errorBorder: _inputBorder(color: AppColors.error, width: 1.6),
        focusedErrorBorder: _inputBorder(color: AppColors.error, width: 1.6),
      ),
      onChanged: (phone) => _phone = phone,
      onSubmitted: (_) => _handleSendOtp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final imageHeight = loginImageHeightFor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), AppColors.primary50],
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
              child: const IgnorePointer(child: LoginIllustration()),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        48,
                        24,
                        imageHeight + 12 + keyboardInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 28),
                          const Text(
                            'Welcome back!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your phone number to sign in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildOtpInfoBanner(),
                          if (authState.error case final String message) ...[
                            const SizedBox(height: 16),
                            _buildErrorBanner(message),
                          ],
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mobile number',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildPhoneField(isLoading: authState.isLoading),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.phone_android_rounded,
                                      size: 15,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Enter the mobile number linked to your account.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.center,
                            child: DeliveroButton(
                              label: 'Send OTP',
                              onPressed: authState.isLoading
                                  ? null
                                  : _handleSendOtp,
                              isLoading: authState.isLoading,
                              isFullWidth: false,
                              icon: Icons.sms_outlined,
                              borderRadius: 28,
                              height: 52,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Secure & private. Your number is safe with us.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                    child: _LegalFooter(
                      onPrivacyTap: () => _openExternal(_kPrivacyPolicyUrl),
                      onTermsTap: () => _openExternal(_kTermsOfServiceUrl),
                    ),
                  ),
                  SizedBox(height: bottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showLinkError();
      }
    } catch (_) {
      if (mounted) _showLinkError();
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open link. Please try again.")),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;

  const _LegalFooter({required this.onPrivacyTap, required this.onTermsTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'By continuing you agree to receive an SMS at the number above. '
          'Standard messaging rates may apply.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 11.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegalLink(
              label: 'Privacy policy',
              icon: Icons.shield_outlined,
              onTap: onPrivacyTap,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '|',
                style: TextStyle(
                  color: AppColors.textLight.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            _LegalLink(
              label: 'Terms of service',
              icon: Icons.description_outlined,
              onTap: onTermsTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _LegalLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
