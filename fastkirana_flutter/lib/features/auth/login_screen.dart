import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/theme/responsive.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/brand_logo.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFocused = false;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color primaryRedLight = Color(0xFFFF2D4B);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();

    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });

    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_phone');
    if (saved != null && saved.isNotEmpty && mounted) {
      final clean = saved.replaceAll('+91', '').replaceAll(' ', '').trim();
      if (clean.length == 10) {
        setState(() {
          _phoneController.text = clean;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      await authRepo.sendOtp(phone);

      if (!mounted) return;
      Navigator.push(
        context,
        FadeSlideRoute(page: OtpScreen(identifier: phone)),
      );
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ??
            e.response?.data?['message'] ??
            'Failed to send OTP. Please check connection.';
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSkipGuest() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_chosen_location', true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isValidPhone = _phoneController.text.trim().length == 10;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Top Ambient Gradient Glow
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 380,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFECEF),
                      Color(0xFFFFF7F8),
                      Color(0xFFFAFAFA),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: ResponsiveContainer(
                maxWidth: Responsive.formMaxContentWidth,
                fillHeight: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),

                      // Top Navigation: Skip Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: Bounceable(
                          onTap: _handleSkipGuest,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: slateBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Skip to Browse',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: slateDark,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: slateMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms),

                      const Spacer(flex: 1),

                      // 🔴 Brand Hero Logo & Typography
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryRed.withValues(alpha: 0.20),
                                    blurRadius: 35,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const FastKiranaLogoWidget(size: 84),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .scale(begin: const Offset(0.88, 0.88), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 450.ms),
                            const SizedBox(height: 16),
                            Text(
                              'FastKirana',
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: slateDark,
                                letterSpacing: -0.8,
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFE4E6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('⚡', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Ghatampur\'s Fast Grocery & Food Delivery',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFBE123C),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                          ],
                        ),
                      ),

                      const Spacer(flex: 1),

                      // 📱 Ultra-Clean Modern Phone Input Card (Zepto / Blinkit Style)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enter Mobile Number',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'OTP Verification',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Error Message Banner
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: primaryRed, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: primaryRed,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Single Unified Input Box
                            Container(
                              height: 56,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isFocused ? primaryRed : const Color(0xFFE2E8F0),
                                  width: _isFocused ? 1.6 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Country Code & Flag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🇮🇳', style: TextStyle(fontSize: 17)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+91',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Phone Text Input
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      autofocus: true,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: slateDark,
                                        letterSpacing: 1.5,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: 'Enter 10-digit number',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          color: const Color(0xFF94A3B8),
                                          letterSpacing: 0.2,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onSubmitted: (_) => _handleContinue(),
                                    ),
                                  ),

                                  // Checkmark / Clear Suffix
                                  if (isValidPhone)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 22,
                                    )
                                  else if (_phoneController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _phoneController.clear();
                                        setState(() {});
                                      },
                                      child: const Icon(
                                        Icons.cancel_rounded,
                                        color: Color(0xFFCBD5E1),
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Main CTA Button
                            Bounceable(
                              onTap: _isLoading ? () {} : _handleContinue,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [primaryRed, primaryRedLight],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryRed.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Continue with OTP',
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic, duration: 400.ms),

                      const Spacer(flex: 1),

                      // 🔒 Security & Privacy Footer
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
                    ],
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