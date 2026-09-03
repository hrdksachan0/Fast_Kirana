import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/empty_state.dart';

class EmptyCartScreen extends StatelessWidget {
  const EmptyCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('My Cart', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: EmptyState(
        emoji: '🛒',
        title: 'Your cart is empty',
        subtitle: 'Looks like you haven\'t added anything yet.\nStart shopping now!',
        ctaLabel: 'Start Shopping',
        bgTint: const Color(0xFFFFF5F6),
        onCta: () => Navigator.pop(context),
      ),
    );
  }
}