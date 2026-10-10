import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Fast Switch Banner for Auto-Approve / Manual Order Approval
class AdminAutoApproveBanner extends StatelessWidget {
  final bool isAutoApprove;
  final ValueChanged<bool> onToggleAutoApprove;

  const AdminAutoApproveBanner({
    super.key,
    required this.isAutoApprove,
    required this.onToggleAutoApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isAutoApprove ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAutoApprove ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isAutoApprove ? Icons.bolt_rounded : Icons.admin_panel_settings_rounded,
              size: 20,
              color: isAutoApprove ? AppDesignSystem.green600 : const Color(0xFFEA580C),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAutoApprove ? 'AUTO-APPROVE: ON' : 'MANUAL APPROVAL: ON',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w900,
                          color: isAutoApprove ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isAutoApprove ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAutoApprove ? 'Direct to Kitchen' : 'Admin Call Gate',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9),
                            fontWeight: FontWeight.w800,
                            color: isAutoApprove ? const Color(0xFF166534) : const Color(0xFF9A3412),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isAutoApprove
                        ? 'Incoming orders reach restaurant console immediately'
                        : 'Orders pause for call verification before restaurant sees them',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w500,
                      color: isAutoApprove ? const Color(0xFF166534) : const Color(0xFF9A3412),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 28,
              child: FittedBox(
                child: Switch(
                  value: isAutoApprove,
                  activeThumbColor: AppDesignSystem.green600,
                  activeTrackColor: const Color(0xFFBBF7D0),
                  inactiveThumbColor: const Color(0xFFEA580C),
                  inactiveTrackColor: const Color(0xFFFED7AA),
                  onChanged: onToggleAutoApprove,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
