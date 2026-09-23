import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor != null ? badgeColor!.withValues(alpha: 0.12) : AppDesignSystem.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w800,
                    color: badgeColor ?? AppDesignSystem.slate600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11),
            fontWeight: FontWeight.w500,
            color: AppDesignSystem.slate500,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
      ),
    );
  }
}
