import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/utils/restaurant_utils.dart';

/// Restaurant store settings tab (open/closed status, operating hours, kitchen high rush mode)
class RestaurantSettingsTab extends StatefulWidget {
  final bool isStoreOpen;
  final bool isBusyMode;
  final String openTime;
  final String closeTime;
  final ValueChanged<bool> onToggleStoreOpen;
  final ValueChanged<bool> onToggleBusyMode;
  final void Function(String openTime, String closeTime) onUpdateTimings;

  const RestaurantSettingsTab({
    super.key,
    required this.isStoreOpen,
    required this.isBusyMode,
    this.openTime = '10:00',
    this.closeTime = '23:00',
    required this.onToggleStoreOpen,
    required this.onToggleBusyMode,
    required this.onUpdateTimings,
  });

  @override
  State<RestaurantSettingsTab> createState() => _RestaurantSettingsTabState();
}

class _RestaurantSettingsTabState extends State<RestaurantSettingsTab> {
  late String _currentOpen;
  late String _currentClose;

  @override
  void initState() {
    super.initState();
    _currentOpen = widget.openTime;
    _currentClose = widget.closeTime;
  }

  @override
  void didUpdateWidget(covariant RestaurantSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openTime != widget.openTime || oldWidget.closeTime != widget.closeTime) {
      _currentOpen = widget.openTime;
      _currentClose = widget.closeTime;
    }
  }

  Future<void> _pickTime({required bool isOpenTime}) async {
    final initialStr = isOpenTime ? _currentOpen : _currentClose;
    final parts = initialStr.split(':');
    final initialH = int.tryParse(parts.first) ?? (isOpenTime ? 10 : 23);
    final initialM = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialH, minute: initialM),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppDesignSystem.primary,
              onPrimary: Colors.white,
              onSurface: AppDesignSystem.slate900,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isOpenTime) {
          _currentOpen = formatted;
        } else {
          _currentClose = formatted;
        }
      });
      HapticFeedback.mediumImpact();
      widget.onUpdateTimings(_currentOpen, _currentClose);
    }
  }

  void _applyPreset(String open, String close) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentOpen = open;
      _currentClose = close;
    });
    widget.onUpdateTimings(open, close);
  }

  @override
  Widget build(BuildContext context) {
    final openMin = RestaurantScheduleHelper.parseTimeStringToMinutes(_currentOpen) ?? 600;
    final closeMin = RestaurantScheduleHelper.parseTimeStringToMinutes(_currentClose) ?? 1380;
    final open12h = RestaurantScheduleHelper.formatMinutesTo12h(openMin);
    final close12h = RestaurantScheduleHelper.formatMinutesTo12h(closeMin);
    final isWithinHours = RestaurantScheduleHelper.isWithinOperatingHours(openTime: _currentOpen, closeTime: _currentClose);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── 1. Instant Operational Status Toggle ──────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignSystem.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(
                  'Kitchen Live Online Status',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                subtitle: Text(
                  widget.isStoreOpen
                      ? 'Accepting incoming online customer food orders'
                      : 'Closed / Paused temporarily for online orders',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: AppDesignSystem.slate500,
                  ),
                ),
                value: widget.isStoreOpen,
                activeTrackColor: AppDesignSystem.success,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  widget.onToggleStoreOpen(val);
                },
              ),
              const Divider(height: 1, color: AppDesignSystem.slate100),
              SwitchListTile.adaptive(
                title: Text(
                  'Kitchen Busy / High Rush Mode',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                  ),
                ),
                subtitle: Text(
                  'Displays "High Demand Rush" badge to customers on menu',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: AppDesignSystem.slate500,
                  ),
                ),
                value: widget.isBusyMode,
                activeTrackColor: AppDesignSystem.warning,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  widget.onToggleBusyMode(val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ─── 2. Restaurant Operating Timings Card ─────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDesignSystem.slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.orange50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 20, color: AppDesignSystem.orange600),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operating Hours & Schedule',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        Text(
                          isWithinHours ? 'Currently within active operating hours 🟢' : 'Currently outside operating hours 🌙',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            color: isWithinHours ? AppDesignSystem.emerald600 : AppDesignSystem.amber700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Time Selectors Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isOpenTime: true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OPENS AT',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.wb_sunny_outlined, size: 16, color: AppDesignSystem.amber600),
                                const SizedBox(width: 6),
                                Text(
                                  open12h,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 15),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickTime(isOpenTime: false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CLOSES AT',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.slate500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.nightlight_outlined, size: 16, color: AppDesignSystem.indigo600),
                                const SizedBox(width: 6),
                                Text(
                                  close12h,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 15),
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Quick Presets
              Text(
                'QUICK TIMING PRESETS',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip('☀️ 10 AM - 10 PM', '10:00', '22:00'),
                  _buildPresetChip('🌙 10 AM - 11:30 PM', '10:00', '23:30'),
                  _buildPresetChip('🦉 11 AM - 12:00 Midnight', '11:00', '23:59'),
                  _buildPresetChip('⚡ 24 Hours Open', '00:00', '23:59', isHighlight: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, String open, String close, {bool isHighlight = false}) {
    final isSelected = _currentOpen == open && _currentClose == close;
    return GestureDetector(
      onTap: () => _applyPreset(open, close),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHighlight ? AppDesignSystem.emerald600 : AppDesignSystem.primary)
              : (isHighlight ? const Color(0xFFECFDF5) : AppDesignSystem.slate100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isHighlight ? const Color(0xFFA7F3D0) : AppDesignSystem.slate200),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11),
            fontWeight: FontWeight.w800,
            color: isSelected
                ? Colors.white
                : (isHighlight ? const Color(0xFF065F46) : AppDesignSystem.slate800),
          ),
        ),
      ),
    );
  }
}

