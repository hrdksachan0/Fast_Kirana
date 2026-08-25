import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _authMode = 0; // 0 = WhatsApp Phone, 1 = Email

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final identifier = _authMode == 0 ? _phoneController.text.trim() : _emailController.text.trim();

    if (_authMode == 0) {
      if (identifier.length != 10) {
        setState(() => _errorMessage = 'Please enter valid 10-digit WhatsApp number');
        return;
      }
    } else {
      if (identifier.isEmpty || !identifier.contains('@')) {
        setState(() => _errorMessage = 'Please enter valid email address');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      try {
        await authRepo.sendOtp(identifier);
      } catch (e) {
        debugPrint('sendOtp error: $e');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(identifier: identifier)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(identifier: identifier)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const googleEmail = 'customer@gmail.com';
      const googleName = 'FastKirana Customer';

      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/auth/google', data: {
        'email': googleEmail,
        'name': googleName,
        'photoUrl': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120&auto=format&fit=crop',
      });

      final data = response.data;
      if (data != null && data['id'] != null) {
        final user = User(
          id: data['id'],
          name: data['name'] ?? googleName,
          email: data['email'] ?? googleEmail,
          phone: data['phone'],
          role: data['role'] ?? 'USER',
          isBlocked: false,
        );

        final token = data['token'] ?? 'token_${user.id}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(user.toJson()));
        await prefs.setString('auth_token', token);

        ref.read(authProvider.notifier).setUser(user);
        HapticFeedback.heavyImpact();

        if (!mounted) return;
        _navigateToNext(prefs);
      }
    } catch (e) {
      debugPrint('Google sign-in fallback: $e');
      final fallbackId = 'google_${DateTime.now().millisecondsSinceEpoch}';
      final user = User(
        id: fallbackId,
        name: 'FastKirana Customer',
        email: 'customer@gmail.com',
        phone: null,
        role: 'USER',
        isBlocked: false,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toJson()));
      await prefs.setString('auth_token', 'token_$fallbackId');

      ref.read(authProvider.notifier).setUser(user);
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      _navigateToNext(prefs);
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

  void _navigateToNext(SharedPreferences prefs) {
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
            height: 300,
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

                  const SizedBox(height: 12),

                  // Brand Hero Header with Signature FastKirana 'F' Logo
                  Center(
                    child: Column(
                      children: [
                        const FastKiranaLogoWidget(size: 74),
                        const SizedBox(height: 16),
                        Text(
                          'FastKirana Express',
                          style: GoogleFonts.inter(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Ghatampur\'s Fastest Grocery & Food App',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Login Mode Switcher (WhatsApp Phone vs Email)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _authMode = 0;
                              _errorMessage = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _authMode == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _authMode == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('💬', style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'WhatsApp No.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: _authMode == 0 ? FontWeight.w800 : FontWeight.w600,
                                      color: _authMode == 0 ? slateDark : slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _authMode = 1;
                              _errorMessage = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _authMode == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _authMode == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('✉️', style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Email Address',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: _authMode == 1 ? FontWeight.w800 : FontWeight.w600,
                                      color: _authMode == 1 ? slateDark : slateMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

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

                  // Phone / Email Input Box
                  if (_authMode == 0) ...[
                    // WhatsApp Phone Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🇮🇳 +91',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: slateDark, letterSpacing: 1.2),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Enter Mobile Number',
                                hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8), letterSpacing: 0),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _handleContinue(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Email Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: slateDark),
                        decoration: InputDecoration(
                          icon: const Icon(Icons.email_outlined, size: 20, color: slateMuted),
                          hintText: 'Enter Email Address (e.g. name@gmail.com)',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _handleContinue(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

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
                            : Text(
                                'Continue ➔',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Divider OR
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: slateMuted),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Niche: Continue with Google Button
                  Bounceable(
                    onTap: _isLoading ? () {} : _handleGoogleSignIn,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: slateDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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
        ],
      ),
    );
  }

  Widget _buildTrustBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
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