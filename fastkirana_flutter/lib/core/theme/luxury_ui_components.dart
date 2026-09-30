import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system.dart';

/// 1. SKIPPER UI: Tactile Spring Tap Wrapper
/// Provides an iOS-like fluid spring scale bounce on tap + tactile haptic feedback.
class SkipperTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptic;

  const SkipperTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 140),
    this.enableHaptic = true,
  });

  @override
  State<SkipperTap> createState() => _SkipperTapState();
}

class _SkipperTapState extends State<SkipperTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 2. VENGEANCE UI: Specular Border Glow Card
/// High-end dark/light glass card with subtle neon perimeter glow and specular gradient border.
class VengeanceGlowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final bool enableGlow;
  final Color glowColor;
  final Gradient? borderGradient;
  final VoidCallback? onTap;

  const VengeanceGlowCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.enableGlow = true,
    this.glowColor = const Color(0xFF00B140),
    this.borderGradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceBg = backgroundColor ??
        (isDark ? AppDesignSystem.obsidianSurface : AppDesignSystem.surface);

    final resolvedBorderGradient = borderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? Colors.white.withValues(alpha: 0.22) : glowColor.withValues(alpha: 0.4),
            isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
            glowColor.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.5, 1.0],
        );

    Widget cardBody = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: enableGlow
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(1.2), // Specular border thickness
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: resolvedBorderGradient,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(borderRadius - 1.2),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return SkipperTap(
        onTap: onTap,
        child: cardBody,
      );
    }

    return cardBody;
  }
}

/// 3. ANIMASTER LIB: Liquid Wave Shimmer Skeleton Loader
/// Multi-stop diagonal specular wave for modern skeleton loading states.
class AnimasterLiquidShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const AnimasterLiquidShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.shape = BoxShape.rectangle,
  });

  const AnimasterLiquidShimmer.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 999.0,
        shape = BoxShape.circle;

  @override
  State<AnimasterLiquidShimmer> createState() => _AnimasterLiquidShimmerState();
}

class _AnimasterLiquidShimmerState extends State<AnimasterLiquidShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF161C26) : const Color(0xFFEFF1F5);
    final highlightColor = isDark ? const Color(0xFF2C384A) : Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
            gradient: LinearGradient(
              begin: Alignment(progress * 4.0 - 2.5, -0.4),
              end: Alignment(progress * 4.0 - 0.5, 0.4),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
