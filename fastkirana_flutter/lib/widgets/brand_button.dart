import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/brand_design_system.dart';

class BrandButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;

  const BrandButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isOutlined ? Colors.transparent : BrandColors.primary);
    final txtColor = textColor ??
        (isOutlined ? BrandColors.primary : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: txtColor,
          elevation: isOutlined ? 0 : 4,
          shadowColor: isOutlined
              ? Colors.transparent
              : BrandColors.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandSpacing.buttonRadius),
            side: isOutlined
                ? const BorderSide(color: BrandColors.primary, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}