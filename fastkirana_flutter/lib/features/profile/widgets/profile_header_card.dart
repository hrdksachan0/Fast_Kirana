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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE11D48), // Rose 600
              Color(0xFFDC2626), // Red 600
              Color(0xFF991B1B), // Red 800
            ],
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: user == null
                ? _buildGuestHeader(context)
                : _buildUserHeader(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, size: 28, color: AppDesignSystem.red600),
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
                        fontSize: Responsive.scaledFontSize(context, 17.5),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Log in for 10-min delivery & live tracking',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    'Login / Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.red600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: AppDesignSystem.red600),
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
        ? 'STORE ADMIN'
        : (isRider
            ? 'RIDER'
            : (isRest ? 'RESTAURANT' : 'FASTKIRANA MEMBER'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Monogram Avatar disc with role pin
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 22),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.red600,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: isRider
                        ? const Color(0xFF059669)
                        : (isAdmin
                            ? const Color(0xFFD97706)
                            : (isRest ? const Color(0xFFEA580C) : const Color(0xFF2563EB))),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    isRider
                        ? Icons.moped_rounded
                        : (isAdmin
                            ? Icons.shield_rounded
                            : (isRest ? Icons.restaurant_rounded : Icons.verified_rounded)),
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),
          // User Details Column (Guaranteed Truncation-Free)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(
                      context,
                      name.length > 20 ? 14.5 : (name.length > 15 ? 15.5 : 16.5),
                    ),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.18,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.5),
                // Phone / Email
                Row(
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      size: 11.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        phoneDisplay,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Role Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRider ? '🛵' : (isAdmin ? '👑' : (isRest ? '👨‍🍳' : '⚡')),
                        style: const TextStyle(fontSize: 9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 8.5),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Edit Profile Button
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              onEditProfile();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, size: 12.5, color: AppDesignSystem.red600),
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
