import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';
import '../core/services/logger_service.dart';

/// Premium bottom-sheet for pausing / closing a store hub or restaurant outlet.
///
/// Matches the web "Manage Serviceability" dialog with proper design tokens,
/// 2-column reason grid, timed pause durations, and audited reason selection.
class StoreServiceabilitySheet extends StatefulWidget {
  final String targetType; // 'HUB' | 'RESTAURANT'
  final String targetId;
  final String storeName;
  final bool currentIsOpen;
  final String? pauseUntil;
  final String? closeReason;
  final Dio dio;
  final Function(bool isOpen, String? pauseUntil)? onStatusChanged;

  const StoreServiceabilitySheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.storeName,
    required this.currentIsOpen,
    this.pauseUntil,
    this.closeReason,
    required this.dio,
    this.onStatusChanged,
  });

  /// Convenience factory — opens the sheet as a modal bottom-sheet.
  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String storeName,
    required bool currentIsOpen,
    String? pauseUntil,
    String? closeReason,
    required Dio dio,
    Function(bool isOpen, String? pauseUntil)? onStatusChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreServiceabilitySheet(
        targetType: targetType,
        targetId: targetId,
        storeName: storeName,
        currentIsOpen: currentIsOpen,
        pauseUntil: pauseUntil,
        closeReason: closeReason,
        dio: dio,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  State<StoreServiceabilitySheet> createState() =>
      _StoreServiceabilitySheetState();
}

class _StoreServiceabilitySheetState extends State<StoreServiceabilitySheet> {
  int _selectedDuration = 30; // 15, 30, 60, -1 (Full Day)
  String _selectedReason = 'HIGH_ORDER_SURGE';
  final TextEditingController _customReasonCtrl = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _reasons = [
    {
      'id': 'HIGH_ORDER_SURGE',
      'label': 'High Order Rush / Surge',
      'icon': Icons.local_fire_department_rounded,
    },
    {
      'id': 'HEAVY_RAIN',
      'label': 'Heavy Rain / Bad Weather',
      'icon': Icons.thunderstorm_rounded,
    },
    {
      'id': 'RIDER_SHORTAGE',
      'label': 'Delivery Riders Unavailable',
      'icon': Icons.two_wheeler_rounded,
    },
    {
      'id': 'STOCK_AUDIT',
      'label': 'Stock Counting & Inward',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'id': 'TECHNICAL_MAINTENANCE',
      'label': 'Power Cut / System Maint.',
      'icon': Icons.build_rounded,
    },
    {
      'id': 'OTHER',
      'label': 'Other Operational Reason',
      'icon': Icons.help_outline_rounded,
    },
  ];

  String get _pauseLabel {
    if (_isLoading) return 'Updating...';
    if (_selectedDuration == -1) return 'CLOSE STORE TODAY';
    return 'PAUSE STORE (${_selectedDuration}M)';
  }

  // ───────────────────────── API ─────────────────────────

