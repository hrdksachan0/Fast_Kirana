import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';

class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDesignSystem.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              color: AppDesignSystem.surfaceMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
              child: SizedBox(width: 32, height: 32,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.textTertiary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14, width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14, width: 80,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 20, width: 60,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      height: 32, width: 32,
                      decoration: const BoxDecoration(
                        color: AppDesignSystem.surfaceMuted, shape: BoxShape.circle,
                      ),
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

class OrderCardShimmer extends StatelessWidget {
  const OrderCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppDesignSystem.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14, width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12, width: 120,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
