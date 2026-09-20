import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fastkirana_flutter/core/routes/page_transitions.dart';
import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:fastkirana_flutter/features/profile/add_review_screen.dart';

/// Reviews and ratings list tab for Cafe / Restaurant Menu screen
class CafeReviewsTab extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> reviewsAsync;
  final String restaurantName;
  final String restaurantId;

  const CafeReviewsTab({
    super.key,
    required this.reviewsAsync,
    required this.restaurantName,
    required this.restaurantId,
  });

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      LoggerService.error('CafeReviewsTab: date parse catch', e);
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = AppDesignSystem.primary;

    return reviewsAsync.when(
      data: (data) {
        final reviews = data['reviews'] as List? ?? [];
        final totalCount = data['totalCount'] ?? reviews.length;
        final avgRating = data['averageRating'] ?? 4.5;

        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('⭐', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48))),
                const SizedBox(height: 12),
                Text(
                  'No reviews yet',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to review!',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: AppDesignSystem.slate400,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: AddReviewScreen(
                          productName: restaurantName,
                          restaurantId: restaurantId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Write a Review',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: reviews.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignSystem.slate100),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$avgRating',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 32),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: i < (avgRating is num ? avgRating.round() : 4)
                                ? AppDesignSystem.warning
                                : AppDesignSystem.border,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalCount reviews',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(
                            page: AddReviewScreen(
                              productName: restaurantName,
                              restaurantId: restaurantId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Write Review',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final review = reviews[index - 1];
            final user = review['user'] as Map<String, dynamic>?;
            final rating = review['rating'] ?? 5;
            final comment = review['comment'] ?? '';
            final createdAt = review['createdAt'] ?? '';
            final userName = user?['name'] ?? 'Customer';

            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.slate100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppDesignSystem.slate100,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.slate900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: List.generate(5, (i) => Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: i < rating ? AppDesignSystem.warning : AppDesignSystem.border,
                              )),
                            ),
                          ],
                        ),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          _formatDate(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            color: AppDesignSystem.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.orange600)),
      error: (_, __) => const Center(child: Text('Failed to load reviews')),
    );
  }
}
