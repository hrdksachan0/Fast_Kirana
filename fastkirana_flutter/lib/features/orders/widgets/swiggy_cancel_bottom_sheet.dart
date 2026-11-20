import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';

class SwiggyCancelBottomSheet extends StatefulWidget {
  final String displayId;
  final bool isPaid;
  final double totalAmount;

  const SwiggyCancelBottomSheet({
    super.key,
    required this.displayId,
    required this.isPaid,
    required this.totalAmount,
  });

  static Future<String?> show({
    required BuildContext context,
    required String displayId,
    required bool isPaid,
    required double totalAmount,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SwiggyCancelBottomSheet(
        displayId: displayId,
        isPaid: isPaid,
        totalAmount: totalAmount,
      ),
    );
  }

  @override
  State<SwiggyCancelBottomSheet> createState() => _SwiggyCancelBottomSheetState();
}

class _SwiggyCancelBottomSheetState extends State<SwiggyCancelBottomSheet> {
  String _selectedReason = 'Placed order by mistake';
  bool _isCancelled = false;

  final List<String> _cancelReasons = [
    'Placed order by mistake',
    'Selected wrong delivery address',
    'Forgot to add some items',
    'Delay in store verification',
    'Change of mind / Not needed now',
  ];

  static const Color primaryRed = Color(0xFFDC2626);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Center(
                      child: Icon(Icons.cancel_outlined, color: primaryRed, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancel Order ${widget.displayId}',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14.5),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Select reason to help us improve',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w500,
                            color: slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: slateMuted, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Reason Options List
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: _cancelReasons.map((reason) {
                  final isSelected = _selectedReason == reason;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedReason = reason);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF991B1B) : slateDark,
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? primaryRed : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? primaryRed : const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(Icons.check, size: 12, color: Colors.white),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Refund Notice Banner (If paid online)
            if (widget.isPaid)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '₹${widget.totalAmount.toStringAsFixed(0)} will be refunded back to your original payment method in 2-4 business days.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10.5),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF166534),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── SWIGGY RED SLIDE TO CANCEL TOGGLE ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SWIPE RED TOGGLE TO CONFIRM',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9.5),
                      fontWeight: FontWeight.w900,
                      color: slateMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwiggySlideToCancel(
                    onCancelled: () {
                      if (!_isCancelled) {
                        _isCancelled = true;
                        Navigator.pop(context, _selectedReason);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draggable Red Slider Toggle ("Slide to Cancel >>>")
class SwiggySlideToCancel extends StatefulWidget {
  final VoidCallback onCancelled;

  const SwiggySlideToCancel({super.key, required this.onCancelled});

  @override
  State<SwiggySlideToCancel> createState() => _SwiggySlideToCancelState();
}

class _SwiggySlideToCancelState extends State<SwiggySlideToCancel>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isSuccess = false;

  late AnimationController _springController;
  late Animation<double> _springAnimation;

  static const double _thumbWidth = 48.0;
  static const double _trackHeight = 52.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _springAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    )..addListener(() {
        setState(() {
          _dragPosition = _springAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isSuccess) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });

    if (_dragPosition >= maxDrag * 0.90 && !_isSuccess) {
      _triggerSuccess(maxDrag);
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) {
    if (_isSuccess) return;
    if (_dragPosition < maxDrag * 0.90) {
      // Spring back
      _springAnimation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
      );
      _springController.forward(from: 0.0);
    }
  }

  void _triggerSuccess(double maxDrag) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSuccess = true;
      _dragPosition = maxDrag;
    });

    Future.delayed(const Duration(milliseconds: 320), () {
      widget.onCancelled();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDrag = (totalWidth - _thumbWidth - 6).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: _trackHeight,
          width: totalWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(
              color: const Color(0xFFFECACA),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Dynamic Vivid Red Track Fill
              AnimatedContainer(
                duration: _springController.isAnimating
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                width: _thumbWidth + _dragPosition + 3,
                height: _trackHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),

              // Track Text Label (Fades as thumb moves)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SLIDE TO CANCEL',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFB91C1C),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFFB91C1C),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFFB91C1C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Draggable Red Thumb Knob
              Positioned(
                left: 3 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onHorizontalDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) =>
                      _onHorizontalDragEnd(details, maxDrag),
                  child: Container(
                    width: _thumbWidth - 4,
                    height: _trackHeight - 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDC2626),
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isSuccess
                            ? const Icon(
                                Icons.check_rounded,
                                key: ValueKey('check'),
                                color: Colors.white,
                                size: 22,
                              )
                            : const Icon(
                                Icons.chevron_right_rounded,
                                key: ValueKey('arrow'),
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
