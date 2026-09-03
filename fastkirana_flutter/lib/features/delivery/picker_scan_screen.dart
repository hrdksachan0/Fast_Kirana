import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class PickerScanScreen extends StatelessWidget {
  const PickerScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Scan Barcode', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppDesignSystem.borderLight, width: 2),
                ),
                child: Stack(
                  children: [
                    Center(child: Icon(Icons.qr_code_2_rounded, size: 120, color: AppDesignSystem.textMuted)),
                    Positioned(top: 0, left: 0, child: _corner(true, true)),
                    Positioned(top: 0, right: 0, child: _corner(true, false)),
                    Positioned(bottom: 0, left: 0, child: _corner(false, true)),
                    Positioned(bottom: 0, right: 0, child: _corner(false, false)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Position barcode within frame', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textSecondary)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppDesignSystem.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppDesignSystem.success)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppDesignSystem.success),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Last scanned: Amul Milk 1L', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), color: AppDesignSystem.textPrimary))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corner(bool top, bool left) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: AppDesignSystem.success, width: 4) : BorderSide.none,
          left: left ? BorderSide(color: AppDesignSystem.success, width: 4) : BorderSide.none,
          right: !left ? BorderSide(color: AppDesignSystem.success, width: 4) : BorderSide.none,
          bottom: !top ? BorderSide(color: AppDesignSystem.success, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}