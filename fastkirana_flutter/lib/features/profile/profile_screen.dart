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
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update your name, phone and email address',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
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
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
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
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Phone Number',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
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
                    Text('+91 ', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '10-digit mobile number',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
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
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
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
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
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
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
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
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
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
                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.3),
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
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: 'ENTER 6-DIGIT OTP',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600),
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
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
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
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'We are here to assist with orders, deliveries & refunds in Ghatampur',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
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
              title: Text('Call Support', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text('+91 81128 49854 (Instant Call)', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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
                child: const Text('💬', style: TextStyle(fontSize: 20)),
              ),
              title: Text('WhatsApp Chat Support', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text('Chat with Ghatampur Support team', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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
              title: Text('Email Support', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text('fastkiranadelivery@gmail.com', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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

    final cleanPhone = (user?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    
    // 1. Super Admin Role (7054470303)
    final isAdmin = user?.role == 'ADMIN' || 
                    cleanPhone == '7054470303' || 
                    (user?.email.toLowerCase() == 'admin@fastkirana.in') ||
                    (user?.email.toLowerCase() == 'admin@fastkirana.com');

    // 2. Rider / Delivery Role (Aryan & Delivery Partners)
    final isRider = user?.role == 'RIDER' || 
                    user?.role == 'DELIVERY' ||
                    user?.role == 'DELIVERY_PARTNER' ||
                    isAdmin;

    // 3. Restaurant Head Role (8112849854 - AS Restaurant / Wedson Restaurant)
    final isChefOrOwner = user?.role == 'CHEF' || 
                          user?.role == 'RESTAURANT_OWNER' || 
                          cleanPhone == '8112849854' ||
                          isAdmin;

    // 4. Warehouse Picker Role (9800001122 - Suresh Picker)
    final isPicker = user?.role == 'PICKER' || 
                     cleanPhone == '9800001122' || 
                     isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
          // 1. Premium Brand Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE11D48), Color(0xFFDC2626), Color(0xFF991B1B)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33DC2626),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: user == null
                      ? _buildGuestHeader(context)
                      : _buildUserHeader(context, ref, user),
                ),
              ),
            ),
          ),

          // Top Delivery Partner Quick Access Banner (Only when logged in as RIDER)
          if (isRider)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(page: const DeliveryDashboard()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF15803D), Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🛵', style: TextStyle(fontSize: 21)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Delivery Partner Dashboard',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'RIDER',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to manage live pickups, GPS & deliveries',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
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

          // Top Admin & Store Portal Quick Access Banner (Shows for 7054470303 or ADMIN)
          if (isAdmin)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(page: const AdminDashboard()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB45309), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🛡️', style: TextStyle(fontSize: 21)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Admin & Store Portal',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'ADMIN',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage live orders, catalog & store operations',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
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

          // Top Restaurant Partner Console Quick Access Banner (Shows for Chef, Owner, or Admin)
          if (isChefOrOwner)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    String? targetRestId;
                    String? targetRestName;
                    if (cleanPhone == '8112849854') {
                      targetRestId = outletAsRestaurantId;
                      targetRestName = 'A.S. Restaurant';
                    } else if (cleanPhone == '9250138656') {
                      targetRestId = outletWedsonId;
                      targetRestName = 'Wedson Restaurant';
                    } else if (cleanPhone == '7991488783') {
                      targetRestId = outletBalUdyanId;
                      targetRestName = 'Bal Udyan Restaurant';
                    }
                    Navigator.push(
                      context,
                      FadeSlideRoute(
                        page: RestaurantDashboard(
                          initialRestaurantId: targetRestId,
                          initialRestaurantName: targetRestName,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFE11D48)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('👨‍🍳', style: TextStyle(fontSize: 21)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Restaurant Partner Console',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'KITCHEN',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage live kitchen orders, cooking timer & 86 stock',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
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

          // Top Picker Dashboard Quick Access Banner (Shows for Picker or Admin)
          if (isPicker)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      FadeSlideRoute(page: const PickerDashboard()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('📦', style: TextStyle(fontSize: 21)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Warehouse Picker Dashboard',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'PICKER',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFEA580C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pack incoming grocery items & notify riders',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
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

          // 2. Quick 3-Column Shortcut Strip (Connected to Real DB & Stores)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  _buildShortcutCard(
                    context,
                    iconWidget: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    title: 'Orders',
                    subtitle: ordersCount > 0 ? '$ordersCount Placed' : 'Live Track',
                    onTap: () => Navigator.push(context, FadeSlideRoute(page: const OrdersScreen())),
                  ),
                  const SizedBox(width: 10),
                  _buildShortcutCard(
                    context,
                    iconWidget: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    title: 'Wishlist',
                    subtitle: wishlist.isNotEmpty ? '${wishlist.length} Items' : 'Saved Items',
                    onTap: () => Navigator.push(context, FadeSlideRoute(page: const WishlistScreen())),
                  ),
                  const SizedBox(width: 10),
                  _buildShortcutCard(
                    context,
                    iconWidget: Container(
                      padding: const EdgeInsets.all(8),
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

          // 3. Grouped Settings & Action Menu (World-Class Clean Tiles)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.receipt_long_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: 'My Orders',
                      subtitle: ordersCount > 0 ? '$ordersCount active & past orders' : 'Track live orders & order history',
                      badge: ordersCount > 0 ? '$ordersCount' : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const OrdersScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_rounded,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      title: 'Saved Addresses',
                      subtitle: addresses.isNotEmpty ? '${addresses.length} locations saved' : 'Add home, office & shop address',
                      badge: addresses.isNotEmpty ? '${addresses.length}' : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const AddressBookScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.favorite_rounded,
                      iconBg: const Color(0xFFFFF1F2),
                      iconColor: primaryRed,
                      title: 'My Wishlist',
                      subtitle: wishlist.isNotEmpty ? '${wishlist.length} products saved' : 'Saved items to buy later',
                      badge: wishlist.isNotEmpty ? '${wishlist.length}' : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const WishlistScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_active_rounded,
                      iconBg: const Color(0xFFEEF2FF),
                      iconColor: const Color(0xFF4F46E5),
                      title: 'Notifications & Alerts',
                      subtitle: 'Offers, live order tracking & dispatch updates',
                      onTap: () {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const NotificationsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.headset_mic_rounded,
                      iconBg: const Color(0xFFFAF5FF),
                      iconColor: const Color(0xFF7E22CE),
                      title: 'Help & Customer Support',
                      subtitle: '+91 81128 49854 (7 AM – 10 PM) · Ghatampur Care',
                      onTap: () => _showSupportModal(context),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.restaurant_menu_rounded,
                      iconBg: const Color(0xFFFFF1F2),
                      iconColor: primaryRed,
                      title: 'Restaurant Partner Console',
                      subtitle: 'Live kitchen KDS, order cooking timers & 86 stock',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: const RestaurantDashboard()),
                        );
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildMenuItem(
                      context,
                      icon: Icons.share_rounded,
                      iconBg: const Color(0xFFFFFBEB),
                      iconColor: const Color(0xFFD97706),
                      title: 'Share FastKirana App',
                      subtitle: 'Share 10-min delivery app with friends & family',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Share.share(
                          '⚡ Order Groceries, Daily Essentials & Restaurant Food in Ghatampur delivered in 10-15 mins with FastKirana!\n\nDownload app now: https://www.fastkirana.in',
                          subject: 'Download FastKirana App',
                        );
                      },
                    ),

                    // LOGOUT BUTTON (Only when logged in)
                    if (user != null) ...[
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
    ),
  );
  }

  Widget _buildGuestHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, size: 26, color: Colors.white),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Log in for express delivery & best offers',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                FadeSlideRoute(page: const LoginScreen()),
              );
            },
            child: Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Login / Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: primaryRed,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: primaryRed, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, WidgetRef ref, User user) {
    final name = (user.name != null && user.name!.isNotEmpty) ? user.name! : 'FastKirana Customer';
    String phoneDisplay;
    if (user.phone != null && user.phone!.isNotEmpty) {
      final raw = user.phone!.trim();
      phoneDisplay = raw.startsWith('+91') ? raw : '+91 $raw';
    } else {
      phoneDisplay = user.email;
    }
    final isAdmin = user.role == 'ADMIN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF08A), Color(0xFFFACC15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  phoneDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              _showEditProfileModal(context, ref, user);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
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
                fontSize: 13.5,
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
                    fontSize: 9.5,
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
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      ),
    );
  }
}