import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/config/app_config.dart';
import '../../../data/models/order.dart';
import '../../profile/add_review_screen.dart';

class TrackingReviewCard extends StatelessWidget {
  final Order? order;

  const TrackingReviewCard({super.key, required this.order});

  void _navigateToReview(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          productName: (order?.items != null && order!.items!.isNotEmpty)
              ? order!.items!.first.name
              : 'FastKirana Delivery',
          restaurantId: order?.restaurantId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riderName = order?.deliveryUser?.name ?? 'Delivery Partner';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'DELIVERED SAFELY',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9.5),
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
              const SizedBox(height: 10),
              Text(
                'How was your delivery with $riderName?',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14.5),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                'Rate your experience to help us reward top delivery partners.',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  color: const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => _navigateToReview(context),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 26,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToReview(context),
                  icon: const Icon(Icons.rate_review_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Write Detailed Review',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.headset_mic_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Need assistance with this order?',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:${AppConfig.supportPhone}')),
              child: Text(
                'Call FastKirana Support (${AppConfig.supportPhone})',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
