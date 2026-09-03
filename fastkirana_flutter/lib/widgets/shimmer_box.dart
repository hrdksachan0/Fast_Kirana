import 'package:flutter/material.dart';

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? BorderRadius.circular(8)),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _controller.value * 3, -0.3),
              end: Alignment(0.5 + _controller.value * 3, 0.3),
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFF1F5F9),
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Product Card Skeleton for Horizontal Rails & Vertical Grids
class ProductCardSkeleton extends StatelessWidget {
  final double width;
  const ProductCardSkeleton({super.key, this.width = 148});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Stack(
              children: [
                const ShimmerBox(
                  width: double.infinity,
                  height: 120,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: ShimmerBox(
                    width: 44,
                    height: 16,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery time / tag
                ShimmerBox(width: 50, height: 10, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                // Title line 1
                ShimmerBox(width: double.infinity, height: 12, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 4),
                // Title line 2
                ShimmerBox(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                // Weight / Unit
                ShimmerBox(width: 45, height: 10, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 10),
                // Price & Add Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 42, height: 14, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 3),
                        ShimmerBox(width: 30, height: 9, borderRadius: BorderRadius.circular(3)),
                      ],
                    ),
                    ShimmerBox(
                      width: 54,
                      height: 28,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Category Circular Avatar Skeleton
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            ),
            child: const ShimmerBox(
              width: 64,
              height: 64,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          ShimmerBox(width: 48, height: 10, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 3),
          ShimmerBox(width: 32, height: 8, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }
}

/// Restaurant Card Skeleton for Food Mode
class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Skeleton
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Stack(
              children: [
                const ShimmerBox(
                  width: double.infinity,
                  height: 140,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: ShimmerBox(
                    width: 70,
                    height: 22,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ShimmerBox(
                    width: 80,
                    height: 24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Outlet Name + Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 140, height: 16, borderRadius: BorderRadius.circular(5)),
                    ShimmerBox(width: 48, height: 20, borderRadius: BorderRadius.circular(6)),
                  ],
                ),
                const SizedBox(height: 8),
                // Cuisine tags
                ShimmerBox(width: 200, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 12),
                // Divider
                Container(height: 1, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                // Bottom stats & CTA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ShimmerBox(width: 70, height: 12, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(width: 12),
                        ShimmerBox(width: 60, height: 12, borderRadius: BorderRadius.circular(4)),
                      ],
                    ),
                    ShimmerBox(width: 80, height: 28, borderRadius: BorderRadius.circular(8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section Header Skeleton (Category title + Subtitle + See all button)
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 130, height: 16, borderRadius: BorderRadius.circular(5)),
              const SizedBox(height: 4),
              ShimmerBox(width: 180, height: 11, borderRadius: BorderRadius.circular(4)),
            ],
          ),
          ShimmerBox(width: 65, height: 24, borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }
}

/// Banner Skeleton
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const ShimmerBox(
        height: 130,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    );
  }
}