import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Full-Screen Ultra-Smooth Zepto & Blinkit Style Order Placement Overlay
class CheckoutPlacingOrderOverlay extends StatefulWidget {
  const CheckoutPlacingOrderOverlay({super.key});

  @override
  State<CheckoutPlacingOrderOverlay> createState() => _CheckoutPlacingOrderOverlayState();
}

class _CheckoutPlacingOrderOverlayState extends State<CheckoutPlacingOrderOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _bounceAnimation;

  int _currentStep = 0;

  static const List<Map<String, dynamic>> _steps = [
    {
      'title': 'Locking Fresh Items',
      'subtitle': 'Reserved from nearest express hub',
      'icon': Icons.inventory_2_rounded,
    },
    {
      'title': 'Calculating Fastest Route',
      'subtitle': 'Zero-traffic delivery path mapped',
      'icon': Icons.navigation_rounded,
    },
    {
      'title': 'Assigning Express Rider',
      'subtitle': 'Partner preparing for pickup',
      'icon': Icons.two_wheeler_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Radar pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );

    // Vehicle gentle road vibration bounce
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Progress bar fill animation
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    _progressAnimation = Tween<double>(begin: 0.15, end: 0.92).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOutCubic),
    );

    // Step switching timer
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _currentStep = 1);
    });
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _currentStep = 2);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Express Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '⚡ FASTKIRANA EXPRESS • 10-15 MINS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF047857),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Animated Radar + Road Bounce Scooter Hero
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Sonar Pulse Ring
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final val = _pulseAnimation.value;
                        final alpha = (1.5 - val).clamp(0.0, 0.6);
                        return Transform.scale(
                          scale: val,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE20A22).withValues(alpha: alpha),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Scooter Vehicle Capsule with road physics
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _bounceAnimation.value),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE20A22), Color(0xFFBE123C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.two_wheeler_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Creating Your Order',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Securing freshest stock & packing items',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),

              // Smooth Glowing Progress Bar
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE20A22), Color(0xFFF59E0B), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE20A22).withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Live Micro-Milestones Checklist
              Column(
                children: List.generate(_steps.length, (idx) {
                  final step = _steps[idx];
                  final isDone = idx < _currentStep;
                  final isCurrent = idx == _currentStep;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFFEF2F2)
                          : isDone
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFFECACA)
                            : isDone
                                ? const Color(0xFFBBF7D0)
                                : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : isCurrent
                                    ? const Color(0xFFE20A22)
                                    : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isDone ? Icons.check_rounded : step['icon'] as IconData,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isCurrent
                                      ? const Color(0xFF991B1B)
                                      : isDone
                                          ? const Color(0xFF166534)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                step['subtitle'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFE20A22),
                            ),
                          )
                        else if (isDone)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
