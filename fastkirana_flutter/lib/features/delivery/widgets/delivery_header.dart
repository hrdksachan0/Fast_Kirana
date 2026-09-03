import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../widgets/live_clock_badge.dart';

/// Top header for the delivery dashboard. Contains:
/// - Back button
/// - Online / Offline pill (toggles location tracking)
/// - Live clock pill
/// - Dark mode toggle
/// - Refresh button
/// - Partner greeting + avatar
/// - 3-segment tab bar (Deliveries | Cash Wallet | History)
class DeliveryHeader extends StatelessWidget {
  final bool isOnline;
  final bool isDarkMode;
  final String userName;
  final int refreshCountdown;
  final int activeTab;
  final VoidCallback onBack;
  final VoidCallback onToggleOnline;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onRefresh;
  final VoidCallback? onLogout;
  final ValueChanged<int> onTabChanged;

  const DeliveryHeader({
    super.key,
    required this.isOnline,
    required this.isDarkMode,
    required this.userName,
    required this.refreshCountdown,
    required this.activeTab,
    required this.onBack,
    required this.onToggleOnline,
    required this.onToggleDarkMode,
    required this.onRefresh,
    this.onLogout,
    required this.onTabChanged,
  });

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00965E), Color(0xFF007A48), Color(0xFF045D38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            children: [
              _statusBar(),
              const SizedBox(height: 12),
              _greeting(),
              const SizedBox(height: 12),
              _segmentedTabs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Bounceable(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            onToggleOnline();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF34D399) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        const LiveDigitalClockBadge(),
        const Spacer(),
        Bounceable(
          onTap: () {
            HapticFeedback.mediumImpact();
            onToggleDarkMode();
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Bounceable(
          onTap: () {
            HapticFeedback.lightImpact();
            onRefresh();
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
          ),
        if (onLogout != null) ...[
          const SizedBox(width: 6),
          Bounceable(
            onTap: onLogout,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.logout_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _greeting() {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'P',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 17),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 8),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greetingText().toUpperCase()} · DELIVERY PARTNER',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 9.5),
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.82),
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16.5),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('👋', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF34D399),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${refreshCountdown}s',
                style: GoogleFonts.robotoMono(
                  fontSize: Responsive.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF02462A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _segmentTab(0, 'Deliveries', Icons.local_shipping_rounded),
          _segmentTab(1, 'Cash Wallet', Icons.account_balance_wallet_rounded),
          _segmentTab(2, 'History', Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _segmentTab(int index, String label, IconData icon) {
    final isSelected = activeTab == index;
    return Expanded(
      child: Bounceable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTabChanged(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFF007A48) : Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w800,
                  color: isSelected ? const Color(0xFF007A48) : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}