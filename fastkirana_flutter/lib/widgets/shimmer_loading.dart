import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppDesignSystem.slate200,
      highlightColor: highlightColor ?? AppDesignSystem.slate50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: double.infinity, height: 110, borderRadius: 12),
          SizedBox(height: 10),
          ShimmerBox(width: 80, height: 12, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 60, height: 18, borderRadius: 4),
              ShimmerBox(width: 44, height: 32, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryShimmer extends StatelessWidget {
  const CategoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerBox(width: 60, height: 60, borderRadius: 30),
        SizedBox(height: 6),
        ShimmerBox(width: 50, height: 10, borderRadius: 4),
      ],
    );
  }
}

class OrderRowShimmer extends StatelessWidget {
  const OrderRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 16, borderRadius: 4),
              ShimmerBox(width: 70, height: 22, borderRadius: 6),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(width: 180, height: 12, borderRadius: 4),
          SizedBox(height: 8),
          ShimmerBox(width: 120, height: 12, borderRadius: 4),
          Divider(height: 20, color: AppDesignSystem.slate100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 80, height: 16, borderRadius: 4),
              ShimmerBox(width: 90, height: 32, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}
