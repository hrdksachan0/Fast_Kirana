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
  static const Color slateLight = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
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
            'Failed to send OTP. Please try again.';
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error. Check your connection.');
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
      backgroundColor: const Color(0xFFFAFAFC),
      body: Stack(
        children: [
          // 1. Ambient Background Glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            height: 380,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 0.9,
                  colors: [
                    Color(0xFFFFE4E6),
                    Color(0xFFFFF1F2),
                    Color(0xFFFAFAFC),
                  ],
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: Responsive.formMaxContentWidth,
              fillHeight: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),

                            // Top Navigation: Skip Pill
                            Align(
                              alignment: Alignment.centerRight,
                              child: Bounceable(
                                onTap: _handleSkipGuest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
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
                                        size: 10.5,
                                        color: slateMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(duration: 350.ms),

                            const SizedBox(height: 16),

                            // Brand Hero: Logo & Title
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryRed.withOpacity(0.18),
                                          blurRadius: 28,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const FastKiranaLogoWidget(size: 76),
                                  )
                                      .animate()
                                      .fadeIn(duration: 400.ms)
                                      .scale(
                                        begin: const Offset(0.85, 0.85),
                                        end: const Offset(1.0, 1.0),
                                        curve: Curves.easeOutBack,
                                        duration: 450.ms,
                                      ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'FastKirana Express',
                                    style: GoogleFonts.inter(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                      letterSpacing: -0.6,
                                    ),
                                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFE4E6)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('⚡', style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Ghatampur\'s Fast Grocery & Food App',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFBE123C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Elevated Modern Form Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.05),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.015),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Form Title & Subtitle
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF1F2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.phone_android_rounded,
                                          size: 16,
                                          color: primaryRed,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Login or Register',
                                        style: GoogleFonts.inter(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          color: slateDark,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 30),
                                    child: Text(
                                      'We will send a 6-digit OTP to verify',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: slateMuted,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Error Banner
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      margin: const EdgeInsets.only(bottom: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(12),
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

                                  // Unified Modern Phone Input Box
                                  Container(
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _errorMessage != null
                                            ? primaryRed
                                            : (_isFocused ? primaryRed : const Color(0xFFE2E8F0)),
                                        width: _isFocused ? 1.5 : 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Country Flag + Code
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🇮🇳', style: TextStyle(fontSize: 17)),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+91',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: slateDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Subtle Vertical Divider
                                        Container(
                                          height: 24,
                                          width: 1.2,
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                        const SizedBox(width: 12),

                                        // Mobile Number Input Field
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
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                              color: slateDark,
                                              letterSpacing: 1.2,
                                            ),
                                            decoration: InputDecoration(
                                              counterText: '',
                                              hintText: 'Enter Mobile Number',
                                              hintStyle: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                color: slateLight,
                                                letterSpacing: 0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onSubmitted: (_) => _handleContinue(),
                                          ),
                                        ),

                                        // Suffix Icon: Live Checkmark or Clear
                                        if (isValidPhone)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: Icon(
                                              Icons.check_circle_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 20,
                                            ),
                                          )
                                        else if (_phoneController.text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: GestureDetector(
                                              onTap: () {
                                                _phoneController.clear();
                                                setState(() {});
                                              },
                                              child: const Icon(
                                                Icons.cancel_rounded,
                                                color: Color(0xFFCBD5E1),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 18),

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
                                            color: primaryRed.withOpacity(0.32),
                                            blurRadius: 14,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.4,
                                                  color: Colors.white,
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

                                  const SizedBox(height: 16),

                                  // Terms Note
                                  Center(
                                    child: Text(
                                      'By continuing, you agree to our Terms & Privacy Policy',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: slateLight,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(
                                  begin: 0.05,
                                  end: 0,
                                  duration: 400.ms,
                                  delay: 200.ms,
                                  curve: Curves.easeOutCubic,
                                ),

                            const Spacer(),

                            // 4. Bottom Pinned Trust Badges
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTrustBadge('🔒 100% Safe & Secure'),
                                  const SizedBox(width: 8),
                                  _buildTrustBadge('⚡ Instant Ghatampur Express'),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: slateMuted,
        ),
      ),
    );
  }
}