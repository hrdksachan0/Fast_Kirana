import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/services/location_service.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/store_hub_provider.dart';
import '../../../widgets/brand_logo.dart';
import '../../../widgets/address_selector_sheet.dart';
import '../../../widgets/unserviceable_location_banner.dart';
import '../../../widgets/voice_search_sheet.dart';
import '../../profile/notifications_screen.dart';
import '../../search/search_screen.dart';

class HomeTopHeader extends ConsumerStatefulWidget {
  const HomeTopHeader({super.key});

  @override
  ConsumerState<HomeTopHeader> createState() => _HomeTopHeaderState();
}

class _HomeTopHeaderState extends ConsumerState<HomeTopHeader> {
  int _searchPlaceholderIndex = 0;
  Timer? _searchTimer;

  static const List<String> _dynamicPlaceholders = [
    'Search for "milk"',
    'Search for "atta"',
    'Search for "chips"',
    'Search for "maggi"',
    'Search fresh fruits & veggies',
    'Search for "dairy milk"',
  ];

  @override
  void initState() {
    super.initState();
    _searchTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        setState(() {
          _searchPlaceholderIndex = (_searchPlaceholderIndex + 1) % _dynamicPlaceholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        context.isCompact ? 10 : 16,
        8,
        context.isCompact ? 10 : 16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + 10-15 MIN Delivery Speed Header + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: context.isCompact ? 34 : 40),
              SizedBox(width: context.isCompact ? 8 : 12),

              // 10-15 Min Fast Delivery Header & Location Selector
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final selectedAddress = ref.watch(selectedAddressProvider);
                    final currentHub = ref.watch(currentStoreHubProvider);
                    final locationLabel = selectedAddress?.displayLabel ?? 'Home';
                    final shortLocation = selectedAddress?.shortAddress ?? currentHub.city;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AddressSelectorSheet.show(
                          context,
                          activeAddress: selectedAddress,
                          onAddressSelected: (addr) {
                            final distKm = (addr.latitude != null && addr.longitude != null)
                                ? LocationService.getDistanceKm(
                                    addr.latitude!,
                                    addr.longitude!,
                                    originLat: currentHub.latitude,
                                    originLng: currentHub.longitude,
                                  )
                                : 0.0;
                            if (distKm > currentHub.deliveryRadiusKm) {
                              UnserviceableLocationBanner.showUnserviceableModal(context, ref, distKm);
                            }
                          },
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Delivering to $locationLabel',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.primaryGreen.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  currentHub.id.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Location title + dropdown arrow
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  shortLocation,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 14.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.textPrimary,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppDesignSystem.textPrimary),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Notification Icon with sleek double-bezel ambient container
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, FadeSlideRoute(page: const NotificationsScreen()));
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF334155)),
                      Positioned(
                        top: 9,
                        right: 9,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppDesignSystem.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Ambient Search Pill (Floating glow & soft ambient depth)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppDesignSystem.primary.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ambient Lens Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEE2E2), width: 0.8),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: AppDesignSystem.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final placeholderText =
                            _dynamicPlaceholders[_searchPlaceholderIndex % _dynamicPlaceholders.length];

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                            return Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: Align(
                            key: ValueKey<String>(placeholderText),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              placeholderText,
                              textAlign: TextAlign.left,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ambient Voice Mic Action Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      VoiceSearchSheet.show(context, onResult: (query) {
                        Navigator.push(
                          context,
                          FadeSlideRoute(page: SearchScreen(initialQuery: query)),
                        );
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
                      ),
                      child: const Icon(Icons.mic_rounded, size: 16, color: AppDesignSystem.primary),
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
