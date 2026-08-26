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
  bool _isLoading = false;
  String? _errorMessage;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _phoneController.dispose();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background soft ambient red glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 320,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFECEE),
                    Color(0xFFFFF8F8),
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: ResponsiveContainer(
              maxWidth: Responsive.formMaxContentWidth,
              fillHeight: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Skip to Browse
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleSkipGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: slateMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Skip to Browse',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 11),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Brand Hero Header with Signature FastKirana 'F' Logo
                  Center(
                    child: Column(
                      children: [
                        const FastKiranaLogoWidget(size: 80)
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 100.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack, duration: 500.ms, delay: 100.ms),
                        const SizedBox(height: 18),
                        Text(
                          'FastKirana Express',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 250.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 6),
                        Text(
                          'Ghatampur\'s Fast Grocery & Food App',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: slateMuted,
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 400.ms, curve: Curves.easeOutCubic),
                      ],
                    ),
                  ),

                  const SizedBox(height: 38),

                  // Section Title
                  Text(
                    'Login with Mobile Number',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We will send a 6-digit OTP to verify your number',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: slateMuted,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: primaryRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(fontSize: 12, color: primaryRed, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // WhatsApp / Mobile Phone Input Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _errorMessage != null ? primaryRed : const Color(0xFFE2E8F0),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                '+91',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            autofocus: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark, letterSpacing: 1.5),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter Mobile Number',
                              hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8), letterSpacing: 0, fontWeight: FontWeight.w500),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _handleContinue(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main Continue Button
                  Bounceable(
                    onTap: _isLoading ? () {} : _handleContinue,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE20A22), Color(0xFFFF2D4B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Terms & Privacy Note
                  Text(
                    'By continuing, you agree to FastKirana\'s Terms of Service & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Trust Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTrustBadge('🔒 100% Safe & Secure'),
                      const SizedBox(width: 8),
                      _buildTrustBadge('⚡ Instant Ghatampur Express'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildTrustBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: slateMuted),
      ),
    );
  }
}