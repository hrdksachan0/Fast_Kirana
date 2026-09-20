import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/admin_notification_service.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../data/models/order.dart';

/// Modal bottom sheet for sharing KOT & order receipts via WhatsApp or system share sheet
class AdminShareSheet {
  static void show(BuildContext context, Order order) {
    HapticFeedback.lightImpact();
    final whatsappMessage = AdminNotificationService.formatRestaurantKOTMessage(order);
    final cleanCustomerPhone = (order.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');
    final cleanRiderPhone = (order.deliveryBoyPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '').replaceAll(RegExp(r'^91'), '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.green100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share_rounded, color: AppDesignSystem.green700, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Order #${order.readableId ?? order.id}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14.5),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        Text(
                          'Send order details / KOT to anyone',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: WhatsApp (Pick ANY Contact / Group)
              _buildShareOptionTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'Share on WhatsApp',
                subtitle: 'Choose any cook, rider, group, or contact',
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(whatsappMessage)}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    await Share.share(whatsappMessage, subject: 'FastKirana Order #${order.readableId ?? order.id}');
                  }
                },
              ),
              const SizedBox(height: 10),

              // Option 2: General Share Sheet (Any App)
              _buildShareOptionTile(
                icon: Icons.share_outlined,
                iconColor: AppDesignSystem.blue600,
                title: 'Share via Any App',
                subtitle: 'Telegram, SMS, Email, or Other Apps',
                onTap: () async {
                  Navigator.pop(ctx);
                  await Share.share(whatsappMessage, subject: 'FastKirana Order #${order.readableId ?? order.id}');
                },
              ),

              if (cleanCustomerPhone.length >= 10) ...[
                const SizedBox(height: 10),
                // Option 3: Direct to Customer
                _buildShareOptionTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppDesignSystem.orange600,
                  title: 'Send to Customer ($cleanCustomerPhone)',
                  subtitle: 'Send order receipt directly to customer on WhatsApp',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse('https://wa.me/91$cleanCustomerPhone?text=${Uri.encodeComponent(whatsappMessage)}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],

              if (cleanRiderPhone.length >= 10) ...[
                const SizedBox(height: 10),
                // Option 4: Direct to Rider
                _buildShareOptionTile(
                  icon: Icons.delivery_dining_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  title: 'Send to Rider ($cleanRiderPhone)',
                  subtitle: 'Send pickup & delivery details to rider on WhatsApp',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse('https://wa.me/91$cleanRiderPhone?text=${Uri.encodeComponent(whatsappMessage)}');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _buildShareOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppDesignSystem.slate50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignSystem.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
          ],
        ),
      ),
    );
  }
}
