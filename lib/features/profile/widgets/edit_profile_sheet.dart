import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';

/// Edits the signed-in user's display name, and — for owners — the business
/// name and address. The phone number is the login identity, so it is shown but
/// not editable.
Future<void> showEditProfileSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String name,
  required String phone,
  required bool isDelivery,
  String? companyName,
  String? companyAddress,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _EditProfileSheet(
        ref: ref,
        name: name,
        phone: phone,
        isDelivery: isDelivery,
        companyName: companyName ?? '',
        companyAddress: companyAddress ?? '',
      ),
    ),
  );
}

class _EditProfileSheet extends StatefulWidget {
  final WidgetRef ref;
  final String name;
  final String phone;
  final bool isDelivery;
  final String companyName;
  final String companyAddress;

  const _EditProfileSheet({
    required this.ref,
    required this.name,
    required this.phone,
    required this.isDelivery,
    required this.companyName,
    required this.companyAddress,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _addressController;
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name.trim());
    _companyController = TextEditingController(text: widget.companyName.trim());
    _addressController = TextEditingController(
      text: widget.companyAddress.trim(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter your name.');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final ref = widget.ref;
    try {
      await ref.read(authProvider.notifier).updateOwnerName(name);

      if (!widget.isDelivery) {
        await _saveFactory(
          ref,
          name: _companyController.text.trim(),
          address: _addressController.text.trim(),
        );
        ref.invalidate(factoryProvider);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile updated',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not save. Check your connection.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _saveFactory(
    WidgetRef ref, {
    required String name,
    required String address,
  }) async {
    if (name.isEmpty && address.isEmpty) return;
    final factoryId = ref.read(factoryIdProvider).asData?.value;
    if (factoryId == null ||
        factoryId.trim().isEmpty ||
        !FirebaseService.isInitialized) {
      return;
    }
    await FirebaseService.firestore
        .collection('factories')
        .doc(factoryId)
        .set({
          'name': name,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'YOUR NAME',
              controller: _nameController,
              hint: 'Full name',
              icon: Icons.person_rounded,
              errorText: _nameError,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            _ReadOnlyField(
              label: 'PHONE',
              value: widget.phone.trim().isEmpty ? '—' : widget.phone.trim(),
              note: 'Used to sign in — cannot be changed here.',
            ),
            if (!widget.isDelivery) ...[
              const SizedBox(height: 14),
              _Field(
                label: 'BUSINESS NAME',
                controller: _companyController,
                hint: 'e.g. Delivero Foods',
                icon: Icons.storefront_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'BUSINESS ADDRESS',
                controller: _addressController,
                hint: 'Street, city',
                icon: Icons.location_on_rounded,
                maxLines: 2,
                textCapitalization: TextCapitalization.words,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? errorText;
  final int maxLines;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.errorText,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          note,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }
}
