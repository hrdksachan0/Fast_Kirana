import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/user.dart';
import '../../widgets/brand_card.dart';
import '../../widgets/brand_button.dart';
import '../orders/orders_screen.dart';
import 'addresses_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text('My Profile', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildMenuItems(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppDesignSystem.shadowLg,
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_rounded, size: 40, color: AppDesignSystem.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sooraj Singh',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'sooraj@example.com',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context) {
    final menuItems = [
      {'icon': Icons.receipt_long_rounded, 'label': 'My Orders', 'screen': OrdersScreen()},
      {'icon': Icons.location_on_rounded, 'label': 'Saved Addresses', 'screen': const AddressesScreen()},
      {'icon': Icons.favorite_border_rounded, 'label': 'Favorites', 'screen': null},
      {'icon': Icons.local_offer_rounded, 'label': 'Offers & Coupons', 'screen': null},
      {'icon': Icons.notifications_outlined, 'label': 'Notifications', 'screen': null},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'screen': null},
      {'icon': Icons.help_outline_rounded, 'label': 'Help & Support', 'screen': null},
      {'icon': Icons.info_outline_rounded, 'label': 'About', 'screen': null},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppDesignSystem.borderLight),
      ),
      child: Column(
        children: List.generate(menuItems.length, (index) {
          final item = menuItems[index];
          final isLast = index == menuItems.length - 1;
          return InkWell(
            onTap: () {
              if (item['screen'] != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => item['screen'] as Widget),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: AppDesignSystem.borderLight)),
              ),
              child: Row(
                children: [
                  Icon(item['icon'] as IconData, size: 22, color: AppDesignSystem.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item['label'] as String,
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppDesignSystem.textTertiary),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}