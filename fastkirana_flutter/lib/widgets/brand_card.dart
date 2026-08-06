import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

/// Premium Card with brand styling and hover/press effects
class BrandCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool elevated;

  const BrandCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: margin ?? const EdgeInsets.only(bottom: AppDesignSystem.sm),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        boxShadow: elevated ? AppDesignSystem.shadowLg : AppDesignSystem.shadowSm,
        border: Border.all(color: AppDesignSystem.borderLight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDesignSystem.md),
            child: child,
          ),
        ),
      ),
    );
  }
}