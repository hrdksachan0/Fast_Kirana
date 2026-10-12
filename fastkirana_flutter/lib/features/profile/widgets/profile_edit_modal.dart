import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/theme/design_system.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../providers/auth_provider.dart';

class ProfileEditModal {
  static void show(BuildContext context, WidgetRef ref, User user) {
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
            boxShadow: [
              BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. TOP DRAG HANDLE ───
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ─── 2. HEADER WITH CIRCULAR CLOSE BUTTON ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile Details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 18.5),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Update your name, phone and email address',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Bounceable(
                      scaleFactor: 0.92,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ─── 3. FULL NAME FIELD (CLEAN SINGLE SURFACE) ───
                _buildFieldLabel(context, 'Full Name'),
                const SizedBox(height: 7),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ─── 4. PHONE NUMBER FIELD (INTEGRATED +91 PREFIX) ───
                _buildFieldLabel(context, 'Phone Number'),
                const SizedBox(height: 7),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hintText: '10-digit mobile number',
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.phone_outlined,
                          color: Color(0xFF64748B),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+91',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1.2,
                          height: 20,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ─── 5. EMAIL ADDRESS FIELD ───
                _buildFieldLabel(context, 'Email Address'),
                const SizedBox(height: 7),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'user@fastkirana.in',
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // ─── 6. PREMIUM ACTION BUTTON (BOUNCEABLE + GRADIENT) ───
                Bounceable(
                  scaleFactor: 0.98,
                  onTap: () async {
                    final newName = nameCtrl.text.trim();
                    final newPhone = phoneCtrl.text.trim();
                    final newEmail = emailCtrl.text.trim();

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid name'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    HapticFeedback.mediumImpact();
                    final authRepo = AuthRepository(ref.read(dioProvider));

                    // 1. Phone number changed -> Require Phone OTP Verification
                    if (newPhone.isNotEmpty && newPhone != user.phone) {
                      try {
                        await authRepo.sendPhoneOtp(newPhone);
                        if (!context.mounted) return;
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
                            SnackBar(
                              content: Text('Failed to send phone OTP: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                    }

                    // 2. Email changed -> Require Email OTP Verification
                    if (newEmail.isNotEmpty && newEmail.toLowerCase() != (user.email.toLowerCase())) {
                      try {
                        await authRepo.sendEmailOtp(newEmail);
                        if (!context.mounted) return;
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
                            SnackBar(
                              content: Text('Failed to send email OTP: $e'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                    }

                    // 3. Name changed
                    if (newName.isNotEmpty && newName != user.name) {
                      try {
                        await authRepo.updateName(newName);
                      } catch (e, _) {
                        LoggerService.error('ProfileEditModal: silent catch', e);
                      }
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
                        const SnackBar(
                          backgroundColor: AppDesignSystem.green700,
                          content: Row(
                            children: [
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
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
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

  // ─── HELPER: FIELD LABEL ───
  static Widget _buildFieldLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: Responsive.scaledFontSize(context, 12.5),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF334155),
        letterSpacing: -0.2,
      ),
    );
  }

  // ─── HELPER: SINGLE CLEAN INPUT DECORATION (NO NESTED BOXES) ───
  static InputDecoration _buildInputDecoration({
    required String hintText,
    required Widget prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF94A3B8),
      ),
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
      ),
    );
  }

  // ─── OTP VERIFICATION DIALOG (CLEAN REDESIGN) ───
  static Future<bool> _promptOtpVerification({
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 16.5),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Bounceable(
                      scaleFactor: 0.92,
                      onTap: () => Navigator.pop(dialogCtx, false),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    color: const Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 20),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    hintText: '------',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: const Color(0xFFCBD5E1),
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: errorText != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: errorText != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE11D48),
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      color: const Color(0xFFE11D48),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Bounceable(
                  scaleFactor: 0.98,
                  onTap: isLoading
                      ? null
                      : () async {
                          final otp = otpCtrl.text.trim();
                          if (otp.length < 4) {
                            setDialogState(() => errorText = 'Please enter a valid OTP code');
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
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Verify & Update',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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
}
