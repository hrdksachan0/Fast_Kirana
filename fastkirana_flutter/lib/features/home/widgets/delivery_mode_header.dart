import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';

/// Clean, Modular Top Header for FastKirana Home
/// Handles: Location & Darkstore indicator, Animated Search Bar, and Grocery 🛒 vs Cafe ☕ Segmented Switcher.
class DeliveryModeHeader extends StatelessWidget {
  final bool isGrocerySelected;
  final ValueChanged<bool> onModeChanged;
  final String activeLocationTitle;
  final String activeLocationSubtitle;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;
  final VoidCallback onVoiceSearchTap;
  final VoidCallback onNotificationsTap;
  final String currentSearchPlaceholder;
  final Animation<double>? toggleNudgeAnim;
  final Animation<double>? toggleGlowAnim;
  final int unreadNotificationsCount;

  static const String grocerySvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <g filter="url(#shadow)">
    <path d="M22 24c0-5.5 4.5-10 10-10s10 4.5 10 10" fill="none" stroke="#FBBF24" stroke-width="4" stroke-linecap="round"/>
    <path d="M16 26h32l-3 34H19L16 26z" fill="#8B5CF6"/>
    <path d="M34 20c0-6 5-11 11-11s11 5 11 11" fill="none" stroke="#FDE047" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M28 22h34l-3 38H31L28 22z" fill="#EF4444"/>
    <path d="M42 12c-2-4 1-8 6-7 4 1 5 6 2 9-2 2-6 1-8-2z" fill="#22C55E"/>
    <path d="M48 9c1-3 5-4 7-1 2 2 1 6-2 7-3 1-5-3-5-6z" fill="#4ADE80"/>
  </g>
</svg>
''';

  static const String cafeSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <g>
    <path d="M16 26c0-6.6 5.4-12 12-12h16c6.6 0 12 5.4 12 12v3h-40v-3z" fill="#F59E0B"/>
    <rect x="14" y="32" width="44" height="6" rx="3" fill="#22C55E"/>
    <rect x="18" y="38" width="36" height="5" rx="2.5" fill="#EF4444"/>
    <rect x="12" y="43" width="48" height="7" rx="3.5" fill="#78350F"/>
    <rect x="16" y="50" width="40" height="5" rx="2.5" fill="#F59E0B"/>
    <path d="M14 55h44c0 6.6-5.4 12-12 12H26c-6.6 0-12-5.4-12-12z" fill="#D97706"/>
  </g>
</svg>
''';

  const DeliveryModeHeader({
    super.key,
    required this.isGrocerySelected,
    required this.onModeChanged,
    required this.activeLocationTitle,
    required this.activeLocationSubtitle,
    required this.onLocationTap,
    required this.onSearchTap,
    required this.onVoiceSearchTap,
    required this.onNotificationsTap,
    required this.currentSearchPlaceholder,
    this.toggleNudgeAnim,
    this.toggleGlowAnim,
    this.unreadNotificationsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystem.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate100,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Brand & Location Address Pill & Notification
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Delivery Location Selector
              Expanded(
                child: Bounceable(
                  onTap: onLocationTap,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: AppDesignSystem.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '10 MINS ⚡',
                                    style: AppDesignSystem.captionBold.copyWith(
                                      color: AppDesignSystem.primary,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: AppDesignSystem.slate700,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              activeLocationTitle.isNotEmpty
                                  ? activeLocationTitle
                                  : 'Deliver to Ghatampur...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppDesignSystem.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mode Switcher (Grocery vs Cafe Toggle Pill)
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildSegmentedModeToggle(context),
                ),
              ),

              const SizedBox(width: 8),

              // Notifications Icon
              Bounceable(
                onTap: onNotificationsTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppDesignSystem.darkSurfaceMuted : AppDesignSystem.slate50,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate200,
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate800,
                      ),
                    ),
                    if (unreadNotificationsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppDesignSystem.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unreadNotificationsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search Bar with animated rotating placeholder
          Bounceable(
            onTap: onSearchTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppDesignSystem.darkSurfaceMuted : AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppDesignSystem.darkBorder : AppDesignSystem.slate200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isGrocerySelected ? AppDesignSystem.primary : AppDesignSystem.cafeAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        'Search "$currentSearchPlaceholder"',
                        key: ValueKey(currentSearchPlaceholder),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.slate400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  // Mic / Voice Search Icon
                  Bounceable(
                    onTap: onVoiceSearchTap,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.mic_none_rounded,
                        color: AppDesignSystem.slate500,
                        size: 20,
                      ),
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

  Widget _buildSegmentedModeToggle(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppDesignSystem.slate100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grocery Pill
          Bounceable(
            onTap: () {
              if (!isGrocerySelected) {
                HapticFeedback.lightImpact();
                onModeChanged(true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGrocerySelected ? AppDesignSystem.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isGrocerySelected
                    ? [
                        BoxShadow(
                          color: AppDesignSystem.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: SvgPicture.string(grocerySvg),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Mart',
                    style: TextStyle(
                      color: isGrocerySelected ? Colors.white : AppDesignSystem.slate600,
                      fontWeight: isGrocerySelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cafe / Food Pill
          Bounceable(
            onTap: () {
              if (isGrocerySelected) {
                HapticFeedback.lightImpact();
                onModeChanged(false);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: !isGrocerySelected ? AppDesignSystem.cafeAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: !isGrocerySelected
                    ? [
                        BoxShadow(
                          color: AppDesignSystem.cafeAccent.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: SvgPicture.string(cafeSvg),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cafe',
                    style: TextStyle(
                      color: !isGrocerySelected ? Colors.white : AppDesignSystem.slate600,
                      fontWeight: !isGrocerySelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
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
