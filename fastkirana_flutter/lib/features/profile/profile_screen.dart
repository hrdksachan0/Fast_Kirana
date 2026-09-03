import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/product_provider.dart';
import '../auth/login_screen.dart';
import '../auth/admin_login.dart';
import '../auth/delivery_login.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/picker_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../cafe/restaurant_dashboard.dart';
import '../../core/utils/restaurant_utils.dart';
import 'package:share_plus/share_plus.dart';
import '../orders/orders_screen.dart';
import 'address_book_screen.dart';
import 'wishlist_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const Color primaryRed = Color(0xFFDC2626);

  void _showEditProfileModal(BuildContext context, WidgetRef ref, User user) {
    final nameCtrl = TextEditingController(text: user.name ?? '');
    String cleanPhone = user.phone ?? '';
    if (cleanPhone.startsWith('+91')) {
      cleanPhone = cleanPhone.substring(3).trim();
    }
    final phoneCtrl = TextEditingController(text: cleanPhone);
    final emailCtrl = TextEditingController(text: user.email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Profile Details',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update your name, phone and email address',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Full Name',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Phone Number',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text('+91 ', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '10-digit mobile number',
                          hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Email Address',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    final newPhone = phoneCtrl.text.trim();
                    final newEmail = emailCtrl.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid name')),
                      );
                      return;
                    }

                    HapticFeedback.heavyImpact();
                    final authRepo = AuthRepository(ref.read(dioProvider));

                    // 1. Phone number changed -> Require Phone OTP Verification
                    if (newPhone.isNotEmpty && newPhone != user.phone) {
                      try {
                        await authRepo.sendPhoneOtp(newPhone);
                        final verified = await _promptOtpVerification(
                          context: context,
                          title: 'Verify New Phone Number',
                          subtitle: 'Enter the 6-digit OTP code sent to +91 $newPhone via SMS / WhatsApp.',
                          onVerify: (otp) => authRepo.updatePhoneWithOtp(newPhone, otp),
                        );
                        if (!verified) return;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to send phone OTP: $e')),
                          );
                        }
                        return;
                      }
                    }

                    // 2. Email changed -> Require Email OTP Verification
                    if (newEmail.isNotEmpty && newEmail.toLowerCase() != (user.email.toLowerCase())) {
                      try {
                        await authRepo.sendEmailOtp(newEmail);
                        final verified = await _promptOtpVerification(
                          context: context,
                          title: 'Verify New Email Address',
                          subtitle: 'Enter the 6-digit verification code sent to $newEmail.',
                          onVerify: (otp) => authRepo.updateEmailWithOtp(newEmail, otp),
                        );
                        if (!verified) return;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to send email OTP: $e')),
                          );
                        }
                        return;
                      }
                    }

                    // 3. Name changed
                    if (newName.isNotEmpty && newName != user.name) {
                      try {
                        await authRepo.updateName(newName);
                      } catch (_) {}
                    }

                    final updatedUser = User(
                      id: user.id,
                      name: newName,
                      email: newEmail.isNotEmpty ? newEmail : user.email,
                      phone: newPhone.isNotEmpty ? newPhone : user.phone,
                      image: user.image,
                      role: user.role,
                      isBlocked: user.isBlocked,
                      blockReason: user.blockReason,
                      createdAt: user.createdAt,
                    );

                    await ref.read(authProvider.notifier).updateUser(updatedUser);

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF15803D),
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Profile updated successfully!'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _promptOtpVerification({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Future<void> Function(String otp) onVerify,
  }) async {
    final otpCtrl = TextEditingController();
    String? errorText;
    bool isLoading = false;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(dialogCtx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: const Color(0xFF64748B), height: 1.3),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: errorText != null ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: 'ENTER 6-DIGIT OTP',
                      hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            final otp = otpCtrl.text.trim();
                            if (otp.length < 4) {
                              setDialogState(() => errorText = 'Please enter a valid OTP');
                              return;
                            }
                            setDialogState(() {
                              isLoading = true;
                              errorText = null;
                            });
                            try {
                              await onVerify(otp);
                              if (context.mounted) {
                                Navigator.pop(dialogCtx, true);
                              }
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                                errorText = 'Invalid OTP code. Please check and retry.';
                              });
                            }
                          },
                    child: isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'Verify & Update',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return success ?? false;
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out of FastKirana?',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
        ),
        content: Text(
          'You will need to enter your phone or email to log back in.',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
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
            child: Text('Log Out', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
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
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(
              'FastKirana 24x7 Customer Care',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'We are here to assist with orders, deliveries & refunds in Ghatampur',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('tel:+918112849854');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              title: Text('Call Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('+91 81128 49854 (Instant Call)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: const Color(0xFF64748B))),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('https://wa.me/918112849854?text=Hello%20FastKirana%20Support');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                child: const Text('💬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
              ),
              title: Text('WhatsApp Chat Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('Chat with Ghatampur Support team', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: const Color(0xFF64748B))),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              onTap: () async {
                final uri = Uri.parse('mailto:fastkiranadelivery@gmail.com?subject=FastKirana%20Customer%20Support');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.email_outlined, color: Color(0xFFDC2626), size: 22),
              ),
              title: Text('Email Support', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800)),
              subtitle: Text('fastkiranadelivery@gmail.com', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: const Color(0xFF64748B))),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);
    final user = userAsync.valueOrNull;
    final userId = user?.id ?? 'cmqgzqeud0000vkid7hd6mti4';
    final ordersAsync = ref.watch(ordersProvider(userId));
    final wishlist = ref.watch(wishlistProvider);
    final addresses = ref.watch(addressesProvider).valueOrNull ?? [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    final ordersCount = ordersAsync.valueOrNull?.length ?? 0;

    final role = (user?.role ?? 'USER').toUpperCase();
    
    // 1. Dynamic Super Admin Role (Pure DB Role)
    final isAdmin = role == 'ADMIN';

    // 2. Dynamic Rider / Delivery Role
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

    final name = (user?.name?.isNotEmpty == true && user?.name != 'FastKirana Customer')
        ? user!.name!
        : (isAdmin
            ? 'FastKirana Admin'
            : (isRiderOnly
                ? 'Delivery Partner'
                : (isChefOrOwnerOnly
                    ? 'Restaurant Chef'
                    : (isPickerOnly ? 'Warehouse Picker' : 'FastKirana Customer'))));

    String phoneDisplay;
    if (user?.phone?.isNotEmpty == true) {
      final raw = user!.phone!.trim();
      phoneDisplay = raw.startsWith('+91') ? raw : '+91 $raw';
    } else {
      phoneDisplay = user?.email ?? 'Not logged in';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── 1. Luxury Glassmorphic Header ─────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE11D48), Color(0xFFDC2626), Color(0xFF991B1B)],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33DC2626),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: user == null
                        ? _buildGuestHeader(context)
                        : _buildUserHeader(context, ref, user, name, phoneDisplay),
                  ),
                ),
              ),
            ),

            // ─── 2. Partner Banner / Admin Suite (Role Specific) ───────────
            if (isAdmin)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFD97706)),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Operations Command Suite',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ADMIN',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 8.5),
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF15803D),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOperationBentoTile(
                                title: 'Admin Console',
                                subtitle: 'Store & Orders',
                                emoji: '🛡️',
                                badge: 'ADMIN',
                                gradientColors: [const Color(0xFFB45309), const Color(0xFFD97706)],
                                bgTint: const Color(0xFFFFFBEB),
                                borderColor: const Color(0xFFFDE68A),
                                textColor: const Color(0xFF92400E),
                                onTap: () => Navigator.push(context, FadeSlideRoute(page: const AdminDashboard())),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildOperationBentoTile(
                                title: 'Rider Console',
                                subtitle: 'GPS & Deliveries',
                                emoji: '🛵',
                                badge: 'RIDER',
                                gradientColors: [const Color(0xFF15803D), const Color(0xFF16A34A)],
                                bgTint: const Color(0xFFF0FDF4),
                                borderColor: const Color(0xFFBBF7D0),
                                textColor: const Color(0xFF166534),
                                onTap: () => Navigator.push(context, FadeSlideRoute(page: const DeliveryDashboard())),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildOperationBentoTile(
                                title: 'Kitchen KOT',
                                subtitle: 'Cooking Orders',
                                emoji: '👨‍🍳',
                                badge: 'KITCHEN',
                                gradientColors: [const Color(0xFFDC2626), const Color(0xFFE11D48)],
                                bgTint: const Color(0xFFFEF2F2),
                                borderColor: const Color(0xFFFECACA),
                                textColor: const Color(0xFF991B1B),
                                onTap: () => Navigator.push(context, FadeSlideRoute(page: const RestaurantDashboard())),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildOperationBentoTile(
                                title: 'Picker Hub',
                                subtitle: 'Item Packing',
                                emoji: '📦',
                                badge: 'PICKER',
                                gradientColors: [const Color(0xFFEA580C), const Color(0xFFF97316)],
                                bgTint: const Color(0xFFFFF7ED),
                                borderColor: const Color(0xFFFED7AA),
                                textColor: const Color(0xFF9A3412),
                                onTap: () => Navigator.push(context, FadeSlideRoute(page: const PickerDashboard())),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ─── RIDER ONLY: Sleek Partner Card ───────────────────────────
            if (isRiderOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, FadeSlideRoute(page: const DeliveryDashboard()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: const Center(child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Delivery Partner Dashboard',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14.5), fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 8.5), fontWeight: FontWeight.w900, color: const Color(0xFF047857))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Tap to open GPS routes & active order pickups ➔',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ─── RESTAURANT ONLY: Kitchen Card ───────────────────────────
            if (isChefOrOwnerOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        FadeSlideRoute(
                          page: RestaurantDashboard(
                            initialRestaurantId: user?.assignedRestaurantId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF881337), Color(0xFFBE123C), Color(0xFFE11D48)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: const Center(child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Restaurant Kitchen Console',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14.5), fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                      child: Text('KITCHEN', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 8.5), fontWeight: FontWeight.w900, color: const Color(0xFFBE123C))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Manage live cooking orders, KOT slips & menu ➔',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ─── PICKER ONLY: Warehouse Picker Card ────────────────────────
            if (isPickerOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Bounceable(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        FadeSlideRoute(page: const PickerDashboard()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: const Center(child: Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Picker Hub Console',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14.5), fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                      child: Text('PICKER', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 8.5), fontWeight: FontWeight.w900, color: const Color(0xFF4338CA))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Pack orders, scan barcodes & assign riders ➔',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ─── 3. Quick Stats Grid (Clean, Elevated, Minimalist) ─────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    _buildShortcutCard(
                      context,
                      iconWidget: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      title: 'My Orders',
                      subtitle: ordersCount > 0 ? '$ordersCount Placed' : 'No Orders',
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const OrdersScreen())),
                    ),
                    const SizedBox(width: 10),
                    _buildShortcutCard(
                      context,
                      iconWidget: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 20),
                      ),
                      title: 'Wishlist',
                      subtitle: wishlist.isNotEmpty ? '${wishlist.length} Items' : '0 Saved',
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const WishlistScreen())),
                    ),
                    const SizedBox(width: 10),
                    _buildShortcutCard(
                      context,
                      iconWidget: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 20),
                      ),
                      title: 'Addresses',
                      subtitle: addresses.isNotEmpty ? '${addresses.length} Saved' : 'Add New',
                      onTap: () => Navigator.push(context, FadeSlideRoute(page: const AddressBookScreen())),
                    ),
                  ],
                ),
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
                    _buildSectionHeader('ACCOUNT & ADDRESSES'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            context,
                            icon: Icons.location_on_rounded,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            title: 'Saved Addresses',
                            subtitle: addresses.isNotEmpty ? '${addresses.length} locations saved in Ghatampur' : 'Add home, office or shop location',
                            badge: addresses.isNotEmpty ? '${addresses.length}' : null,
                            onTap: () => Navigator.push(context, FadeSlideRoute(page: const AddressBookScreen())),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildMenuItem(
                            context,
                            icon: Icons.notifications_active_rounded,
                            iconBg: const Color(0xFFEEF2FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: 'Notifications & Alerts',
                            subtitle: 'Order tracking, offers & dispatch updates',
                            onTap: () => Navigator.push(context, FadeSlideRoute(page: const NotificationsScreen())),
                          ),
                          if (user != null) ...[
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildMenuItem(
                              context,
                              icon: Icons.edit_note_rounded,
                              iconBg: const Color(0xFFF8FAFC),
                              iconColor: const Color(0xFF475569),
                              title: 'Personal Information',
                              subtitle: 'Edit your name, phone & email',
                              onTap: () => _showEditProfileModal(context, ref, user),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Help & Support
                    _buildSectionHeader('SUPPORT & FASTKIRANA'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            context,
                            icon: Icons.headset_mic_rounded,
                            iconBg: const Color(0xFFFAF5FF),
                            iconColor: const Color(0xFF7E22CE),
                            title: '24x7 Customer Support',
                            subtitle: 'Direct WhatsApp & phone assistance',
                            badge: 'FAST HELP',
                            badgeColor: const Color(0xFF7E22CE),
                            onTap: () => _showSupportModal(context),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildMenuItem(
                            context,
                            icon: Icons.share_rounded,
                            iconBg: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFD97706),
                            title: 'Share with Friends & Family',
                            subtitle: 'Invite neighbours to 10-min delivery',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Share.share(
                                '⚡ FastKirana Express: Order Groceries & Food in Ghatampur in 10-15 mins!\n\nDownload app: https://www.fastkirana.in',
                                subject: 'FastKirana Express Ghatampur',
                              );
                            },
                          ),
                          if (user != null) ...[
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            _buildMenuItem(
                              context,
                              icon: Icons.logout_rounded,
                              iconBg: const Color(0xFFFEF2F2),
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
                              Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                'FastKirana Express v1.0.0',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF94A3B8),
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
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: Responsive.scaledFontSize(context, 10.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGuestHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, size: 28, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to FastKirana',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 18),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Log in for 10-min delivery & live tracking',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, FadeSlideRoute(page: const LoginScreen()));
            },
            child: Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Login / Sign Up ➔',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      color: primaryRed,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context,
    WidgetRef ref,
    User user,
    String name,
    String phoneDisplay,
  ) {
    final role = user.role.toUpperCase();
    final isAdmin = role == 'ADMIN';
    final isRider = role == 'DELIVERY' || role == 'RIDER' || role == 'DELIVERY_PARTNER';
    final isRest = role == 'RESTAURANT_OWNER' || role == 'CHEF' || role == 'RESTAURANT';

    final badgeText = isAdmin
        ? '👑 STORE ADMIN'
        : (isRider
            ? '🛵 RIDER'
            : (isRest ? '👨‍🍳 RESTAURANT' : '⚡ FASTKIRANA MEMBER'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Monogram Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF08A), Color(0xFFFACC15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF991B1B),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 20),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 15.5),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phoneDisplay,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.88),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 8.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Edit Profile Button
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              _showEditProfileModal(context, ref, user);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, size: 12, color: Color(0xFFDC2626)),
                  const SizedBox(width: 3.5),
                  Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard(
    BuildContext context, {
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              iconWidget,
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationBentoTile({
    required String title,
    required String subtitle,
    required String emoji,
    required String badge,
    required List<Color> gradientColors,
    required Color bgTint,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Bounceable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 8),
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
    String? badge,
    Color? badgeColor,
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
        title: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13.5),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeColor != null ? badgeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w800,
                    color: badgeColor ?? const Color(0xFF475569),
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
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      ),
    );
  }
}