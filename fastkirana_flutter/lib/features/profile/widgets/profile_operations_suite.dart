import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../admin/admin_dashboard.dart';
import '../../admin/vendor_console_screen.dart';
import '../../delivery/delivery_dashboard.dart';
import '../../delivery/picker_dashboard.dart';
import '../../cafe/restaurant_dashboard.dart';

class ProfileOperationsSuite extends StatelessWidget {
  final bool isAdmin;
  final bool isRiderOnly;
  final bool isChefOrOwnerOnly;
  final bool isPickerOnly;
  final bool isVendorOnly;
  final String? assignedRestaurantId;
  final String? assignedVendorId;

  const ProfileOperationsSuite({
    super.key,
    required this.isAdmin,
    required this.isRiderOnly,
    required this.isChefOrOwnerOnly,
    required this.isPickerOnly,
    this.isVendorOnly = false,
    this.assignedRestaurantId,
    this.assignedVendorId,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppDesignSystem.slate200),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.slate900.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.statusPending,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bolt_rounded, size: 16, color: AppDesignSystem.amber600),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Operations Command Suite',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.green100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ADMIN',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 8.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.green700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOperationBentoTile(
                      context: context,
                      title: 'Admin Console',
                      subtitle: 'Store & Orders',
                      emoji: '🛡️',
                      badge: 'ADMIN',
                      bgTint: AppDesignSystem.amber50,
                      borderColor: AppDesignSystem.yellow200,
                      textColor: AppDesignSystem.statusPendingText,
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const AdminDashboard())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildOperationBentoTile(
                      context: context,
                      title: 'Rider Console',
                      subtitle: 'GPS & Deliveries',
                      emoji: '🛵',
                      badge: 'RIDER',
                      bgTint: AppDesignSystem.green50,
                      borderColor: AppDesignSystem.green200,
                      textColor: AppDesignSystem.green800,
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const DeliveryDashboard())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildOperationBentoTile(
                      context: context,
                      title: 'Kitchen KOT',
                      subtitle: 'Cooking Orders',
                      emoji: '👨‍🍳',
                      badge: 'KITCHEN',
                      bgTint: AppDesignSystem.statusCancelled,
                      borderColor: AppDesignSystem.red200,
                      textColor: AppDesignSystem.statusCancelledText,
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const RestaurantDashboard())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildOperationBentoTile(
                      context: context,
                      title: 'Picker Hub',
                      subtitle: 'Item Packing',
                      emoji: '📦',
                      badge: 'PICKER',
                      bgTint: AppDesignSystem.orange50,
                      borderColor: AppDesignSystem.orange300,
                      textColor: AppDesignSystem.amber800,
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const PickerDashboard())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildOperationBentoTile(
                      context: context,
                      title: 'Vendor Hub',
                      subtitle: 'Suppliers & Rates',
                      emoji: '🏪',
                      badge: 'VENDORS',
                      bgTint: const Color(0xFFFFF7ED),
                      borderColor: const Color(0xFFFED7AA),
                      textColor: const Color(0xFFC2410C),
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const VendorConsoleScreen())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (isVendorOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              FadeSlideRoute(
                page: VendorConsoleScreen(
                  initialVendorId: assignedVendorId,
                  isVendorSelf: true,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Center(child: Text('🏪', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Supplier Partner Portal',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'SUPPLIER',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 8.5),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Live store orders, products, rates & sales payouts',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isRiderOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, FadeSlideRoute(page: const DeliveryDashboard()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF047857), // emerald 700
                  Color(0xFF059669), // emerald 600
                  Color(0xFF10B981), // emerald 500
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Delivery Partner Dashboard',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6EE7B7),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Open GPS navigation & active order pickups',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isChefOrOwnerOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              FadeSlideRoute(
                page: RestaurantDashboard(initialRestaurantId: assignedRestaurantId),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppDesignSystem.rose900, AppDesignSystem.rose600, Color(0xFFBE123C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.rose600.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Restaurant Kitchen Console',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'KITCHEN',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 8.5),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manage live cooking orders, KOT slips & menu',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isPickerOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, FadeSlideRoute(page: const PickerDashboard()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(child: Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Picker Hub Console',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'PICKER',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 8.5),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pack orders, scan barcodes & assign riders',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildOperationBentoTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String emoji,
    required String badge,
    required Color bgTint,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(emoji, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 8),
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
