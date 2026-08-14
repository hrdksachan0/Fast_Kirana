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

  static const Color primaryGreen = Color(0xFF047857);
  static const Color primaryGreenDark = Color(0xFF065F46);
  static const Color primaryGreenLight = Color(0xFFD1FAE5);
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Profile Header with gradient
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF047857), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FastKirana User',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ghatampur Market, Kanpur',
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+91 98765 43210',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Order Tracker Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Orders',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: primaryGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildOrderTrackerCard(context),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Account & Services Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account & Services',
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
                  ),
                  const SizedBox(height: 14),
                  _buildAccountCard(context),
                ],
              ),
            ),
          ),

          // Help & Support Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help & Support',
                    style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
                  ),
                  const SizedBox(height: 14),
                  _buildHelpCard(context),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // Logout Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppDesignSystem.danger,
                    side: const BorderSide(color: AppDesignSystem.danger, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Logout', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildOrderTrackerCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Timeline-like order tracker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOrderStep(Icons.pending_outlined, 'Pending', '2', AppDesignSystem.statusPending, AppDesignSystem.statusPendingText),
                _buildOrderStep(Icons.confirmation_num_outlined, 'Confirmed', '1', AppDesignSystem.statusConfirmed, AppDesignSystem.statusConfirmedText),
                _buildOrderStep(Icons.inventory_2_outlined, 'Packed', '1', AppDesignSystem.statusPacked, AppDesignSystem.statusPackedText),
                _buildOrderStep(Icons.delivery_dining_outlined, 'Delivered', '12', AppDesignSystem.statusDelivered, AppDesignSystem.statusDeliveredText),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Quick stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Active Orders', '4', Icons.shopping_bag_rounded, primaryGreen),
                _buildQuickStat('Total Saved', '₹1,250', Icons.savings_rounded, const Color(0xFF10B981)),
                _buildQuickStat('Total Spent', '₹8,490', Icons.account_balance_wallet_rounded, AppDesignSystem.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStep(IconData icon, String label, String count, Color bgColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Center(child: Icon(icon, size: 24, color: textColor)),
              if (count != '0')
                Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: textDark)),
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: textMuted)),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Column(
        children: [
          _buildProfileTile(
            context,
            icon: Icons.favorite_border_rounded,
            iconColor: AppDesignSystem.danger,
            title: 'Wishlist & Favorites',
            subtitle: '12 items saved',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.repeat_rounded,
            iconColor: primaryGreen,
            title: 'Daily Subscriptions',
            subtitle: '3 active subscriptions',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.location_on_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: 'My Addresses',
            subtitle: '2 addresses',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.wallet_outlined,
            iconColor: const Color(0xFFF59E0B),
            title: 'Wallet & Cashbacks',
            subtitle: '₹250 available',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Notifications',
            subtitle: '3 new notifications',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Column(
        children: [
          _buildProfileTile(
            context,
            icon: Icons.headset_mic_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'Customer Support',
            subtitle: 'Chat or call us',
            onTap: () {},
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('24/7', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF06B6D4))),
            ),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.help_outline_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'FAQs',
            subtitle: 'Frequently asked questions',
            onTap: () {},
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.share_rounded,
            iconColor: primaryGreen,
            title: 'Share App',
            subtitle: 'Share with friends & family',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: textMuted)),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppDesignSystem.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Divider(height: 1, color: AppDesignSystem.divider),
    );
  }
}
