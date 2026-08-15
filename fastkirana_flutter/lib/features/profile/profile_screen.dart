import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/auth_provider.dart';
import 'address_book_screen.dart';
import 'wallet_screen.dart';
import 'wishlist_screen.dart';
import 'subscriptions_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);

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
                  colors: [Color(0xFFE20A22), Color(0xFFFF4D62)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: userAsync.when(
                    data: (user) {
                      final name = user?.name ?? 'FastKirana User';
                      final phoneStr = user?.phone;
                      final phone = phoneStr != null && phoneStr.isNotEmpty ? '+91 $phoneStr' : 'Not set';
                      final email = user?.email ?? '';

                      return Row(
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
                                  name,
                                  style: GoogleFonts.inter(
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
                                    Expanded(
                                      child: Text(
                                        email.isNotEmpty ? email : 'FastKirana User',
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
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
                      );
                    },
                    loading: () => Row(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Center(
                            child: SizedBox(width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 20, width: 140, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6))),
                              const SizedBox(height: 8),
                              Container(height: 14, width: 100, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    error: (_, __) => Row(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(36),
                          ),
                          child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guest',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to sign in',
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                        style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.primary),
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
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
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
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: textDark),
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
                _buildOrderStep(Icons.pending_outlined, 'Pending', '0', AppDesignSystem.statusPending, AppDesignSystem.statusPendingText),
                _buildOrderStep(Icons.confirmation_num_outlined, 'Confirmed', '0', AppDesignSystem.statusConfirmed, AppDesignSystem.statusConfirmedText),
                _buildOrderStep(Icons.inventory_2_outlined, 'Packed', '0', AppDesignSystem.statusPacked, AppDesignSystem.statusPackedText),
                _buildOrderStep(Icons.delivery_dining_outlined, 'Delivered', '0', AppDesignSystem.statusDelivered, AppDesignSystem.statusDeliveredText),
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
            // Quick stats - placeholder until we have real data from orders API
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('Active Orders', '0', Icons.shopping_bag_rounded, AppDesignSystem.primary),
                _buildQuickStat('Total Saved', '₹0', Icons.savings_rounded, const Color(0xFF22C55E)),
                _buildQuickStat('Total Spent', '₹0', Icons.account_balance_wallet_rounded, AppDesignSystem.textSecondary),
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
                    color: AppDesignSystem.primary,
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
            subtitle: null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.repeat_rounded,
            iconColor: AppDesignSystem.primary,
            title: 'Daily Subscriptions',
            subtitle: null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.location_on_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: 'My Addresses',
            subtitle: null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.wallet_outlined,
            iconColor: const Color(0xFFF59E0B),
            title: 'Wallet & Cashbacks',
            subtitle: null,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Notifications',
            subtitle: null,
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
            subtitle: null,
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
            subtitle: null,
            onTap: () {},
          ),
          _buildDivider(),
          _buildProfileTile(
            context,
            icon: Icons.share_rounded,
            iconColor: AppDesignSystem.primary,
            title: 'Share App',
            subtitle: null,
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
    String? subtitle,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: textMuted)),
                  ],
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