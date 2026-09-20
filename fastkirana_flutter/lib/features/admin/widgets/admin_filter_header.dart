import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Top control header for Admin Orders: segmented tabs, search box, auto-approve toggle, and sub-filter chips
class AdminFilterHeader extends StatefulWidget {
  final int selectedTab;
  final int displayLiveCount;
  final int displayHistoryCount;
  final int displayPendingPaymentCount;
  final String searchQuery;
  final bool isAutoApprove;
  final List<String> liveStatusFilters;
  final List<String> historyStatusFilters;
  final String currentSubFilter;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<bool> onToggleAutoApprove;
  final ValueChanged<String> onFilterSelected;

  const AdminFilterHeader({
    super.key,
    required this.selectedTab,
    required this.displayLiveCount,
    required this.displayHistoryCount,
    required this.displayPendingPaymentCount,
    required this.searchQuery,
    required this.isAutoApprove,
    required this.liveStatusFilters,
    required this.historyStatusFilters,
    required this.currentSubFilter,
    required this.onTabChanged,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onToggleAutoApprove,
    required this.onFilterSelected,
  });

  @override
  State<AdminFilterHeader> createState() => _AdminFilterHeaderState();
}

class _AdminFilterHeaderState extends State<AdminFilterHeader> {
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryRed = AppDesignSystem.primary;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
  }

  @override
  void didUpdateWidget(covariant AdminFilterHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Primary Tab Switcher (Live vs History with modern iOS-style segmented control)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate100,
              borderRadius: BorderRadius.circular(16),
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

        // 2. Search Field with Instant Clear
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
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
                const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.slate600),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        widget.onSearchChanged(val.toLowerCase().trim());
                      });
                    },
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by Order ID, customer, phone...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      widget.onSearchCleared();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppDesignSystem.slate200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppDesignSystem.slate600),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. Auto-Approve Fast Switch Banner
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: widget.isAutoApprove ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isAutoApprove ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.isAutoApprove ? Icons.bolt_rounded : Icons.admin_panel_settings_rounded,
                  size: 20,
                  color: widget.isAutoApprove ? AppDesignSystem.green600 : const Color(0xFFEA580C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.isAutoApprove ? 'AUTO-APPROVE: ON' : 'MANUAL APPROVAL: ON',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w900,
                              color: widget.isAutoApprove ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: widget.isAutoApprove ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.isAutoApprove ? 'Direct to Kitchen' : 'Admin Call Gate',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9),
                                fontWeight: FontWeight.w800,
                                color: widget.isAutoApprove ? const Color(0xFF166534) : const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.isAutoApprove
                            ? 'Incoming orders reach restaurant console immediately'
                            : 'Orders pause for call verification before restaurant sees them',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w500,
                          color: widget.isAutoApprove ? const Color(0xFF166534) : const Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: FittedBox(
                    child: Switch(
                      value: widget.isAutoApprove,
                      activeThumbColor: AppDesignSystem.green600,
                      activeTrackColor: const Color(0xFFBBF7D0),
                      inactiveThumbColor: const Color(0xFFEA580C),
                      inactiveTrackColor: const Color(0xFFFED7AA),
                      onChanged: widget.onToggleAutoApprove,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Status Sub-filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: (widget.selectedTab == 0 ? widget.liveStatusFilters : widget.historyStatusFilters).map((status) {
                final isSelected = widget.currentSubFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedback.selectionClick();
                        widget.onFilterSelected(status);
                      }
                    },
                    label: Text(
                      status == 'ALL'
                          ? (widget.selectedTab == 0 ? 'All Live' : 'All History')
                          : (status == 'PAYMENT_PENDING'
                              ? '⚠️ Payment Pending${widget.displayPendingPaymentCount > 0 ? ' (${widget.displayPendingPaymentCount})' : ''}'
                              : status),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
              }).toList(),
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
              size: 15,
              color: isSelected
                  ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                  : AppDesignSystem.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (index == 0 ? primaryRed : AppDesignSystem.slate900)
                    : AppDesignSystem.slate500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (index == 0 ? primaryRed.withValues(alpha: 0.12) : AppDesignSystem.slate200)
                    : AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10),
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
