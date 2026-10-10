import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Pinned Sticky Header for Admin Orders:
/// - Segmented Tab Switcher (Live Orders vs History)
/// - On-Demand Search (Icon tap expands sleek full-width search input)
/// - Sub-filter status chips
class AdminFilterHeader extends StatefulWidget {
  final int selectedTab;
  final int displayLiveCount;
  final int displayHistoryCount;
  final int displayPendingPaymentCount;
  final String searchQuery;
  final List<String> liveStatusFilters;
  final List<String> historyStatusFilters;
  final String currentSubFilter;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onFilterSelected;
  final bool? isAutoApprove;
  final ValueChanged<bool>? onToggleAutoApprove;

  const AdminFilterHeader({
    super.key,
    required this.selectedTab,
    required this.displayLiveCount,
    required this.displayHistoryCount,
    required this.displayPendingPaymentCount,
    required this.searchQuery,
    required this.liveStatusFilters,
    required this.historyStatusFilters,
    required this.currentSubFilter,
    required this.onTabChanged,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterSelected,
    this.isAutoApprove,
    this.onToggleAutoApprove,
  });

  @override
  State<AdminFilterHeader> createState() => _AdminFilterHeaderState();
}

class _AdminFilterHeaderState extends State<AdminFilterHeader> {
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchOpen = false;

  static const Color primaryRed = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    if (widget.searchQuery.isNotEmpty) {
      _isSearchOpen = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdminFilterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
    if (widget.searchQuery.isNotEmpty && !_isSearchOpen) {
      _isSearchOpen = true;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchOpen = false;
    });
    _searchController.clear();
    widget.onSearchCleared();
  }

  void _openSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchOpen = true;
    });
    Future.microtask(() {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  String _formatStatusLabel(String status) {
    if (status == 'ALL') {
      return widget.selectedTab == 0 ? 'All Live' : 'All History';
    }
    if (status == 'PAYMENT_PENDING') {
      return '⚠️ Payment Pending${widget.displayPendingPaymentCount > 0 ? ' (${widget.displayPendingPaymentCount})' : ''}';
    }
    if (status == 'ADMIN_PENDING') return 'Admin Pending';
    if (status == 'PENDING') return 'Kitchen Pending';
    if (status == 'CONFIRMED') return 'Confirmed';
    if (status == 'PACKED') return 'Packed';
    if (status == 'SHIPPED') return 'Shipped';
    if (status == 'DELIVERED') return 'Delivered';
    if (status == 'CANCELLED') return 'Cancelled';
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = widget.selectedTab == 0 ? widget.liveStatusFilters : widget.historyStatusFilters;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppDesignSystem.slate200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Segmented Tabs OR Active Search Input Bar
          SizedBox(
            height: 40,
            child: _isSearchOpen ? _buildSearchInputRow() : _buildTabsWithSearchButtonRow(),
          ),

          const SizedBox(height: 6),

          // Row 2: Status Sub-filter Chips (Horizontal scroll)
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: activeFilters.length,
              itemBuilder: (context, index) {
                final status = activeFilters[index];
                final isSelected = widget.currentSubFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        widget.onFilterSelected(status);
                      }
                    },
                    label: Text(
                      _formatStatusLabel(status),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (status == 'PAYMENT_PENDING' && widget.displayPendingPaymentCount > 0
                                ? const Color(0xFFE11D48)
                                : AppDesignSystem.slate600),
                      ),
                    ),
                    selectedColor: status == 'PAYMENT_PENDING' ? const Color(0xFFE11D48) : AppDesignSystem.slate900,
                    backgroundColor: status == 'PAYMENT_PENDING' && widget.displayPendingPaymentCount > 0
                        ? const Color(0xFFFFF1F2)
                        : AppDesignSystem.slate100,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? (status == 'PAYMENT_PENDING' ? const Color(0xFFE11D48) : AppDesignSystem.slate900)
                            : (status == 'PAYMENT_PENDING' && widget.displayPendingPaymentCount > 0
                                ? const Color(0xFFFDA4AF)
                                : AppDesignSystem.slate200),
                        width: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the normal Row 1: Segmented Tabs (Live vs History) + On-Demand 🔍 Search Button
  Widget _buildTabsWithSearchButtonRow() {
    return Row(
      children: [
        // Segmented Control
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppDesignSystem.slate200, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMainTabButton(
                    index: 0,
                    label: 'Live Orders',
                    count: widget.displayLiveCount,
                    icon: Icons.bolt_rounded,
                    isSelected: widget.selectedTab == 0,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMainTabButton(
                    index: 1,
                    label: 'Order History',
                    count: widget.displayHistoryCount,
                    icon: Icons.history_rounded,
                    isSelected: widget.selectedTab == 1,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // On-Demand Search Icon Button
        GestureDetector(
          onTap: _openSearch,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.searchQuery.isNotEmpty ? primaryRed.withValues(alpha: 0.1) : AppDesignSystem.slate100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.searchQuery.isNotEmpty ? primaryRed : AppDesignSystem.slate200,
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: widget.searchQuery.isNotEmpty ? primaryRed : AppDesignSystem.slate700,
                ),
                if (widget.searchQuery.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the active Search Input Row when user taps Search icon
  Widget _buildSearchInputRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryRed.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          // Back button to close search
          GestureDetector(
            onTap: _closeSearch,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: AppDesignSystem.slate700),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  widget.onSearchChanged(val.toLowerCase().trim());
                });
              },
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.slate900,
              ),
              decoration: InputDecoration(
                hintText: 'Search order #, customer, phone...',
                hintStyle: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (widget.searchQuery.isNotEmpty || _searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                widget.onSearchCleared();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.slate200,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppDesignSystem.slate600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainTabButton({
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTabChanged(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
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
              color: isSelected
                  ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                  : AppDesignSystem.slate500,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                    : AppDesignSystem.slate500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (index == 0 ? primaryRed.withValues(alpha: 0.12) : AppDesignSystem.slate200)
                    : AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 9.5),
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                      : AppDesignSystem.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
