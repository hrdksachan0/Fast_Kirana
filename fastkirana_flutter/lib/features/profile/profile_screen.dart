import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes/page_transitions.dart';
import '../../core/theme/design_system.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../auth/login_screen.dart';
import '../orders/orders_screen.dart';
import 'address_book_screen.dart';
import 'notifications_screen.dart';
import 'widgets/profile_edit_modal.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_menu_item.dart';
import 'widgets/profile_operations_suite.dart';
import 'widgets/profile_quick_stats.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color primaryRed = AppDesignSystem.red600;

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppConfirmationDialog.showLogout(
      context: context,
      title: 'Log Out of FastKirana?',
      subtitle: 'You will need to verify your phone number or email to log back in.',
      accountNote: 'Your cart items, saved addresses, and active orders stay secure in the cloud.',
      confirmLabel: 'Log Out',
    );

    if (confirmed == true) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
      unawaited(ref.read(authProvider.notifier).clear());
    }
  }

  void _showSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'FastKirana 24x7 Customer Care',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We are here to assist with orders, deliveries & refunds in Ghatampur',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                color: AppDesignSystem.slate500,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('tel:+918112849854');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.blue50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_rounded, color: AppDesignSystem.blue600, size: 22),
              ),
              title: Text('Call Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('+91 81128 49854 (Instant Call)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
            ),
            const Divider(height: 1, color: AppDesignSystem.slate100),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('https://wa.me/918112849854?text=Hello%20FastKirana%20Support');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('💬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
              ),
              title: Text('WhatsApp Chat Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('Chat with Ghatampur Support team', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
            ),
            const Divider(height: 1, color: AppDesignSystem.slate100),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('mailto:fastkiranadelivery@gmail.com?subject=FastKirana%20Customer%20Support');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.rose50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.email_outlined, color: AppDesignSystem.red600, size: 22),
              ),
              title: Text('Email Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('fastkiranadelivery@gmail.com', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppDesignSystem.slate400),
            ),
          ],
        ),
      ),
    );
  }

  void _showRateAppDialog(BuildContext context) {
    int selectedStars = 5;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.amber50,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppDesignSystem.amber400.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.star_rounded, size: 36, color: AppDesignSystem.warning),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Love FastKirana?',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 18),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedStars >= 4
                      ? 'Your 5-star review motivates our 10-minute delivery fleet to serve you better!'
                      : 'We are sorry to disappoint. How can we make your experience better?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: AppDesignSystem.slate500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setDialogState(() => selectedStars = starIndex);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starIndex <= selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 36,
                          color: starIndex <= selectedStars ? AppDesignSystem.warning : AppDesignSystem.slate300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedStars >= 4 ? AppDesignSystem.emerald600 : AppDesignSystem.slate800,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      HapticFeedback.mediumImpact();
                      if (selectedStars >= 4) {
                        // Launch Google Play Store directly
                        final marketUri = Uri.parse('market://details?id=com.fastkirana.app');
                        final webUri = Uri.parse('https://play.google.com/store/apps/details?id=com.fastkirana.app');
                        try {
                          if (await canLaunchUrl(marketUri)) {
                            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
                          } else {
                            await launchUrl(webUri, mode: LaunchMode.externalApplication);
                          }
                        } catch (_) {
                          if (await canLaunchUrl(webUri)) {
                            await launchUrl(webUri, mode: LaunchMode.externalApplication);
                          }
                        }
                      } else {
                        // 1-3 stars: route to direct WhatsApp support to solve grievance
                        final waUri = Uri.parse(
                          'https://wa.me/918112849854?text=${Uri.encodeComponent('Hi FastKirana Support, I gave a $selectedStars-star rating. Here is my feedback: ')}',
                        );
                        if (await canLaunchUrl(waUri)) {
                          await launchUrl(waUri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Text(
                      selectedStars >= 4 ? 'Rate on Google Play ⭐' : 'Send Feedback on WhatsApp',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Maybe Later',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      color: AppDesignSystem.slate400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: Responsive.scaledFontSize(context, 10.5),
          fontWeight: FontWeight.w800,
          color: AppDesignSystem.slate400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final user = userAsync.valueOrNull;
    final userId = user?.id ?? '';
    final ordersAsync = ref.watch(ordersProvider(userId));
    final wishlist = ref.watch(wishlistProvider);
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];

    final ordersCount = ordersAsync.valueOrNull?.length ?? 0;
    final role = (user?.role ?? 'USER').toUpperCase();

    final isAdmin = role == 'ADMIN';
    final isRiderOnly = !isAdmin && (
      role == 'RIDER' ||
      role == 'DELIVERY' ||
      role == 'DELIVERY_PARTNER'
    );
    final isChefOrOwnerOnly = !isAdmin && (
      role == 'CHEF' ||
      role == 'RESTAURANT_OWNER' ||
      role == 'RESTAURANT'
    );
    final isPickerOnly = !isAdmin && (role == 'PICKER');
    final isVendorOnly = !isAdmin && (role == 'VENDOR');

    final name = (user?.name?.isNotEmpty == true && user?.name != 'FastKirana Customer')
        ? user!.name!
        : (isAdmin
            ? 'FastKirana Admin'
            : (isRiderOnly
                ? 'Delivery Partner'
                : (isChefOrOwnerOnly
                    ? 'Restaurant Chef'
                    : (isPickerOnly
                        ? 'Warehouse Picker'
                        : (isVendorOnly ? 'Supplier Partner' : 'FastKirana Customer')))));

    String phoneDisplay;
    if (user?.phone?.isNotEmpty == true) {
      final raw = user!.phone!.trim();
      phoneDisplay = raw.startsWith('+91') ? raw : '+91 $raw';
    } else {
      phoneDisplay = user?.email ?? 'Not logged in';
    }

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      body: SafeArea(
        bottom: false,
        child: ResponsiveContainer(
          maxWidth: Responsive.wideMaxContentWidth,
          fillHeight: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── 1. Luxury Glassmorphic Header ─────────────────────────────
              SliverToBoxAdapter(
                child: ProfileHeaderCard(
                  user: user,
                  name: name,
                  phoneDisplay: phoneDisplay,
                  onEditProfile: () {
                    if (user != null) {
                      ProfileEditModal.show(context, ref, user);
                    }
                  },
                ),
              ),

              // ─── 2. Operations Suite (Admin, Rider, Chef, Picker, Vendor) ──────────
              SliverToBoxAdapter(
                child: ProfileOperationsSuite(
                  isAdmin: isAdmin,
                  isRiderOnly: isRiderOnly,
                  isChefOrOwnerOnly: isChefOrOwnerOnly,
                  isPickerOnly: isPickerOnly,
                  isVendorOnly: isVendorOnly,
                  assignedRestaurantId: user?.assignedRestaurantId,
                ),
              ),

              // ─── 3. Quick Stats Grid ────────────────────────────────────────
              SliverToBoxAdapter(
                child: ProfileQuickStats(
                  ordersCount: ordersCount,
                  wishlistCount: wishlist.length,
                  addressesCount: addresses.length,
                  isLoggedIn: user != null,
                  onOrdersTap: () {
                    if (user == null) {
                      Navigator.push(context, FadeSlideRoute(page: const LoginScreen()));
                    } else {
                      Navigator.push(context, FadeSlideRoute(page: const OrdersScreen()));
                    }
                  },
                  onWishlistTap: () => Navigator.push(context, FadeSlideRoute(page: const WishlistScreen())),
                  onAddressesTap: () => Navigator.push(context, FadeSlideRoute(page: const AddressBookScreen())),
                ),
              ),

              // ─── 4. Structured Clean Settings Groups ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Account & Preferences
                      _buildSectionHeader(context, 'ACCOUNT & ADDRESSES'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ProfileMenuItem(
                              icon: Icons.location_on_rounded,
                              iconBg: AppDesignSystem.green50,
                              iconColor: AppDesignSystem.emerald600,
                              title: 'Saved Addresses',
                              subtitle: addresses.isNotEmpty ? '${addresses.length} locations saved in Ghatampur' : 'Add home, office or shop location',
                              badge: addresses.isNotEmpty ? '${addresses.length}' : null,
                              onTap: () => Navigator.push(context, FadeSlideRoute(page: const AddressBookScreen())),
                            ),
                            const Divider(height: 1, color: AppDesignSystem.slate100),
                            ProfileMenuItem(
                              icon: Icons.notifications_active_rounded,
                              iconBg: AppDesignSystem.indigo50,
                              iconColor: AppDesignSystem.indigo700,
                              title: 'Notifications & Alerts',
                              subtitle: 'Order tracking, offers & dispatch updates',
                              onTap: () {
                                if (user == null) {
                                  Navigator.push(context, FadeSlideRoute(page: const LoginScreen()));
                                } else {
                                  Navigator.push(context, FadeSlideRoute(page: const NotificationsScreen()));
                                }
                              },
                            ),
                            if (user != null) ...[
                              const Divider(height: 1, color: AppDesignSystem.slate100),
                              ProfileMenuItem(
                                icon: Icons.edit_note_rounded,
                                iconBg: AppDesignSystem.slate50,
                                iconColor: AppDesignSystem.slate600,
                                title: 'Personal Information',
                                subtitle: 'Edit your name, phone & email',
                                onTap: () => ProfileEditModal.show(context, ref, user),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Help & Support
                      _buildSectionHeader(context, 'SUPPORT & FASTKIRANA'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ProfileMenuItem(
                              icon: Icons.headset_mic_rounded,
                              iconBg: AppDesignSystem.violet50,
                              iconColor: AppDesignSystem.fuchsia700,
                              title: '24x7 Customer Support',
                              subtitle: 'Direct WhatsApp & phone assistance',
                              onTap: () => _showSupportModal(context),
                            ),
                            const Divider(height: 1, color: AppDesignSystem.slate100),
                            ProfileMenuItem(
                              icon: Icons.star_rounded,
                              iconBg: AppDesignSystem.amber50,
                              iconColor: AppDesignSystem.amber600,
                              title: 'Rate FastKirana App',
                              subtitle: 'Love 10-min delivery? Rate us on Play Store',
                              badge: '5.0 ★',
                              onTap: () => _showRateAppDialog(context),
                            ),
                            const Divider(height: 1, color: AppDesignSystem.slate100),
                            ProfileMenuItem(
                              icon: Icons.share_rounded,
                              iconBg: AppDesignSystem.blue50,
                              iconColor: AppDesignSystem.blue600,
                              title: 'Share with Friends & Family',
                              subtitle: 'Invite neighbours to 10-min delivery',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Share.share(
                                  '⚡ FastKirana Express: Order Groceries & Food in 10-15 mins!\n\nDownload app: https://www.fastkirana.in',
                                  subject: 'FastKirana Express',
                                );
                              },
                            ),
                            if (user != null) ...[
                              const Divider(height: 1, color: AppDesignSystem.slate100),
                              ProfileMenuItem(
                                icon: Icons.logout_rounded,
                                iconBg: AppDesignSystem.statusCancelled,
                                iconColor: primaryRed,
                                title: 'Log Out',
                                subtitle: 'Sign out from this phone',
                                onTap: () => _showLogoutDialog(context, ref),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Version & Ghatampur Stamp
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppDesignSystem.success, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(
                                  'FastKirana Express v1.0.0',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Proudly Serving Ghatampur, Kanpur Nagar ❤️',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                fontWeight: FontWeight.w600,
                                color: AppDesignSystem.slate300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}