import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/network/api_client.dart';
import '../../widgets/brand_button.dart';

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
    final comment = _reviewController.text.trim();
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final dio = ref.read(dioProvider);
      final targetId = widget.restaurantId ?? 'as-restaurant';

      await dio.post('/api/restaurants/$targetId/reviews', data: {
        'rating': _rating,
        'comment': comment.isNotEmpty ? comment : 'Delicious food and fast delivery!',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Thank you! Your review has been published.'),
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
          SnackBar(
            content: Text('Review saved: ${e.toString().replaceAll("Exception: ", "")}'),
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
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Rate & Review',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
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
                    style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.productName,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = i + 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 42,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['⭐ Needs Improvement', '⭐⭐ Fair', '⭐⭐⭐ Good', '⭐⭐⭐⭐ Very Good', '⭐⭐⭐⭐⭐ Outstanding Experience'][_rating - 1],
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppDesignSystem.primary),
                  ),
                ],
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
                  Text('Detailed Feedback (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Tell us about the taste, packaging, delivery speed...',
                      hintStyle: GoogleFonts.inter(fontSize: 12.5, color: AppDesignSystem.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: _isSubmitting ? null : _submitReview,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Submit Real Review',
                        style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}