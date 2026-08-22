import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/design_system.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../auth/admin_login.dart';
import '../admin/admin_dashboard.dart';
import '../orders/orders_screen.dart';
import 'address_book_screen.dart';
import 'wallet_screen.dart';
import 'wishlist_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color primaryRed = Color(0xFFE20A22);

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out of FastKirana?',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
        ),
        content: Text(
          'You will need to enter your phone or email to log back in.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).clear();
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
            child: Text('Log Out', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Profile Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryRed, Color(0xFFB30013)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: userAsync.when(
                    data: (user) {
                      if (user == null) {
                        // GUEST STATE
                        return Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                              ),
                              child: const Icon(Icons.person_outline_rounded, size: 30, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome to FastKirana 👋',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Log in for 10-min fast delivery',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Bounceable(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppDesignSystem.shadowSm,
                                ),
                                child: Text(
                                  'LOGIN',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: primaryRed,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      // LOGGED IN USER STATE
                      final name = (user.name != null && user.name!.isNotEmpty) ? user.name! : 'Customer';
                      final phone = user.phone != null && user.phone!.isNotEmpty
                          ? '+91 ${user.phone}'
                          : user.email;
                      final isAdmin = user.role == 'ADMIN';

                      return Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                            ),
                            child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? const Color(0xFFFEF08A) : const Color(0xFFFDE047),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isAdmin ? 'ADMIN' : 'VIP',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF854D0E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  phone,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(height: 60),
                    error: (_, __) => const SizedBox(height: 60),
                  ),
                ),
              ),
            ),
          ),

          // 2. FastKirana Wallet Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: primaryRed, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FastKirana Wallet & Savings',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Available Balance & Cashback',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹120',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Quick Action Menu & Controls
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: 'My Orders',
                      subtitle: 'Track live orders & order history',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      title: 'Saved Addresses',
                      subtitle: 'Home, office & landmark addresses',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    _buildMenuItem(
                      context,
                      icon: Icons.favorite_rounded,
                      iconBg: const Color(0xFFFFF1F2),
                      iconColor: primaryRed,
                      title: 'My Wishlist',
                      subtitle: 'Saved items to buy later',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WishlistScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    _buildMenuItem(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'Darkstore & Admin Hub',
                      subtitle: 'Inventory, 428 products, pipeline & stats',
                      onTap: () {
                        final currentUser = userAsync.valueOrNull;
                        if (currentUser?.role == 'ADMIN') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminDashboard()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    _buildMenuItem(
                      context,
                      icon: Icons.headset_mic_rounded,
                      iconBg: const Color(0xFFFAF5FF),
                      iconColor: const Color(0xFF7E22CE),
                      title: 'Help & 24x7 Support',
                      subtitle: '+91 70544 70303 · Ghatampur Care',
                      onTap: () {},
                    ),

                    // LOGOUT BUTTON (Only if user logged in)
                    if (userAsync.valueOrNull != null) ...[
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      _buildMenuItem(
                        context,
                        icon: Icons.logout_rounded,
                        iconBg: const Color(0xFFFEF2F2),
                        iconColor: primaryRed,
                        title: 'Log Out / Switch Account',
                        subtitle: 'Sign out from this device',
                        onTap: () => _showLogoutDialog(context, ref),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}