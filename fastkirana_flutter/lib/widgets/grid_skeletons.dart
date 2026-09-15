import 'package:flutter/material.dart';
import '../core/theme/design_system.dart';
import 'shimmer_box.dart';

/// 1:1 Bone-Structure Skeleton for Category Bento Grids (Zero CLS)
class CategoryBentoSkeleton extends StatelessWidget {
  final int count;
  final bool isCafeMode;

  const CategoryBentoSkeleton({
    super.key,
    this.count = 8,
    this.isCafeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppDesignSystem.slate100,
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: ShimmerBox(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const ShimmerBox(
                width: 52,
                height: 10,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              const SizedBox(height: 3),
              const ShimmerBox(
                width: 36,
                height: 8,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 1:1 Bone-Structure Skeleton for 2-Column Product Feeds (Zero CLS)
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  final EdgeInsets padding;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.65,
        ),
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
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
                // Top Tag + Thumbnail Box
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.slate50,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: ShimmerBox(
                            width: 72,
                            height: 72,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                        ),
                        // Top Discount Badge Placeholder
                        Positioned(
                          top: 8,
                          left: 8,
                          child: ShimmerBox(
                            width: 44,
                            height: 18,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Meta & Pricing Details
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(
                              width: 50,
                              height: 11,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                            SizedBox(height: 6),
                            ShimmerBox(
                              width: double.infinity,
                              height: 13,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                            SizedBox(height: 4),
                            ShimmerBox(
                              width: 80,
                              height: 13,
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                          ],
                        ),
                        // Price Tag + ADD Button Stepper Placeholder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShimmerBox(
                                  width: 42,
                                  height: 16,
                                  borderRadius: BorderRadius.all(Radius.circular(4)),
                                ),
                                SizedBox(height: 3),
                                ShimmerBox(
                                  width: 32,
                                  height: 10,
                                  borderRadius: BorderRadius.all(Radius.circular(3)),
                                ),
                              ],
                            ),
                            ShimmerBox(
                              width: 58,
                              height: 32,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 1:1 Bone-Structure Skeleton for Hero Banner Carousel
class HeroBannerSkeleton extends StatelessWidget {
  final double height;
  final EdgeInsets margin;

  const HeroBannerSkeleton({
    super.key,
    this.height = 145,
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 80, height: 16, borderRadius: BorderRadius.all(Radius.circular(6))),
                  SizedBox(height: 10),
                  ShimmerBox(width: 140, height: 20, borderRadius: BorderRadius.all(Radius.circular(6))),
                  SizedBox(height: 6),
                  ShimmerBox(width: 100, height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
                ],
              ),
            ),
            ShimmerBox(
              width: 85,
              height: 85,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1:1 Bone-Structure Skeleton for Cart Summary & Items
class CartShimmerSkeleton extends StatelessWidget {
  const CartShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Savings banner skeleton
        const ShimmerBox(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        const SizedBox(height: 16),
        // Item list skeleton
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.slate100),
          ),
          child: Column(
            children: List.generate(3, (index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  ShimmerBox(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(10))),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.all(Radius.circular(4))),
                        SizedBox(height: 6),
                        ShimmerBox(width: 60, height: 12, borderRadius: BorderRadius.all(Radius.circular(4))),
                      ],
                    ),
                  ),
                  ShimmerBox(width: 70, height: 32, borderRadius: BorderRadius.all(Radius.circular(8))),
                ],
              ),
            )),
          ),
        ),
        const SizedBox(height: 16),
        // Bill card skeleton
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.slate100),
          ),
          child: const Column(
            children: [
              ShimmerBox(width: double.infinity, height: 16, borderRadius: BorderRadius.all(Radius.circular(4))),
              SizedBox(height: 12),
              ShimmerBox(width: double.infinity, height: 16, borderRadius: BorderRadius.all(Radius.circular(4))),
              SizedBox(height: 12),
              ShimmerBox(width: double.infinity, height: 22, borderRadius: BorderRadius.all(Radius.circular(6))),
            ],
          ),
        ),
      ],
    );
  }
}
