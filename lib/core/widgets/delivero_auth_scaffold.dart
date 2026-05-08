import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DeliveroAuthScaffold extends StatelessWidget {
  final Widget header;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry cardPadding;

  const DeliveroAuthScaffold({
    super.key,
    required this.header,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 32),
    this.cardPadding = const EdgeInsets.fromLTRB(24, 24, 24, 22),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Container(
                padding: cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowDeep,
                      blurRadius: 50,
                      offset: Offset(0, 24),
                    ),
                  ],
                ),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
