import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/responsive.dart';

class RiderCard extends StatelessWidget {
  final String riderName;
  final String? riderPhone;
  final String? riderRating;
  final String? vehicleNumber;
  final String? deliveryOtp;

  const RiderCard({
    super.key,
    required this.riderName,
    this.riderPhone,
    this.riderRating,
    this.vehicleNumber,
    this.deliveryOtp,
  });

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppDesignSystem.slate100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.blue600.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining_rounded, size: 14, color: AppDesignSystem.blue600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DELIVERY PARTNER ASSIGNED',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.green100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 11, color: AppDesignSystem.green600),
                      const SizedBox(width: 3),
                      Text(
                        'Verified',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.green700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppDesignSystem.blue600, AppDesignSystem.blue700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.blue600.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22))),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),

                // Rider details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              riderName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                fontWeight: FontWeight.w900,
                                color: AppDesignSystem.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: AppDesignSystem.blue600),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.statusPending,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: AppDesignSystem.amber600),
                                const SizedBox(width: 1.5),
                                Text(
                                  riderRating ?? '4.9',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.statusPendingText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (vehicleNumber != null && vehicleNumber!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              vehicleNumber!,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Call Action Button
                if (riderPhone != null && riderPhone!.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _makeCall(riderPhone!);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.green600.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              'Call',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Delivery OTP Banner (if present)
          if (deliveryOtp != null && deliveryOtp!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.amber50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppDesignSystem.yellow200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 16, color: AppDesignSystem.amber600),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery OTP: ',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.statusPendingText,
                    ),
                  ),
                  Text(
                    deliveryOtp!,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: AppDesignSystem.amber700,
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
