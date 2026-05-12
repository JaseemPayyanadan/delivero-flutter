import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_button.dart';

const String _kPrivacyPolicyUrl = 'https://delivero.app/privacy';
const String _kTermsOfServiceUrl = 'https://delivero.app/terms';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  static const _inputRadius = 14.0;
  static const _defaultCountryCode = 'IN';

  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  PhoneNumber? _phone;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onFocusChanged);
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _hasFocus = _phoneFocusNode.hasFocus);
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

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 18),
        Center(
          child: Hero(
            tag: 'app_logo',
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/images/logo.png',
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'DELIVERO',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Sign in with your phone',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "We'll send a 6-digit code to verify it's really you.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
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

  Widget _buildPhoneField({required bool isLoading}) {
    return IntlPhoneField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      initialCountryCode: _defaultCountryCode,
      disableLengthCheck: false,
      enabled: !isLoading,
      invalidNumberMessage: 'Please enter a valid mobile number',
      dropdownIconPosition: IconPosition.trailing,
      flagsButtonPadding: const EdgeInsets.only(left: 12, right: 4),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
      dropdownTextStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      dropdownIcon: const Icon(
        Icons.expand_more_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
      decoration: InputDecoration(
        hintText: '9876543210',
        hintStyle: const TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
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

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              if (authState.error case final String message) ...[
                _buildErrorBanner(message),
                const SizedBox(height: 20),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mobile number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _hasFocus ? 1 : 0,
                    child: const Text(
                      'Tap send to receive OTP',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPhoneField(isLoading: authState.isLoading),
              const SizedBox(height: 22),
              DeliveroButton(
                label: 'Send OTP',
                onPressed: authState.isLoading ? null : _handleSendOtp,
                isLoading: authState.isLoading,
                icon: Icons.sms_outlined,
                borderRadius: 12,
              ),
              const SizedBox(height: 18),
              _LegalFooter(
                onPrivacyTap: () => _openExternal(_kPrivacyPolicyUrl),
                onTermsTap: () => _openExternal(_kTermsOfServiceUrl),
              ),
            ],
          ),
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

  const _LegalFooter({
    required this.onPrivacyTap,
    required this.onTermsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: AppColors.textLight,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'By continuing you agree to receive an SMS at the number above. '
                'Standard messaging rates may apply.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _LegalLink(
              label: 'Privacy policy',
              icon: Icons.shield_outlined,
              onTap: onPrivacyTap,
            ),
            const _LegalLinkDivider(),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinkDivider extends StatelessWidget {
  const _LegalLinkDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: AppColors.textLight,
        shape: BoxShape.circle,
      ),
    );
  }
}
