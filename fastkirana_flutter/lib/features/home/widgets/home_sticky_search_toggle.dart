import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../widgets/voice_search_sheet.dart';
import '../../search/search_screen.dart';
import 'home_category_toggle.dart';

/// Ambient Search Bar with animated rotating placeholders and voice search.
class HomeStickySearchBar extends StatefulWidget {
  const HomeStickySearchBar({super.key});

  @override
  State<HomeStickySearchBar> createState() => _HomeStickySearchBarState();
}

class _HomeStickySearchBarState extends State<HomeStickySearchBar> {
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
    _startSearchTimer();
  }

  void _startSearchTimer() {
    _searchTimer?.cancel();
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, FadeSlideRoute(page: const SearchScreen()));
      },
      child: Container(
        height: 46,
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
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ambient Lens Badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFEE2E2),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.search_rounded,
                size: 16,
                color: AppDesignSystem.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Builder(
                builder: (context) {
                  final placeholderText = _dynamicPlaceholders[
                      _searchPlaceholderIndex % _dynamicPlaceholders.length];

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
              child: Semantics(
                button: true,
                label: 'Voice search',
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFECDD3),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    size: 15,
                    color: AppDesignSystem.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky Persistent Header Delegate keeping Search Bar and Grocery/Food Tabs
/// fixed at the top of the screen across both Grocery and Food views.
class HomeStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isGrocerySelected;
  final ValueChanged<bool> onModeChanged;
  final double height;

  const HomeStickyHeaderDelegate({
    required this.isGrocerySelected,
    required this.onModeChanged,
    this.height = 124.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final horizontalPadding = context.isCompact ? 10.0 : 16.0;
    final isPinned = overlapsContent || shrinkOffset > 0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isPinned
                ? const Color(0xFFCBD5E1)
                : const Color(0xFFF1F5F9),
            width: 1.2,
          ),
        ),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              8,
            ),
            child: const HomeStickySearchBar(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              12,
            ),
            child: HomeCategoryToggle(
              isGrocerySelected: isGrocerySelected,
              onModeChanged: onModeChanged,
              height: 50.0,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeStickyHeaderDelegate oldDelegate) {
    return oldDelegate.isGrocerySelected != isGrocerySelected ||
        oldDelegate.height != height;
  }
}
