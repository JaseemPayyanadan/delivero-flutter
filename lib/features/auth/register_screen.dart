import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_button.dart';
import '../../core/widgets/delivero_auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _inputRadius = 10.0;
  static const _inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, email and password')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    await ref
        .read(authProvider.notifier)
        .registerOwner(
          name: name,
          email: email,
          password: password,
          factoryName: '$name Factory',
          phone: phone.isEmpty ? null : phone,
        );
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
      borderSide: const BorderSide(color: AppColors.border, width: 1.2),
    );
  }

  InputDecoration _inputDecoration({
    required OutlineInputBorder inputBorder,
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: _inputPadding,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  Widget _buildHeader({required bool isLoading}) {
    return Row(
      children: [
        IconButton(
          onPressed: isLoading ? null : () => context.go('/login'),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Create Owner Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorLighter,
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildForm({
    required dynamic authState,
    required OutlineInputBorder inputBorder,
  }) {
    final isLoading = authState.isLoading == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (authState.error case final String message) ...[
          _buildErrorBanner(message),
          const SizedBox(height: 18),
        ],
        _buildLabel('Name'),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          enabled: !isLoading,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            inputBorder: inputBorder,
            hintText: 'Your name',
            prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Email'),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          enabled: !isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            inputBorder: inputBorder,
            hintText: 'name@company.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Phone (optional)'),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneController,
          enabled: !isLoading,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            inputBorder: inputBorder,
            hintText: '+91 9xxxx xxxxx',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Password'),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          enabled: !isLoading,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            inputBorder: inputBorder,
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: isLoading
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Confirm password'),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPasswordController,
          enabled: !isLoading,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleRegister(),
          decoration: _inputDecoration(
            inputBorder: inputBorder,
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            suffixIcon: IconButton(
              onPressed: isLoading
                  ? null
                  : () => setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textLight,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        DeliveroButton(
          label: 'Create Account',
          onPressed: isLoading ? null : _handleRegister,
          isLoading: isLoading,
          icon: Icons.person_add_rounded,
          borderRadius: 12,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account? ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: isLoading ? null : () => context.go('/login'),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final inputBorder = _inputBorder();

    return DeliveroAuthScaffold(
      header: Column(
        children: [
          _buildHeader(isLoading: authState.isLoading),
          const SizedBox(height: 18),
        ],
      ),
      child: _buildForm(authState: authState, inputBorder: inputBorder),
    );
  }
}
