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

  final List<Map<String, String>> _cancelReasonItems = [
    {
      'title': 'Placed order by mistake',
      'emoji': '⚡',
      'subtitle': 'Accidental checkout or timing issue',
    },
    {
      'title': 'Selected wrong delivery address',
      'emoji': '📍',
      'subtitle': 'Need to send to a different location',
    },
    {
      'title': 'Forgot to add some items',
      'emoji': '🛍️',
      'subtitle': 'Want to add more grocery items to cart',
    },
    {
      'title': 'Delay in store verification',
      'emoji': '⏱️',
      'subtitle': 'Order taking longer than estimated',
    },
    {
      'title': 'Change of mind / Not needed now',
      'emoji': '💭',
      'subtitle': 'Decided to purchase at another time',
    },
  ];

  static const Color primaryRed = Color(0xFFE11D48);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
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
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Luxury Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFE4E6), Color(0xFFFEE2E2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFECDD3),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.cancel_rounded, color: primaryRed, size: 22),
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
                            fontSize: Responsive.scaledFontSize(context, 15),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 1.5),
                        Text(
                          'Select reason to help us improve service',
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
                    icon: const Icon(Icons.close_rounded, color: slateMuted, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // High-End Reason Options List
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: _cancelReasonItems.map((item) {
                  final title = item['title']!;
                  final emoji = item['emoji']!;
                  final subtitle = item['subtitle']!;
                  final isSelected = _selectedReason == title;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedReason = title);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFF5F6) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF43F5E) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1.1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          else
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left Accent Pill when selected
                          if (isSelected)
                            Container(
                              width: 3.5,
                              height: 32,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: primaryRed,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                          // Emoji Icon Box
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFE4E6) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Title & Micro Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF9F1239) : slateDark,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? const Color(0xFFE11D48).withValues(alpha: 0.8) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right Selection Radio Indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? primaryRed : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? primaryRed : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.5 : 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primaryRed.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
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

            // Trust Refund Notice Banner (If paid online)
            if (widget.isPaid)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Refund Guarantee',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF166534),
                              ),
                            ),
                            Text(
                              '₹${widget.totalAmount.toStringAsFixed(0)} will be refunded back to your original payment method in 2-4 business days.',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF15803D),
                                height: 1.25,
                              ),
                            ),
                          ],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swipe_right_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Text(
                        'SWIPE RED TOGGLE TO CONFIRM',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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

/// Draggable Luxury Red Slider Toggle ("SLIDE TO CANCEL »»")
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

  static const double _thumbWidth = 50.0;
  static const double _trackHeight = 54.0;

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
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(
              color: const Color(0xFFFECDD3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Dynamic Vivid Red Track Fill with Gradient
              AnimatedContainer(
                duration: _springController.isAnimating
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                width: _thumbWidth + _dragPosition + 3,
                height: _trackHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),

              // Track Text Label (Fades smoothly as thumb moves)
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: (1.0 - (progress * 1.6)).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SLIDE TO CANCEL',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFBE123C),
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          size: 18,
                          color: Color(0xFFBE123C),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Draggable Red Thumb Knob with 3D Border & Shadow
              Positioned(
                left: 3 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onHorizontalDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) =>
                      _onHorizontalDragEnd(details, maxDrag),
                  child: Container(
                    width: _thumbWidth - 4,
                    height: _trackHeight - 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBE123C).withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                                size: 24,
                              )
                            : const Icon(
                                Icons.keyboard_double_arrow_right_rounded,
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
