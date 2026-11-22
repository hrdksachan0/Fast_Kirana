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
import '../../../providers/wallet_provider.dart';
import '../../wallet/wallet_screen.dart';
import '../../profile/notifications_screen.dart';
import '../../search/search_screen.dart';
import '../../navratri/navratri_data.dart';
import '../../../widgets/festive_fairy_lights.dart';
import '../../../providers/store_settings_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeTopHeader extends ConsumerStatefulWidget {
  final bool showSearch;
  const HomeTopHeader({super.key, this.showSearch = true});

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
    _syncSearchTimer();
  }

  @override
  void didUpdateWidget(covariant HomeTopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showSearch != widget.showSearch) _syncSearchTimer();
  }

  void _syncSearchTimer() {
    _searchTimer?.cancel();
    if (!widget.showSearch) return;
    _searchTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (mounted) {
        setState(() {
          _searchPlaceholderIndex =
              (_searchPlaceholderIndex + 1) % _dynamicPlaceholders.length;
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
    final campaignAsync = ref.watch(navratriDataProvider);
    final activeData = campaignAsync.valueOrNull ?? memoryCachedCampaign;
    final isCampaignActive = activeData?.enabled == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isCampaignActive ? const Color(0xFFFFF9ED) : Colors.white,
        gradient: isCampaignActive
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF5DC), // Warm golden festive ivory
                  Color(0xFFFFFDF8), // Soft warm ambient
                ],
              )
            : null,
      ),
      padding: EdgeInsets.fromLTRB(
        context.isCompact ? 10 : 14,
        6,
        context.isCompact ? 10 : 14,
        widget.showSearch ? 8 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo + 10-15 MIN Delivery Speed Header + Notifications
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // FastKirana Speed Logo
              FastKiranaLogoWidget(size: context.isCompact ? 30 : 36),
              SizedBox(width: context.isCompact ? 8 : 12),

              // 10-15 Min Fast Delivery Header & Location Selector
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final selectedAddress = ref.watch(selectedAddressProvider);
                    final recentFeedback = ref.watch(recentLocationFeedbackProvider);
                    final currentHub = ref.watch(currentStoreHubProvider);
                    final hasLocation = selectedAddress != null &&
                        selectedAddress.latitude != null &&
                        selectedAddress.latitude != 0.0;

                    final shortLocation = hasLocation
                        ? selectedAddress.shortAddress
                        : 'Select Location';
                    final displayLoc = shortLocation
                        .replaceAll(RegExp(r'\s+Central\s+Hub', caseSensitive: false), '')
                        .trim();
                    final addrLabel = (hasLocation && selectedAddress.label.trim().isNotEmpty)
                        ? selectedAddress.label.trim().replaceAll('📍', '').trim()
                        : '';

                    final String line1Text;
                    if (!hasLocation) {
                      line1Text = 'Delivery';
                    } else if (addrLabel.isNotEmpty &&
                        ['home', 'work', 'office'].contains(addrLabel.toLowerCase()) &&
                        addrLabel.toLowerCase() != displayLoc.toLowerCase()) {
                      line1Text = 'Delivering to $addrLabel';
                    } else {
                      line1Text = 'Delivering to';
                    }

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AddressSelectorSheet.show(
                          context,
                          activeAddress: selectedAddress,
                          onAddressSelected: (addr) {
                            final distKm = (addr.latitude != null &&
                                    addr.longitude != null)
                                ? LocationService.getDistanceKm(
                                    addr.latitude!,
                                    addr.longitude!,
                                    originLat: currentHub.latitude,
                                    originLng: currentHub.longitude,
                                  )
                                : 0.0;
                            if (distKm > currentHub.deliveryRadiusKm) {
                              UnserviceableLocationBanner
                                  .showUnserviceableModal(context, ref, distKm);
                            } else {
                              showLocationFeedback(ref, '${distKm.toStringAsFixed(1)} km');
                            }
                          },
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Line 1: Delivering to [Selected Area] or Set Delivery Location
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE11D48),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                line1Text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize:
                                      Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Line 2: Location title + dropdown arrow + Distance Feedback Pill right next to it!
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayLoc,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(
                                        context, 14.5),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.textPrimary,
                                    height: 1.15,
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 18, color: AppDesignSystem.textPrimary),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  reverseDuration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeInOut,
                                      ),
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.82, end: 1.0).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          ),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: (recentFeedback != null &&
                                          recentFeedback.trim().isNotEmpty &&
                                          recentFeedback.trim() != 'km' &&
                                          !recentFeedback.startsWith(' km') &&
                                          RegExp(r'\d').hasMatch(recentFeedback))
                                      ? Container(
                                          key: const ValueKey('header_feedback_active'),
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFA7F3D0),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_rounded,
                                                size: 11,
                                                color: Color(0xFF059669),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                recentFeedback,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF065F46),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(key: ValueKey('header_feedback_empty')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Consumer(
                builder: (context, ref, _) {
                  final wallet = ref.watch(walletNotifierProvider);
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(context, FadeSlideRoute(page: const WalletScreen()));
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 31,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: isCampaignActive ? const Color(0xFFFFF8E7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCampaignActive ? const Color(0xFFFFD54F) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👛', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '₹${wallet.totalUsable.toStringAsFixed(0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Notifications',
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context,
                      FadeSlideRoute(page: const NotificationsScreen()));
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCampaignActive ? const Color(0xFFFFFDF8) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCampaignActive ? const Color(0xFFFFE082) : const Color(0xFFF1F5F9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isCampaignActive
                            ? const Color(0xFFD97706).withValues(alpha: 0.08)
                            : const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 18, color: Color(0xFF334155)),
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
          if (widget.showSearch) ...[
            const SizedBox(height: 12),

            // 2. Ambient Search Pill (Floating glow & soft ambient depth)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                    context, FadeSlideRoute(page: const SearchScreen()));
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isCampaignActive ? const Color(0xFFFFD54F) : const Color(0xFFE2E8F0),
                    width: isCampaignActive ? 1.3 : 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCampaignActive
                          ? const Color(0xFFD97706).withValues(alpha: 0.08)
                          : const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ambient Lens Badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCampaignActive ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isCampaignActive ? const Color(0xFFFFE082) : const Color(0xFFFEE2E2), width: 0.8),
                      ),
                      child: Icon(
                        Icons.search_rounded,
                        size: 15,
                        color: isCampaignActive ? const Color(0xFFD97706) : AppDesignSystem.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final placeholderText = _dynamicPlaceholders[
                              _searchPlaceholderIndex %
                                  _dynamicPlaceholders.length];

                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            layoutBuilder: (Widget? currentChild,
                                List<Widget> previousChildren) {
                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: <Widget>[
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
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
                                  fontSize:
                                      Responsive.scaledFontSize(context, 13),
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
                            FadeSlideRoute(
                                page: SearchScreen(initialQuery: query)),
                          );
                        });
                      },
                      child: Semantics(
                        button: true,
                        label: 'Voice search',
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isCampaignActive ? const Color(0xFFFEF3C7) : const Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isCampaignActive ? const Color(0xFFFFE082) : const Color(0xFFFECDD3), width: 0.8),
                          ),
                          child: Icon(Icons.mic_rounded,
                              size: 15, color: isCampaignActive ? const Color(0xFFD97706) : AppDesignSystem.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: isCampaignActive
                ? Builder(
                    builder: (context) {
                      final storeSettings = ref.watch(storeSettingsProvider).valueOrNull;
                      final campaign = campaignAsync.valueOrNull;

                      // Priority:
                      // 1. Cloud Store Settings (jhallar_palette / fairy_lights_palette)
                      // 2. Cloud Campaign Data (jhallarPalette)
                      // 3. Fallback default: 'multi' (Blinkit Multi-Color 🌈)
                      final rawCloudPalette = storeSettings?.raw['jhallar_palette']?.toString() ??
                          storeSettings?.raw['fairy_lights_palette']?.toString() ??
                          campaign?.jhallarPalette;

                      final palette = (rawCloudPalette != null && rawCloudPalette.trim().isNotEmpty)
                          ? rawCloudPalette.trim().toLowerCase()
                          : 'multi';

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Ornate Diwali Brass Diya
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: SvgPicture.asset(
                                'assets/navratri/diwali-single-diya.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: FestiveFairyLights(height: 22, palette: palette),
                            ),
                            const SizedBox(width: 4),
                            // Right Ornate Diwali Brass Diya
                            Transform.flip(
                              flipX: true,
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: SvgPicture.asset(
                                  'assets/navratri/diwali-single-diya.svg',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}