import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/delivero_button.dart';
import '../../core/widgets/delivero_auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _inputRadius = 10.0;
  static const _inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      await ref.read(authProvider.notifier).login(email, password);
    } catch (e) {
      // Error is also handled in authProvider state
    }
  }

  void _showForgotDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Forgot Password',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This app uses admin-managed accounts. Please contact your admin/support team to reset your credentials.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _inputBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_inputRadius),
      borderSide: const BorderSide(color: AppColors.border, width: 1.2),
    );
  }

  InputDecoration _emailDecoration(OutlineInputBorder inputBorder) {
    return InputDecoration(
      hintText: 'name@company.com',
      prefixIcon: const Icon(Icons.email_outlined, size: 20),
      contentPadding: _inputPadding,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required OutlineInputBorder inputBorder,
    required bool isLoading,
  }) {
    return InputDecoration(
      hintText: '••••••••',
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      contentPadding: _inputPadding,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
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
                height: 52,
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
          'Welcome back',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to continue to your workspace',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.3,
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

  Widget _buildForm({
    required dynamic authState,
    required OutlineInputBorder inputBorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (authState.error case final String message) ...[
          _buildErrorBanner(message),
          const SizedBox(height: 20),
        ],
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          enabled: !authState.isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _emailDecoration(inputBorder),
        ),
        const SizedBox(height: 18),
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          enabled: !authState.isLoading,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
          decoration: _passwordDecoration(
            inputBorder: inputBorder,
            isLoading: authState.isLoading,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              child: Checkbox(
                value: _rememberMe,
                onChanged: authState.isLoading
                    ? null
                    : (value) => setState(() => _rememberMe = value ?? true),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Remember me',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: authState.isLoading ? null : _showForgotDialog,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        DeliveroButton(
          label: 'Sign in',
          onPressed: authState.isLoading ? null : _handleLogin,
          isLoading: authState.isLoading,
          icon: Icons.login_rounded,
          borderRadius: 12,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Don\'t have an account? ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () => context.go('/register'),
              child: const Text(
                'Create one',
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
      header: _buildHeader(),
      child: _buildForm(authState: authState, inputBorder: inputBorder),
    );
  }
}
