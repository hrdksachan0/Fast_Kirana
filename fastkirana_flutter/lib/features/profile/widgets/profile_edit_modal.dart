import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile Details',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 17),
                              fontWeight: FontWeight.w900,
                              color: AppDesignSystem.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Update your name, phone and email address',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11.5),
                              color: AppDesignSystem.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppDesignSystem.slate500),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Full Name',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Phone Number',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Text(
                        '+91 ',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate600,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: '10-digit mobile number',
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
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.slate700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignSystem.slate200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'user@fastkirana.in',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.red600,
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
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppDesignSystem.slate500),
                      onPressed: () => Navigator.pop(dialogCtx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    color: AppDesignSystem.slate500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: errorText != null ? AppDesignSystem.red600 : AppDesignSystem.slate200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ENTER 6-DIGIT OTP',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        color: AppDesignSystem.slate400,
                        letterSpacing: 0.5,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorText!,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      color: AppDesignSystem.red600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.red600,
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
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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
