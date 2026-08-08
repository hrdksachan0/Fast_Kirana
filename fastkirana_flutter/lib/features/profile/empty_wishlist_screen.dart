import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class EmptyWishlistScreen extends StatelessWidget {
  const EmptyWishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Wishlist', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: AppDesignSystem.borderLight),
                  boxShadow: AppDesignSystem.shadowSm,
                ),
                child: Icon(Icons.favorite_border_rounded, size: 56, color: AppDesignSystem.textMuted),
              ),
              const SizedBox(height: 24),
              Text('No favorites yet', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
              const SizedBox(height: 8),
              Text('Tap the heart icon on products\nyou love to save them here.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary, height: 1.5)),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppDesignSystem.shadowCard,
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Explore Products', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}