import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class AdminCouponsDetailScreen extends StatefulWidget {
  final String couponId;
  const AdminCouponsDetailScreen({super.key, required this.couponId});

  @override
  State<AdminCouponsDetailScreen> createState() => _AdminCouponsDetailScreenState();
}

class _AdminCouponsDetailScreenState extends State<AdminCouponsDetailScreen> {
  bool _isActive = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Coupon Details', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                children: [
                  Text(widget.couponId, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('FLAT ₹50 OFF', style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 20), fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Min order: ₹199', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _infoRow('Status', _isActive ? 'Active' : 'Inactive'),
            _infoRow('Used Count', '1,200 times'),
            _infoRow('Valid From', 'Aug 1, 2026'),
            _infoRow('Valid Until', 'Aug 31, 2026'),
            _infoRow('Created At', 'Jul 28, 2026'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Active', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeColor: AppDesignSystem.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: BrandButton(
                    text: 'Delete Coupon',
                    backgroundColor: AppDesignSystem.danger,
                    textColor: Colors.white,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
        ],
      ),
    );
  }
}