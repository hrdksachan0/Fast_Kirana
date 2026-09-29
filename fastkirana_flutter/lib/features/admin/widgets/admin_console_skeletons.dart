import 'package:flutter/material.dart';
import '../../../core/theme/design_system.dart';
import '../../../widgets/shimmer_box.dart';

/// Shimmer Skeleton for Admin Order Card in Orders List Console
class AdminOrderCardSkeleton extends StatelessWidget {
  const AdminOrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar Skeleton (ID, Time, Outlet, Status Pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              children: [
                // Order ID Pill
                ShimmerBox(width: 72, height: 22, borderRadius: BorderRadius.circular(6)),
                const SizedBox(width: 8),
                // Time chip
                ShimmerBox(width: 52, height: 14, borderRadius: BorderRadius.circular(4)),
                const Spacer(),
                // Payment Status Badge
                ShimmerBox(width: 68, height: 20, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 6),
                // Status Pill
                ShimmerBox(width: 76, height: 22, borderRadius: BorderRadius.circular(10)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Customer & Address Details Skeleton
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar circle placeholder
                    const ShimmerBox(width: 36, height: 36, shape: BoxShape.circle),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ShimmerBox(width: 110, height: 14, borderRadius: BorderRadius.circular(4)),
                              const SizedBox(width: 8),
                              ShimmerBox(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ShimmerBox(width: double.infinity, height: 11, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 4),
                          ShimmerBox(width: 160, height: 11, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // 3. Order Items Preview Skeleton (2 simulated items)
                Row(
                  children: [
                    ShimmerBox(width: 18, height: 18, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 140, height: 12, borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    ShimmerBox(width: 28, height: 12, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 12),
                    ShimmerBox(width: 42, height: 12, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    ShimmerBox(width: 18, height: 18, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 100, height: 12, borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    ShimmerBox(width: 28, height: 12, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 12),
                    ShimmerBox(width: 36, height: 12, borderRadius: BorderRadius.circular(4)),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 11),

                // 4. Bottom Total & Action Buttons Skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 36, height: 10, borderRadius: BorderRadius.circular(3)),
                        const SizedBox(height: 4),
                        ShimmerBox(width: 64, height: 18, borderRadius: BorderRadius.circular(5)),
                      ],
                    ),
                    Row(
                      children: [
                        ShimmerBox(width: 74, height: 32, borderRadius: BorderRadius.circular(8)),
                        const SizedBox(width: 8),
                        ShimmerBox(width: 90, height: 32, borderRadius: BorderRadius.circular(8)),
                      ],
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

/// Full List Skeleton for Admin Orders Tab
class AdminOrdersListSkeleton extends StatelessWidget {
  final int itemCount;
  const AdminOrdersListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const AdminOrderCardSkeleton(),
    );
  }
}

/// Shimmer Skeleton for Vendor Console Screen
class VendorConsoleSkeleton extends StatelessWidget {
  const VendorConsoleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Banner Skeleton
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
                    ShimmerBox(width: 70, height: 14, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 50, height: 10, borderRadius: BorderRadius.circular(3)),
                            const SizedBox(height: 6),
                            ShimmerBox(width: 70, height: 16, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 50, height: 10, borderRadius: BorderRadius.circular(3)),
                            const SizedBox(height: 6),
                            ShimmerBox(width: 70, height: 16, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Order / Sales Cards Skeletons
          const AdminOrderCardSkeleton(),
          const AdminOrderCardSkeleton(),
          const AdminOrderCardSkeleton(),
        ],
      ),
    );
  }
}

/// Shimmer Skeleton for Rider Active Delivery Card
class RiderDeliveryCardSkeleton extends StatelessWidget {
  const RiderDeliveryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar (Order ID, Earnings Badge, Status)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                ShimmerBox(width: 72, height: 22, borderRadius: BorderRadius.circular(6)),
                const SizedBox(width: 8),
                ShimmerBox(width: 50, height: 14, borderRadius: BorderRadius.circular(4)),
                const Spacer(),
                ShimmerBox(width: 65, height: 20, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 6),
                ShimmerBox(width: 70, height: 22, borderRadius: BorderRadius.circular(10)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Pickup Point
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 24, height: 24, shape: BoxShape.circle),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 4),
                          ShimmerBox(width: double.infinity, height: 11, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Drop Point
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 24, height: 24, shape: BoxShape.circle),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 100, height: 14, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 4),
                          ShimmerBox(width: 180, height: 11, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Action Buttons (Maps navigation & Deliver)
                Row(
                  children: [
                    Expanded(
                      child: ShimmerBox(width: double.infinity, height: 42, borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ShimmerBox(width: double.infinity, height: 42, borderRadius: BorderRadius.circular(12)),
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

/// Shimmer Skeleton for Rider Dashboard
class RiderDashboardSkeleton extends StatelessWidget {
  final int itemCount;
  const RiderDashboardSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const RiderDeliveryCardSkeleton(),
    );
  }
}

/// Shimmer Skeleton for Restaurant KOT Order Card
class RestaurantOrderCardSkeleton extends StatelessWidget {
  const RestaurantOrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar (Token, Time elapsed, Order Type Badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                ShimmerBox(width: 80, height: 24, borderRadius: BorderRadius.circular(6)),
                const SizedBox(width: 8),
                ShimmerBox(width: 50, height: 14, borderRadius: BorderRadius.circular(4)),
                const Spacer(),
                ShimmerBox(width: 64, height: 20, borderRadius: BorderRadius.circular(10)),
                const SizedBox(width: 6),
                ShimmerBox(width: 75, height: 22, borderRadius: BorderRadius.circular(10)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Items Rows
                Row(
                  children: [
                    ShimmerBox(width: 22, height: 22, borderRadius: BorderRadius.circular(5)),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 130, height: 14, borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    ShimmerBox(width: 32, height: 14, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ShimmerBox(width: 22, height: 22, borderRadius: BorderRadius.circular(5)),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 100, height: 14, borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    ShimmerBox(width: 32, height: 14, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                // Action Buttons (Prep time / Food Ready / Print KOT)
                Row(
                  children: [
                    ShimmerBox(width: 70, height: 34, borderRadius: BorderRadius.circular(8)),
                    const SizedBox(width: 8),
                    ShimmerBox(width: 70, height: 34, borderRadius: BorderRadius.circular(8)),
                    const Spacer(),
                    ShimmerBox(width: 100, height: 34, borderRadius: BorderRadius.circular(8)),
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

/// Shimmer Skeleton for Restaurant Dashboard
class RestaurantDashboardSkeleton extends StatelessWidget {
  final int itemCount;
  const RestaurantDashboardSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const RestaurantOrderCardSkeleton(),
    );
  }
}
