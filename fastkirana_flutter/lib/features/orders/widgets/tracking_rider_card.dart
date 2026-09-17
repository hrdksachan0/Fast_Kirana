import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingRiderCard extends StatelessWidget {
  final Order? order;

  const TrackingRiderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final riderName = order?.deliveryUser?.name?.isNotEmpty == true ? order!.deliveryUser!.name! : 'Aryan';
    final riderPhone = order?.deliveryUser?.phone?.isNotEmpty == true ? order!.deliveryUser!.phone! : '+919696503759';
    final cleanPhone = riderPhone.replaceAll(RegExp(r'[^0-9]'), '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.two_wheeler_rounded, size: 14, color: Color(0xFF475569)),
                const SizedBox(width: 6),
                Text(
                  'DELIVERY PARTNER ASSIGNED',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'On Duty',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.white, size: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              riderName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 15),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                                const SizedBox(width: 2),
                                Text(
                                  '4.9',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '1,200+ deliveries • FastKirana Hero',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final wpUrl = 'https://wa.me/$cleanPhone?text=Hi%20$riderName,%20checking%20on%20my%20order';
                        launchUrl(Uri.parse(wpUrl), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, size: 17, color: Color(0xFF16A34A)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFDCFCE7),
                        padding: const EdgeInsets.all(9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 7),
                    ElevatedButton.icon(
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        launchUrl(Uri.parse('tel:$riderPhone'));
                      },
                      icon: const Icon(Icons.phone_rounded, size: 13, color: Colors.white),
                      label: Text(
                        'Call',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
