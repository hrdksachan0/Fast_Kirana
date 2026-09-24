import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/config/app_config.dart';
import 'order_recipient_helper.dart';

/// Clean "Stop 1 → Stop 2" Delivery Roadmap Card for Rider App
/// Displayed when 2 nearby batched orders are active/out for delivery.
class RiderBatchRoadmapCard extends StatelessWidget {
  final Map<String, dynamic> stop1Order;
  final Map<String, dynamic> stop2Order;
  final num? distanceBetweenMeters;
  final void Function(double lat, double lng, String label, {String? address})? onOpenNavigation;

  const RiderBatchRoadmapCard({
    super.key,
    required this.stop1Order,
    required this.stop2Order,
    this.distanceBetweenMeters,
    this.onOpenNavigation,
  });

  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color emeraldGreen = AppDesignSystem.emeraldBrand;

  @override
  Widget build(BuildContext context) {
    final order1Id = stop1Order['id']?.toString() ?? '';
    final order1Num = stop1Order['readableId'] ?? order1Id.substring(0, math.min(8, order1Id.length));
    final addr1 = stop1Order['address'] is Map ? stop1Order['address'] : null;
    final lat1 = (addr1?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng1 = (addr1?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
    final recip1 = OrderRecipientDetails.fromOrder(stop1Order);
    final name1 = recip1.recipientName;
    final formattedAddr1 = addr1?['formattedAddress']?.toString().trim() ??
        '${addr1?['houseNo'] ?? ''} ${addr1?['area'] ?? 'Ghatampur'}'.trim();

    final order2Id = stop2Order['id']?.toString() ?? '';
    final order2Num = stop2Order['readableId'] ?? order2Id.substring(0, math.min(8, order2Id.length));
    final addr2 = stop2Order['address'] is Map ? stop2Order['address'] : null;
    final lat2 = (addr2?['lat'] as num?)?.toDouble() ?? AppConfig.darkstoreLat;
    final lng2 = (addr2?['lng'] as num?)?.toDouble() ?? AppConfig.darkstoreLng;
    final recip2 = OrderRecipientDetails.fromOrder(stop2Order);
    final name2 = recip2.recipientName;
    final formattedAddr2 = addr2?['formattedAddress']?.toString().trim() ??
        '${addr2?['houseNo'] ?? ''} ${addr2?['area'] ?? 'Ghatampur'}'.trim();

    final dist = distanceBetweenMeters ?? 650;
    final distText = dist < 1000 ? '$dist m' : '${(dist / 1000).toStringAsFixed(1)} km';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppDesignSystem.blue200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.blue600.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ambient Gradient Header Strip
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF0D9488), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppDesignSystem.blue200, width: 1),
                          ),
                          child: const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMART BATCH ROADMAP',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1D4ED8),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              'Stop 1 ➔ Stop 2 Combined Route',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            '+₹24 Bonus',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Roadmap Timeline
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.slate200, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Pickup Node
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 24,
                                color: const Color(0xFF34D399),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Store / Kitchen Pickup Complete',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Stop 1 Node (Active Drop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 2,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF93C5FD),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'STOP 1: $name1',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 12),
                                            fontWeight: FontWeight.w900,
                                            color: slateDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 8.5),
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF1E40AF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '#$order1Num',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w700,
                                        color: slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedAddr1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    color: slateMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Distance Gap indicator between drops
                      Row(
                        children: [
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.straighten_rounded, size: 11, color: Color(0xFFB45309)),
                                const SizedBox(width: 3),
                                Text(
                                  'Only $distText to next drop',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Stop 2 Node
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF6B7280), width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '2',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'STOP 2: $name2',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 12),
                                            fontWeight: FontWeight.w800,
                                            color: slateDark,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppDesignSystem.slate200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'NEXT',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 8.5),
                                              fontWeight: FontWeight.w900,
                                              color: AppDesignSystem.slate600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '#$order2Num',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w700,
                                        color: slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formattedAddr2,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    color: slateMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Navigation Actions
                Row(
                  children: [
                    Expanded(
                      child: Bounceable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onOpenNavigation?.call(lat1, lng1, 'Stop 1: $name1', address: formattedAddr1);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.navigation_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Navigate Stop 1',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Bounceable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onOpenNavigation?.call(lat2, lng2, 'Stop 2: $name2', address: formattedAddr2);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.map_outlined, size: 14, color: Color(0xFF374151)),
                              const SizedBox(width: 5),
                              Text(
                                'Preview Stop 2',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                        ),
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
