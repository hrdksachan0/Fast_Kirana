import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/coupon_provider.dart';
import '../../data/models/coupon.dart';

class AdminCouponsScreen extends ConsumerWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(couponsProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          'Coupons Management',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppDesignSystem.primary),
            onPressed: () => ref.invalidate(couponsProvider),
          ),
        ],
      ),
      body: couponsAsync.when(
        data: (coupons) {
          if (coupons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('🎟️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 28)))),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Coupons Created Yet',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create coupons in Web Admin Portal to offer discounts to customers.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final c = coupons[index];
              final discountText = c.discountType == DiscountType.percent
                  ? 'FLAT ${c.value.toInt()}% OFF'
                  : 'FLAT ₹${c.value.toInt()} OFF';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignSystem.borderLight),
                  boxShadow: AppDesignSystem.shadowSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.code, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.isActive ? AppDesignSystem.success.withValues(alpha: 0.1) : AppDesignSystem.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  c.isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9), fontWeight: FontWeight.w800, color: c.isActive ? AppDesignSystem.success : AppDesignSystem.danger),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$discountText • Min: ₹${c.minOrder.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading coupons: $err')),
      ),
    );
  }
}