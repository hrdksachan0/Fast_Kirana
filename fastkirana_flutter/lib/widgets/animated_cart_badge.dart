import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/cart_provider.dart';

class AnimatedCartBadge extends ConsumerWidget {
  final Widget child;
  final Color badgeColor;
  final Color textColor;
  final VoidCallback? onTap;

  const AnimatedCartBadge({
    super.key,
    required this.child,
    this.badgeColor = AppDesignSystem.primary,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).valueOrNull;
    final int count = cart?.totalItems ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: child,
        ),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              key: ValueKey('cart_badge_$count'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
                .animate(key: ValueKey('badge_anim_$count'))
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.0, 1.0),
                  duration: 250.ms,
                  curve: Curves.elasticOut,
                ),
          ),
      ],
    );
  }
}
