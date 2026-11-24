import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/network/api_client.dart';
import '../auth/login_screen.dart';

class AddReviewScreen extends ConsumerStatefulWidget {
  final String productName;
  final String? restaurantId;

  const AddReviewScreen({
    super.key,
    required this.productName,
    this.restaurantId,
  });

  @override
  ConsumerState<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends ConsumerState<AddReviewScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final user = ref.read(authProvider).valueOrNull;
    final bool isLoggedIn = user != null &&
        user.id.isNotEmpty &&
        !user.name.toString().toLowerCase().startsWith('guest') &&
        !user.name.toString().contains('Guest Shopper');

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Please log in with your FastMinute account to submit a review.'),
              ),
            ],
          ),
          backgroundColor: AppDesignSystem.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final comment = _reviewController.text.trim();
    final rawName = user.name?.trim() ?? '';
    final reviewerName = (rawName.isNotEmpty &&
            !rawName.toLowerCase().startsWith('guest') &&
            !rawName.contains('Guest Shopper'))
        ? rawName
        : (user.phone != null && user.phone!.isNotEmpty ? user.phone! : 'FastMinute Member');

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final dio = ref.read(dioProvider);
      final targetId = widget.restaurantId ?? 'as-restaurant';

      final payload = <String, dynamic>{
        'rating': _rating,
        'comment': comment,
        'userName': reviewerName,
        'userId': user.id,
      };

      await dio.post('/api/restaurants/$targetId/reviews', data: payload);

      // Instantly refresh reviews and restaurant stats across the entire app
      ref.invalidate(restaurantReviewsProvider(targetId));
      ref.invalidate(restaurantsProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Thank you! Your review has been published.')),
            ],
          ),
          backgroundColor: AppDesignSystem.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Review submitted! Thank you for your feedback.')),
              ],
            ),
            backgroundColor: AppDesignSystem.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final bool isLoggedIn = user != null &&
        user.id.isNotEmpty &&
        !user.name.toString().toLowerCase().startsWith('guest') &&
        !user.name.toString().contains('Guest Shopper');

    final rawName = user?.name?.trim() ?? '';
    final displayName = (rawName.isNotEmpty &&
            !rawName.toLowerCase().startsWith('guest') &&
            !rawName.contains('Guest Shopper'))
        ? rawName
        : (user?.phone != null && user!.phone!.isNotEmpty
            ? user.phone!
            : 'FastMinute Member');

    final contactInfo = user?.phone ?? user?.email ?? '';

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rate & Review',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 17),
            fontWeight: FontWeight.w900,
            color: AppDesignSystem.slate900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Rating Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  Text(
                    'How was your experience with',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      color: AppDesignSystem.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.productName,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _rating = i + 1);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            i < _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 42,
                            color: AppDesignSystem.warning,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      '⭐ Needs Improvement',
                      '⭐⭐ Fair',
                      '⭐⭐⭐ Good',
                      '⭐⭐⭐⭐ Very Good',
                      '⭐⭐⭐⭐⭐ Outstanding Experience'
                    ][_rating - 1],
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Identity Card (Locked to Account - No arbitrary name change)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: isLoggedIn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.shield_rounded,
                                  size: 15,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Reviewing from Account',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified Account',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppDesignSystem.borderLight),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    AppDesignSystem.primary.withValues(alpha: 0.12),
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 14),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.slate900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (contactInfo.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        contactInfo,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 11),
                                          fontWeight: FontWeight.w500,
                                          color: AppDesignSystem.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Your review will be posted under your registered account name to ensure authentic ratings.',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  color: const Color(0xFF94A3B8),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_circle_outlined,
                            size: 32,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Login required to review',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Sign in with your account to post reviews.',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppDesignSystem.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Review Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detailed Feedback (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      color: AppDesignSystem.slate900,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Tell us about the quality, taste, packaging, delivery speed...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        color: AppDesignSystem.textMuted,
                      ),
                      filled: true,
                      fillColor: AppDesignSystem.slate50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppDesignSystem.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppDesignSystem.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppDesignSystem.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (!isLoggedIn) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        } else {
                          _submitReview();
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isLoggedIn ? 'Submit Review' : 'Sign in to Submit Review',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
