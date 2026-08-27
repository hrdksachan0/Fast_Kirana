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
      backgroundColor: const Color(0xFFFAF9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ResponsiveContainer(
            maxWidth: Responsive.formMaxContentWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Top Bar: Skip to Browse Button on Top Right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Bounceable(
                      onTap: _handleSkipGuest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
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
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Center Hero: FastKirana Brand Logo with Red Glow
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryRed.withValues(alpha: 0.12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryRed.withValues(alpha: 0.25),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const BrandLogo(size: 72),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Brand Title
                  Center(
                    child: Text(
                      'FastKirana',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle Pill Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                            "Superfast Grocery & Food Delivery",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // White Card Container with Input & Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Header Row: Enter Mobile Number & OTP Verification status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Enter Mobile Number',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
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

                        // Single Seamless Luxury Input Card (No ugly inner nested borders)
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: _isFocused ? Colors.white : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isFocused
                                  ? primaryRed
                                  : (isValidPhone ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                              width: _isFocused ? 1.8 : 1.2,
                            ),
                            boxShadow: [
                              if (_isFocused)
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Clean Country Code Badge
                              Padding(
                                padding: const EdgeInsets.only(left: 14, right: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+91',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Subtle Vertical Divider
                              Container(
                                width: 1,
                                height: 22,
                                color: const Color(0xFFE2E8F0),
                              ),

                              // Pure Seamless Text Input Area
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.phone,
                                  cursorColor: primaryRed,
                                  cursorWidth: 2,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: 0.8,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter 10-digit number',
                                    hintStyle: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
                                      letterSpacing: 0.2,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  ),
                                  onSubmitted: (_) => _handleContinue(),
                                ),
                              ),

                              // Animated Valid Green Checkmark Badge
                              if (isValidPhone)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF16A34A),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ).animate().scale(duration: 200.ms),
                            ],
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: primaryRed,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Big Red Continue Button
                        Bounceable(
                          onTap: _isLoading ? null : _handleContinue,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Continue with OTP',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Terms & Privacy Note
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}