import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import 'address_book_screen.dart';
import 'wallet_screen.dart';
import 'wishlist_screen.dart';
import 'subscriptions_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          'My Account',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppDesignSystem.primaryGradient,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FastKirana User',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+91 9876543210',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Order Tracker Grid
            Text(
              'Orders',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                padding: const EdgeInsets.symmetric(vertical: 16),
                childAspectRatio: 0.85,
                children: [
                  _buildOrderIcon(Icons.pending_outlined, 'Pending', '2'),
                  _buildOrderIcon(Icons.confirmation_num_outlined, 'Confirmed', '1'),
                  _buildOrderIcon(Icons.inventory_2_outlined, 'Packed', '1'),
                  _buildOrderIcon(Icons.delivery_dining_outlined, 'Delivered', '12'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account Actions
            Text(
              'Account & Services',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.favorite_outline_rounded,
                    title: 'Wishlist & Favorites',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WishlistScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    context,
                    icon: Icons.repeat_rounded,
                    title: 'Daily Subscriptions',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    context,
                    icon: Icons.location_on_outlined,
                    title: 'My Addresses',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    context,
                    icon: Icons.wallet_outlined,
                    title: 'Wallet & Cashbacks',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _buildListTile(
                    context,
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, String count) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 28, color: AppDesignSystem.primary),
            if (count != '0')
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppDesignSystem.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppDesignSystem.textMuted),
          ],
        ),
      ),
    );
  }
}