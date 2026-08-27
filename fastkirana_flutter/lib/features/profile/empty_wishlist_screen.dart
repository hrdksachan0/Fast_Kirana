import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/empty_state.dart';

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
      body: EmptyState(
        emoji: '💝',
        title: 'No favorites yet',
        subtitle: 'Tap the heart icon on products\nyou love to save them here.',
        ctaLabel: 'Explore Products',
        bgTint: const Color(0xFFFFF0F0),
        onCta: () => Navigator.pop(context),
      ),
    );
  }
}