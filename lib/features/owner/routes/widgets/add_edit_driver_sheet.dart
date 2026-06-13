import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/providers.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/delivery_route.dart';
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
      title: Text(title, style: ctx.appTextStyles.sectionHeader),
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
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('$e')));
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

/// Re-send the sign-in instructions to a driver via WhatsApp. Drivers sign in
/// with their phone + OTP, so all we need to share is the phone number.
Future<void> showReshareDriverLoginDialog(
  BuildContext context, {
  required Driver driver,
}) async {
  final message =
      'Hi ${driver.name},\n\nYour Delivro driver login is your phone number:\n\n${driver.phone}\n\n'
      'Open the Delivro app, tap "Sign in", enter this number and the OTP we send to confirm.';
  await showDriverLoginShareDialog(
    context: context,
    title: 'Share sign-in details',
    message: message,
    phone: driver.phone,
  );
}

Future<void> showAddEditDriverSheet(BuildContext context, {Driver? driver}) {
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
  ConsumerState<AddEditDriverSheet> createState() => _AddEditDriverSheetState();
}

class _AddEditDriverSheetState extends ConsumerState<AddEditDriverSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  PhoneNumber? _phoneNumber;
  String _initialPhoneE164 = '';
  late VehicleType _vehicle;
  String? _selectedRouteId;
  var _submitting = false;
  late final String _savedSignature;

  bool get _isEdit => widget.driver != null;
  bool get _isLinked =>
      _isEdit &&
      widget.driver!.status == DriverStatus.active &&
      (widget.driver!.userId?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameController = TextEditingController(text: d?.name);
    final initialPhone = d?.phone ?? '';
    _initialPhoneE164 = initialPhone;
    // IntlPhoneField needs just the national number for `initialValue`.
    _phoneController = TextEditingController(text: _nationalPart(initialPhone));
    _vehicle = d?.vehicleType ?? VehicleType.bike;
    _selectedRouteId = d?.currentRoute;
    _savedSignature = _formSignature();
  }

  String _formSignature() {
    final phone = _phoneNumber;
    final phoneSig = (phone != null && phone.number.trim().isNotEmpty)
        ? '+${phone.countryCode.replaceAll('+', '')}${_digitsOnlyPhone(phone.number)}'
        : _digitsOnlyPhone(_phoneController.text);
    return [
      _nameController.text.trim(),
      phoneSig,
      _vehicle.name,
      _selectedRouteId ?? '',
    ].join('::');
  }

  bool get _hasUnsavedChanges => _formSignature() != _savedSignature;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _nationalPart(String e164) {
    if (e164.isEmpty) return '';
    // Strip the leading + and the first 1-3 digit country code so the field
    // shows only the national number portion.
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return digits;
    // Best effort: assume the last 10 digits are the national number for IN.
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final phone = _phoneNumber;
    final rawDigits = _digitsOnlyPhone(_phoneController.text);
    if (name.isEmpty || (phone == null && rawDigits.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter name and phone number.')),
      );
      return;
    }

    final phoneE164 = () {
      if (phone != null && phone.number.trim().isNotEmpty) {
        final dialCode = phone.countryCode.replaceAll('+', '').trim();
        final numberDigits = _digitsOnlyPhone(phone.number);
        return '+$dialCode$numberDigits';
      }

      final initial = _initialPhoneE164.trim();
      if (initial.isNotEmpty) return initial;

      final digits = rawDigits;
      final dialCodeDigits = _initialPhoneE164.replaceAll(RegExp(r'\D'), '');
      final inferredDial = dialCodeDigits.length > 10
          ? dialCodeDigits.substring(0, dialCodeDigits.length - 10)
          : '91';
      return '+$inferredDial$digits';
    }();

    if (_isLinked &&
        _initialPhoneE164.isNotEmpty &&
        phoneE164 != _initialPhoneE164) {
      final confirmed = await _confirmLinkedPhoneChange();
      if (!mounted || confirmed != true) return;
    }

    final factoryId = await ref.read(factoryIdProvider.future);
    if (factoryId == null || factoryId.isEmpty) return;
    if (!mounted) return;

    setState(() => _submitting = true);

    try {
      if (_isEdit) {
        final d = widget.driver!;
        final previousRouteId = d.currentRoute;
        final updated = d.copyWith(
          name: name,
          phone: phoneE164,
          vehicleType: _vehicle,
          currentRoute: _selectedRouteId,
          updatedAt: DateTime.now(),
        );
        await FirebaseService.firestore.runTransaction((tx) async {
          final driversRef = FirebaseService.firestore.collection('drivers');
          final routesRef = FirebaseService.firestore.collection('routes');

          final newRouteId = _selectedRouteId;

          if (previousRouteId != null &&
              previousRouteId.trim().isNotEmpty &&
              previousRouteId != newRouteId) {
            final prevRouteRef = routesRef.doc(previousRouteId);
            final prevRouteSnap = await tx.get(prevRouteRef);
            if (prevRouteSnap.exists) {
              final data = prevRouteSnap.data();
              final assignedDriverId = (data?['assignedDriver'] as String?)
                  ?.trim();
              if (assignedDriverId == d.id) {
                tx.update(prevRouteRef, {
                  'assignedDriver': null,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
            }
          }

          if (newRouteId != null && newRouteId.trim().isNotEmpty) {
            final nextRouteRef = routesRef.doc(newRouteId);
            final nextRouteSnap = await tx.get(nextRouteRef);
            if (nextRouteSnap.exists) {
              final data = nextRouteSnap.data();
              final previousDriverId = (data?['assignedDriver'] as String?)
                  ?.trim();
              if (previousDriverId != null &&
                  previousDriverId.isNotEmpty &&
                  previousDriverId != d.id) {
                tx.update(driversRef.doc(previousDriverId), {
                  'currentRoute': null,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              tx.update(nextRouteRef, {
                'assignedDriver': d.id,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }

          tx.set(driversRef.doc(d.id), updated.toJson());
        });
        if (mounted) Navigator.pop(context);
      } else {
        final created = await ref
            .read(authProvider.notifier)
            .inviteDriver(
              name: name,
              phoneE164: phoneE164,
              factoryId: factoryId,
              vehicleType: _vehicle,
              currentRoute: _selectedRouteId,
            );

        if (!mounted) return;
        await _showCreateShareDialog(driver: created);
        if (mounted) Navigator.pop(context);
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

  Future<bool?> _confirmLinkedPhoneChange() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Change linked phone?'),
        content: const Text(
          'This driver already signs in with their current number. '
          'Changing it will not transfer the existing account — they will '
          'need to sign in with the new number to re-link.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Keep current',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Change anyway',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateShareDialog({required Driver driver}) async {
    final message =
        'Hi ${driver.name},\n\nYour Delivro driver profile is ready.\n\n'
        'Open the Delivro app, tap "Sign in", enter this number:\n${driver.phone}\n'
        'and verify the OTP to start delivering.';
    await showDriverLoginShareDialog(
      context: context,
      title: 'Share sign-in details',
      message: message,
      phone: driver.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final routes = ref.watch(routesProvider);
    final sortedRoutes = [...routes]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final hasSelectedRouteInList =
        _selectedRouteId != null &&
        sortedRoutes.any((r) => r.id == _selectedRouteId);
    final routeDropdownValue = hasSelectedRouteInList ? _selectedRouteId : null;

    return UnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !_submitting,
      child: Padding(
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
                      'Drivers sign in to Delivro with their phone number and OTP. '
                      'Use a phone they have access to.',
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
                    IntlPhoneField(
                      controller: _phoneController,
                      initialCountryCode: 'IN',
                      disableLengthCheck: false,
                      invalidNumberMessage:
                          'Please enter a valid mobile number',
                      dropdownIconPosition: IconPosition.trailing,
                      decoration: _driverSheetInputDecoration(
                        label: 'Phone',
                        hint: '00000 00000',
                      ),
                      onChanged: (phone) => _phoneNumber = phone,
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
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: routeDropdownValue,
                      isExpanded: true,
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'No route assigned',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        ...sortedRoutes.map<DropdownMenuItem<String?>>((
                          DeliveryRoute r,
                        ) {
                          final area = r.area.trim();
                          final label = area.isEmpty
                              ? r.name
                              : '${r.name} · $area';
                          return DropdownMenuItem<String?>(
                            value: r.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.alt_route_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: _submitting
                          ? null
                          : (val) => setState(() => _selectedRouteId = val),
                      decoration: _driverSheetInputDecoration(
                        label: 'Route',
                        hint: sortedRoutes.isEmpty
                            ? 'No routes available yet'
                            : 'Optional',
                      ),
                    ),
                    if (_isLinked) ...[
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
                                    'Sign-in active',
                                    style: context.appTextStyles.caption
                                        .copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.driver!.phone,
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
                    ] else if (_isEdit) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningLighter,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.hourglass_top_rounded,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pending first sign-in. Driver will activate '
                                'on their first OTP login.',
                                style: context.appTextStyles.caption.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            onPressed: _submitting
                                ? null
                                : () {
                                    try {
                                      HapticFeedback.selectionClick();
                                    } catch (_) {}
                                    _onSave();
                                  },
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
                                    _isEdit ? 'Save' : 'Create driver',
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
    ),
    );
  }
}
