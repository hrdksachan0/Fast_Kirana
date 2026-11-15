import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
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
  final String selectedOutlet;
  final List<Map<String, dynamic>> outlets;
  final ValueChanged<String> onOutletSelected;
  final Map<String, int> statusCounts;

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
    this.selectedOutlet = 'ALL',
    this.outlets = const [],
    required this.onOutletSelected,
    this.statusCounts = const {},
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
    final count = widget.statusCounts[status];
    final countSuffix = (count != null && count > 0) ? ' ($count)' : '';
    if (status == 'ALL') {
      final total = widget.selectedTab == 0 ? widget.displayLiveCount : widget.displayHistoryCount;
      return widget.selectedTab == 0 ? 'All Live ($total)' : 'All History ($total)';
    }
    if (status == 'PAYMENT_PENDING') {
      return '⚠️ Payment Pending${widget.displayPendingPaymentCount > 0 ? ' (${widget.displayPendingPaymentCount})' : ''}';
    }
    if (status == 'ADMIN_PENDING') return '⚠️ Needs Approval$countSuffix';
    if (status == 'PENDING') return 'Kitchen Pending$countSuffix';
    if (status == 'CONFIRMED') return 'Confirmed$countSuffix';
    if (status == 'PACKED') return 'Packed$countSuffix';
    if (status == 'SHIPPED') return 'Shipped$countSuffix';
    if (status == 'DELIVERED') return 'Delivered$countSuffix';
    if (status == 'CANCELLED') return 'Cancelled$countSuffix';
    return '$status$countSuffix';
  }

  void _showOutletSelectorSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🏪', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          'Filter by Outlet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppDesignSystem.slate500),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select a darkstore or kitchen to view only its assigned orders.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppDesignSystem.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.outlets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                    itemBuilder: (context, index) {
                      final outlet = widget.outlets[index];
                      final outletId = outlet['id']?.toString() ?? 'ALL';
                      final outletName = outlet['name']?.toString() ?? 'All Outlets';
                      final count = outlet['count'] as int? ?? 0;
                      final iconStr = outlet['icon']?.toString() ?? '🏪';
                      final isSelected = widget.selectedOutlet == outletId;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF3B82F6) : AppDesignSystem.slate200,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(iconStr, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        title: Text(
                          outletName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFDBEAFE) : AppDesignSystem.slate100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? const Color(0xFF1D4ED8) : AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: isSelected ? const Color(0xFF2563EB) : AppDesignSystem.slate300,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onOutletSelected(outletId);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStatusSelectorSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final activeFilters = widget.selectedTab == 0 ? widget.liveStatusFilters : widget.historyStatusFilters;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          widget.selectedTab == 0 ? 'Filter Live Orders' : 'Filter Order History',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: AppDesignSystem.slate500),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Select an order status to filter the list.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppDesignSystem.slate500,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeFilters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                    itemBuilder: (context, index) {
                      final status = activeFilters[index];
                      final isSelected = widget.currentSubFilter == status;
                      final count = status == 'ALL'
                          ? (widget.selectedTab == 0 ? widget.displayLiveCount : widget.displayHistoryCount)
                          : (status == 'PAYMENT_PENDING' ? widget.displayPendingPaymentCount : (widget.statusCounts[status] ?? 0));

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        title: Text(
                          _formatStatusLabel(status),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.slate900 : AppDesignSystem.slate700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFDBEAFE) : AppDesignSystem.slate100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count orders',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? const Color(0xFF1D4ED8) : AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 20,
                              color: isSelected ? const Color(0xFF2563EB) : AppDesignSystem.slate300,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onFilterSelected(status);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutletDropdownPill(BuildContext context) {
    final selectedOutletData = widget.outlets.firstWhereOrNull((o) => o['id'] == widget.selectedOutlet);
    final isAll = widget.selectedOutlet == 'ALL';
    final name = selectedOutletData != null ? selectedOutletData['name']?.toString() ?? 'All Outlets' : 'All Outlets';
    final icon = selectedOutletData != null ? selectedOutletData['icon']?.toString() ?? '🏢' : '🏢';
    final count = selectedOutletData != null ? selectedOutletData['count'] as int? ?? 0 : widget.displayLiveCount;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showOutletSelectorSheet(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isAll ? const Color(0xFF0F172A) : const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAll ? const Color(0xFF0F172A) : const Color(0xFF0D9488),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isAll ? const Color(0xFF0F172A) : const Color(0xFF0F766E)).withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdownPill(BuildContext context) {
    final status = widget.currentSubFilter;
    final isAll = status == 'ALL';
    final total = widget.selectedTab == 0 ? widget.displayLiveCount : widget.displayHistoryCount;
    final count = isAll ? total : (widget.statusCounts[status] ?? 0);
    final label = status == 'ALL' ? (widget.selectedTab == 0 ? 'All Live' : 'All History') : _formatStatusLabel(status).split('(').first.trim();

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showStatusSelectorSheet(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isAll ? const Color(0xFF0F172A) : const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAll ? const Color(0xFF0F172A) : const Color(0xFF1D4ED8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Segmented Tabs OR Active Search Input Bar
          SizedBox(
            height: 38,
            child: _isSearchOpen ? _buildSearchInputRow() : _buildTabsWithSearchButtonRow(),
          ),

          const SizedBox(height: 5),

          // Row 2: Unified 1-Row Filter Bar (Outlets Dropdown + Status Dropdown + Chips)
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                if (widget.outlets.isNotEmpty) ...[
                  _buildOutletDropdownPill(context),
                  Container(
                    height: 18,
                    width: 1,
                    margin: const EdgeInsets.only(right: 6, top: 7, bottom: 7),
                    color: AppDesignSystem.slate300,
                  ),
                ],
                _buildStatusDropdownPill(context),
                Container(
                  height: 18,
                  width: 1,
                  margin: const EdgeInsets.only(right: 6, top: 7, bottom: 7),
                  color: AppDesignSystem.slate300,
                ),
                ...activeFilters.map((status) {
                  final isSelected = widget.currentSubFilter == status;
                  final isNeedsApproval = status == 'ADMIN_PENDING';
                  final approvalCount = widget.statusCounts['ADMIN_PENDING'] ?? 0;

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
                                  : (isNeedsApproval && approvalCount > 0
                                      ? const Color(0xFFB45309)
                                      : AppDesignSystem.slate600)),
                        ),
                      ),
                      selectedColor: status == 'PAYMENT_PENDING'
                          ? const Color(0xFFE11D48)
                          : (isNeedsApproval && approvalCount > 0
                              ? const Color(0xFFD97706)
                              : AppDesignSystem.slate900),
                      backgroundColor: status == 'PAYMENT_PENDING' && widget.displayPendingPaymentCount > 0
                          ? const Color(0xFFFFF1F2)
                          : (isNeedsApproval && approvalCount > 0
                              ? const Color(0xFFFFFBEB)
                              : AppDesignSystem.slate100),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? (status == 'PAYMENT_PENDING'
                                  ? const Color(0xFFE11D48)
                                  : (isNeedsApproval && approvalCount > 0
                                      ? const Color(0xFFD97706)
                                      : AppDesignSystem.slate900))
                              : (status == 'PAYMENT_PENDING' && widget.displayPendingPaymentCount > 0
                                  ? const Color(0xFFFDA4AF)
                                  : (isNeedsApproval && approvalCount > 0
                                      ? const Color(0xFFFDE68A)
                                      : AppDesignSystem.slate200)),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }),
              ],
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