  Future<void> _submitToggle(String action) async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.dio.post(
        '/api/admin/serviceability/toggle',
        data: {
          'targetType': widget.targetType,
          'targetId': widget.targetId,
          'action': action,
          'pauseMinutes': action == 'PAUSE' ? _selectedDuration : null,
          'reason': _selectedReason,
          'customReasonText':
              _selectedReason == 'OTHER' ? _customReasonCtrl.text.trim() : null,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final bool newOpen = data['status'] == 'ONLINE';
        final String? newPause = data['pauseUntil']?.toString();

        if (mounted) {
          Navigator.of(context).pop();
          widget.onStatusChanged?.call(newOpen, newPause);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Store status updated successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor:
                  newOpen ? AppDesignSystem.success : AppDesignSystem.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      LoggerService.error('StoreServiceabilitySheet: toggle failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppDesignSystem.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppDesignSystem.darkSurface : Colors.white;
    final textPrimary =
        isDark ? AppDesignSystem.darkTextPrimary : AppDesignSystem.slate900;
    final textSecondary =
        isDark ? AppDesignSystem.darkTextSecondary : AppDesignSystem.slate500;
    final surfaceMuted =
        isDark ? AppDesignSystem.darkSurfaceMuted : AppDesignSystem.slate50;
    final borderClr =
        isDark ? AppDesignSystem.darkBorder : AppDesignSystem.border;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppDesignSystem.shadowXl,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppDesignSystem.slate600
                      : AppDesignSystem.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppDesignSystem.amber700.withValues(alpha: 0.15)
                        : AppDesignSystem.amber50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppDesignSystem.amber600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Serviceability',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.storeName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppDesignSystem.slate400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Subtitle ──
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Text(
                'Select a pause timer or reason to temporarily halt incoming customer orders.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppDesignSystem.slate400,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Divider(height: 1, color: borderClr),
            const SizedBox(height: 20),

            // ── Section 1: Pause Duration ──
            _buildSectionHeader(Icons.timer_outlined, 'CHOOSE PAUSE DURATION'),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDurationChip(
                    15, '15 Mins', 'Quick rush', isDark, textPrimary,
                    surfaceMuted, borderClr),
                const SizedBox(width: 8),
                _buildDurationChip(
                    30, '30 Mins', 'Restocking', isDark, textPrimary,
                    surfaceMuted, borderClr),
                const SizedBox(width: 8),
                _buildDurationChip(
                    60, '1 Hour', 'Shift break', isDark, textPrimary,
                    surfaceMuted, borderClr),
                const SizedBox(width: 8),
                _buildDurationChip(
                    -1, 'Full Day', 'Manual open', isDark, textPrimary,
                    surfaceMuted, borderClr),
              ],
            ),
            const SizedBox(height: 24),

            // ── Section 2: Audit Reason ──
            _buildSectionHeader(
                Icons.checklist_rounded, 'SELECT REASON (AUDITED)'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final chipWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reasons
                      .map((r) => SizedBox(
                            width: chipWidth,
                            child: _buildReasonChip(
                                r, isDark, textPrimary, surfaceMuted, borderClr),
                          ))
                      .toList(),
                );
              },
            ),

            // ── Custom Reason Field (animated) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _selectedReason == 'OTHER'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _customReasonCtrl,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type specific operational reason...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 12, color: AppDesignSystem.slate400),
                          filled: true,
                          fillColor: surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderClr),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderClr),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppDesignSystem.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 28),

            // ── Action Buttons ──
            Row(
              children: [
                // Cancel
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderClr),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Pause / Close
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              _submitToggle(
                                _selectedDuration == -1
                                    ? 'CLOSE_TODAY'
                                    : 'PAUSE',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.danger,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppDesignSystem.danger.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.power_settings_new, size: 18),
                      label: Text(
                        _pauseLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── SECTION HEADER ─────────────────────────

  Widget _buildSectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppDesignSystem.slate400),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: AppDesignSystem.slate400,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── DURATION CHIP ─────────────────────────

  Widget _buildDurationChip(
    int value,
    String label,
    String sub,
    bool isDark,
    Color textPrimary,
    Color surfaceMuted,
    Color borderClr,
  ) {
    final isSelected = _selectedDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedDuration = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppDesignSystem.primary.withValues(alpha: 0.08)
                : surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppDesignSystem.primary : borderClr,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppDesignSystem.primary : textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: AppDesignSystem.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── REASON CHIP ─────────────────────────

  Widget _buildReasonChip(
    Map<String, dynamic> reason,
    bool isDark,
    Color textPrimary,
    Color surfaceMuted,
    Color borderClr,
  ) {
    final String id = reason['id'] as String;
    final String label = reason['label'] as String;
    final IconData icon = reason['icon'] as IconData;
    final isSelected = _selectedReason == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedReason = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignSystem.primary.withValues(alpha: 0.08)
              : surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppDesignSystem.primary : borderClr,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppDesignSystem.primary
                  : AppDesignSystem.slate400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppDesignSystem.primary
                      : isDark
                          ? AppDesignSystem.darkTextPrimary
                          : AppDesignSystem.slate700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.check_circle, size: 14,
                    color: AppDesignSystem.primary),
              ),
          ],
        ),
      ),
    );
  }
}
