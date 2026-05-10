import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/driver.dart';

InputDecoration _driverSheetInputDecoration({
  required String label,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.backgroundSecondary,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

String _vehicleAsset(VehicleType type) {
  switch (type) {
    case VehicleType.bike:
      return 'assets/images/scooty.png';
    case VehicleType.scooter:
      return 'assets/images/scooter.webp';
    case VehicleType.auto:
      return 'assets/images/auto.png';
    case VehicleType.van:
      return 'assets/images/scooter.webp';
  }
}

String _suggestDriverEmail(String name) {
  var slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
      .replaceAll(RegExp(r'^\.+|\.+$'), '');
  if (slug.isEmpty) slug = 'driver';
  final tail = Random.secure().nextInt(9000) + 1000;
  return '$slug.drv$tail@delivero.driver';
}

String _generateDriverPassword() {
  const chars =
      'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
}

String _digitsOnlyPhone(String phone) {
  return phone.replaceAll(RegExp(r'\D'), '');
}

Future<void> _openWhatsAppShare({
  required String phone,
  required String message,
}) async {
  final digits = _digitsOnlyPhone(phone);
  if (digits.isEmpty) {
    throw Exception('Add a phone number on the driver to share via WhatsApp.');
  }
  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    throw Exception('Could not open WhatsApp.');
  }
}

Future<void> showDriverLoginShareDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String phone,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        title,
        style: ctx.appTextStyles.sectionHeader,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              message,
              style: const TextStyle(
                height: 1.45,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Close',
            style: ctx.appTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await _openWhatsAppShare(phone: phone, message: message);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.chat_rounded, size: 20),
          label: const Text(
            'WhatsApp',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

/// Resend login email via WhatsApp (password is not stored in the app).
Future<void> showReshareDriverLoginDialog(
  BuildContext context, {
  required Driver driver,
}) async {
  final email = driver.email?.trim();
  if (email == null || email.isEmpty) return;
  final message =
      'Hi ${driver.name},\n\nYour Delivero driver app login email:\n\n$email\n\n'
      'Open the Delivero app and sign in with this email and your password.\n\n'
      'Forgot password? On the sign-in screen tap "Forgot password?" or contact your manager.';
  await showDriverLoginShareDialog(
    context: context,
    title: 'Share login',
    message: message,
    phone: driver.phone,
  );
}

Future<void> showAddEditDriverSheet(
  BuildContext context, {
  Driver? driver,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AddEditDriverSheet(driver: driver),
  );
}

class AddEditDriverSheet extends ConsumerStatefulWidget {
  final Driver? driver;

  const AddEditDriverSheet({super.key, this.driver});

  @override
  ConsumerState<AddEditDriverSheet> createState() =>
      _AddEditDriverSheetState();
}

class _AddEditDriverSheetState extends ConsumerState<AddEditDriverSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late VehicleType _vehicle;
  var _obscurePassword = true;
  var _createLogin = false;
  var _submitting = false;

  bool get _isEdit => widget.driver != null;

  bool get _canOfferLogin =>
      !_isEdit || (widget.driver!.email == null || widget.driver!.email!.isEmpty);

  bool get _hasExistingLogin =>
      _isEdit &&
      widget.driver!.email != null &&
      widget.driver!.email!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameController = TextEditingController(text: d?.name);
    _phoneController = TextEditingController(text: d?.phone);
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _vehicle = d?.vehicleType ?? VehicleType.bike;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _fillGeneratedCredentials() {
    final email = _suggestDriverEmail(_nameController.text);
    final password = _generateDriverPassword();
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _createLogin = true;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _showCredentialsDialog({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    if (!mounted) return;
    final message =
        'Hi $name,\n\nYour Delivero driver app login:\n\nEmail: $email\nPassword: $password\n\nUse these in the Delivero app to sign in.';
    await showDriverLoginShareDialog(
      context: context,
      title: 'Share login details',
      message: message,
      phone: phone,
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[^@]+@[^@]+\.[^@]+$',
    ).hasMatch(value.trim());
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name and phone.')),
      );
      return;
    }

    final factoryId =
        await ref.read(factoryIdProvider.future) ?? 'FAC_00001';
    if (!mounted) return;

    final emailTrim = _emailController.text.trim();
    final password = _passwordController.text;

    if (_createLogin && _canOfferLogin) {
      if (!_isValidEmail(emailTrim)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid email for the driver login.')),
        );
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    final d = widget.driver;
    final driverId = d?.id ?? const Uuid().v4();
    final newDriver = Driver(
      id: driverId,
      factoryId: factoryId,
      name: name,
      email: _createLogin && _canOfferLogin
          ? emailTrim.toLowerCase()
          : d?.email,
      phone: phone,
      vehicleType: _vehicle,
      licenseNumber: d?.licenseNumber,
      isActive: d?.isActive ?? true,
      currentRoute: d?.currentRoute,
      createdAt: d?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (_isEdit) {
        if (_createLogin && _canOfferLogin) {
          await ref.read(authProvider.notifier).registerDriverAccount(
                name: name,
                email: emailTrim,
                password: password,
                driverId: driverId,
                factoryId: factoryId,
                phone: phone,
              );
          ref.read(driversProvider.notifier).updateDriver(newDriver);
          if (mounted) {
            await _showCredentialsDialog(
              name: name,
              email: emailTrim.toLowerCase(),
              password: password,
              phone: phone,
            );
          }
          if (mounted) Navigator.pop(context);
        } else {
          ref.read(driversProvider.notifier).updateDriver(newDriver);
          if (mounted) Navigator.pop(context);
        }
      } else {
        ref.read(driversProvider.notifier).addDriver(newDriver);
        if (_createLogin) {
          try {
            await ref.read(authProvider.notifier).registerDriverAccount(
                  name: name,
                  email: emailTrim,
                  password: password,
                  driverId: driverId,
                  factoryId: factoryId,
                  phone: phone,
                );
            if (mounted) {
              await _showCredentialsDialog(
                name: name,
                email: emailTrim.toLowerCase(),
                password: password,
                phone: phone,
              );
            }
            if (mounted) Navigator.pop(context);
          } catch (e) {
            ref.read(driversProvider.notifier).deleteDriver(driverId);
            rethrow;
          }
        } else {
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'Something went wrong',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEdit ? 'Edit driver' : 'New driver',
                      style: context.appTextStyles.sectionHeader,
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Image.asset(
                          _vehicleAsset(_vehicle),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Vehicle type sets the icon on route cards and driver lists.',
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _driverSheetInputDecoration(
                        label: 'Full name',
                        hint: 'e.g. Rahul Kumar',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      decoration: _driverSheetInputDecoration(
                        label: 'Phone',
                        hint: '+91 00000 00000',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<VehicleType>(
                      initialValue: _vehicle,
                      items: VehicleType.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Image.asset(
                                      _vehicleAsset(v),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    v.name.isEmpty
                                        ? v.name
                                        : '${v.name[0].toUpperCase()}${v.name.substring(1)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _vehicle = val ?? VehicleType.bike),
                      decoration: _driverSheetInputDecoration(label: 'Vehicle'),
                    ),
                    if (_hasExistingLogin) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'App login',
                                    style: context.appTextStyles.caption
                                        .copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.driver!.email!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_canOfferLogin) ...[
                      const SizedBox(height: 20),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Create app login',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'Email & password for the driver Delivero account',
                          style: context.appTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: _createLogin,
                        activeThumbColor: AppColors.primary,
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _createLogin = v),
                      ),
                      if (_createLogin) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _submitting ? null : _fillGeneratedCredentials,
                            icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                            label: const Text(
                              'Generate email & password',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: _driverSheetInputDecoration(
                            label: 'Login email',
                            hint: 'driver@example.com',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _driverSheetInputDecoration(
                            label: 'Password',
                            hint: 'At least 6 characters',
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _submitting ? null : _onSave,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isEdit ? 'Save' : 'Add driver',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
