import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ManagementSearchFilters extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<ManagementFilterChip> chips;
  final String hintText;

  const ManagementSearchFilters({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.chips,
    this.hintText = 'Search…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.textLight.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (int i = 0; i < chips.length; i++) ...[
                chips[i],
                if (i != chips.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class ManagementFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ManagementFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? onPrimary : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
