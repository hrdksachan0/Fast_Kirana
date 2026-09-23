import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/user.dart';
import '../../auth/login_screen.dart';

class ProfileHeaderCard extends StatelessWidget {
  final User? user;
  final String name;
  final String phoneDisplay;
  final VoidCallback onEditProfile;

  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.name,
    required this.phoneDisplay,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppDesignSystem.rose600, AppDesignSystem.red600, AppDesignSystem.statusCancelledText],
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
              : _buildUserHeader(context),
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
                      color: AppDesignSystem.red600,
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

  Widget _buildUserHeader(BuildContext context) {
    final role = user!.role.toUpperCase();
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
                colors: [AppDesignSystem.yellow300, AppDesignSystem.yellow400],
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
                  color: AppDesignSystem.statusCancelledText,
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
              onEditProfile();
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
                  const Icon(Icons.edit_rounded, size: 12, color: AppDesignSystem.red600),
                  const SizedBox(width: 3.5),
                  Text(
                    'Edit',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.red600,
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
}
