import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class AddReviewScreen extends StatefulWidget {
  final String productName;
  const AddReviewScreen({super.key, required this.productName});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  int _rating = 5;
  final _reviewController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Write Review', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  Text('Rate', style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () => setState(() => _rating = i + 1),
                      child: Icon(
                        i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: AppDesignSystem.warning,
                      ),
                    )),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['Very Bad', 'Bad', 'Average', 'Good', 'Excellent'][_rating - 1],
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Review', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reviewController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Share your experience with ${widget.productName}...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BrandButton(
              text: 'Submit Review',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Review submitted!'), backgroundColor: AppDesignSystem.success, behavior: SnackBarBehavior.floating),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}