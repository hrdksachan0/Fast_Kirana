import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../../core/theme/responsive.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String identifier;
  const OtpScreen({super.key, required this.identifier});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _resendCooldown = 0;
  String? _errorMessage;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color primaryRedLight = Color(0xFFFF2D4B);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].addListener(() {
        if (mounted) setState(() {});
      });
      _focusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  Future<void> _handleVerifyOtp() async {
    final rawOtp = _otpControllers.map((c) => c.text).join().replaceAll(RegExp(r'\D'), '');
    final otp = rawOtp.length > 6 ? rawOtp.substring(0, 6) : rawOtp;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      final response = await authRepo.verifyOtp(widget.identifier, otp);

      if (response.success && response.token != null) {
        final prefs = await SharedPreferences.getInstance();

        User user = response.user ??
            User(
              id: '',
              name: '',
              email: '',
              phone: widget.identifier,
              role: 'USER',
              isBlocked: false,
            );

        final rawName = (user.name ?? '').trim();
        final isExistingUser = rawName.isNotEmpty && !rawName.toLowerCase().startsWith('user ');

        // If new customer -> Prompt Full Name
        if (!isExistingUser) {
          if (!mounted) return;
          final enteredName = await _showNameBottomSheet(context);
          if (enteredName != null && enteredName.trim().isNotEmpty) {
            final validName = enteredName.trim();
            user = user.copyWith(name: validName);
            try {
              final dio = ref.read(dioProvider);
              await dio.post('/api/auth/profile/update', data: {
                'name': validName,
                'phone': widget.identifier,
              });
            } catch (e) {
              debugPrint('Profile update failed: $e');
            }
          }
        }

        await prefs.setString('user_data', jsonEncode(user.toJson()));
        if (response.token != null && response.token!.isNotEmpty) {
          await prefs.setString('auth_token', response.token!);
        }

        ref.read(authProvider.notifier).setUser(user);
        HapticFeedback.heavyImpact();

        if (!mounted) return;

        final hasChosenLocation = prefs.getBool('has_chosen_location') ?? false;
        if (!hasChosenLocation) {
          Navigator.of(context).pushNamedAndRemoveUntil('/location', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
        return;
      } else {
        setState(() => _errorMessage = 'Invalid OTP. Please check the code.');
        HapticFeedback.heavyImpact();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ??
          e.response?.data?['message'] ??
          'Invalid or expired OTP code.';
      setState(() => _errorMessage = msg);
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _errorMessage = 'Verification error. Please try again.');
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showNameBottomSheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    String? errorText;

    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('👋', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What should we call you?',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Required for orders & superfast delivery',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: slateMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        errorText!,
                        style: GoogleFonts.inter(fontSize: 11.5, color: primaryRed, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Text(
                    'Full Name *',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: slateDark),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.person_outline_rounded, size: 18, color: slateLight),
                        hintText: 'e.g. Rahul Sharma',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: slateLight),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isEmpty) {
                          setModalState(() => errorText = 'Please enter your name');
                        } else {
                          Navigator.pop(ctx, val.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  Bounceable(
                    onTap: () {
                      final val = nameCtrl.text.trim();
                      if (val.isEmpty) {
                        setModalState(() => errorText = 'Please enter your name');
                      } else {
                        Navigator.pop(ctx, val);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryRed, primaryRedLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Let\'s Get Started ➔',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
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
      },
    );
  }

  Future<void> _handleResend() async {
    if (_resendCooldown > 0) return;
    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      await authRepo.sendOtp(widget.identifier);
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP code resent successfully!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: Bounceable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: slateDark,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Top Ambient Gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 320,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFECEF),
                      Color(0xFFFFF6F7),
                      Colors.white,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 1),

                      // Brand Hero
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
                                    blurRadius: 26,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const FastKiranaLogoWidget(size: 64),
                            )
                                .animate()
                                .fadeIn(duration: 350.ms)
                                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 400.ms),
                            const SizedBox(height: 14),
                            Text(
                              'Verify OTP',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: slateDark,
                                letterSpacing: -0.6,
                              ),
                            ).animate().fadeIn(duration: 350.ms, delay: 100.ms),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Code sent to ',
                                  style: GoogleFonts.inter(fontSize: 13, color: slateMuted),
                                ),
                                Text(
                                  '+91 ${widget.identifier}',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Edit',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(duration: 350.ms, delay: 200.ms),
                          ],
                        ),
                      ),

                      const Spacer(flex: 1),

                      // OTP Input Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter 6-Digit OTP',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: slateDark,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: primaryRed, size: 15),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: primaryRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 6 Compact, Modern OTP Boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              final isBoxFilled = _otpControllers[index].text.isNotEmpty;
                              final isBoxFocused = _focusNodes[index].hasFocus;

                              return Container(
                                width: 44,
                                height: 52,
                                margin: EdgeInsets.only(
                                  right: index == 5 ? 0 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isBoxFilled ? const Color(0xFFF8FAFC) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isBoxFocused
                                        ? primaryRed
                                        : (isBoxFilled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                                    width: isBoxFocused ? 1.6 : 1.2,
                                  ),
                                  boxShadow: [
                                    if (isBoxFocused)
                                      BoxShadow(
                                        color: primaryRed.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Center(
                                  child: TextField(
                                    controller: _otpControllers[index],
                                    focusNode: _focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    textAlign: TextAlign.center,
                                    autofocus: index == 0,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      if (value.length == 1 && index < 5) {
                                        _focusNodes[index + 1].requestFocus();
                                      }
                                      if (value.isEmpty && index > 0) {
                                        _focusNodes[index - 1].requestFocus();
                                      }
                                      final all = _otpControllers.map((c) => c.text).join();
                                      if (all.length == 6) {
                                        _handleVerifyOtp();
                                      }
                                    },
                                  ),
                                ),
                              ).animate().fadeIn(duration: 300.ms, delay: (100 + index * 30).ms);
                            }),
                          ),

                          const SizedBox(height: 18),

                          // Resend Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: GoogleFonts.inter(fontSize: 12.5, color: slateMuted),
                              ),
                              GestureDetector(
                                onTap: _resendCooldown > 0 ? null : _handleResend,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _resendCooldown > 0 ? const Color(0xFFF1F5F9) : const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend OTP',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _resendCooldown > 0 ? slateLight : primaryRed,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // Verify CTA Button
                          Bounceable(
                            onTap: _isLoading ? () {} : _handleVerifyOtp,
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
                                    color: primaryRed.withOpacity(0.35),
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
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Verify & Proceed',
                                            style: GoogleFonts.inter(
                                              fontSize: 15.5,
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
                      ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

                      const Spacer(flex: 1),

                      // Trust Badges
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTrustBadge('🔒 100% Safe & Secure'),
                            const SizedBox(width: 8),
                            _buildTrustBadge('⚡ Instant Ghatampur Express'),
                          ],
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
    );
  }

  Widget _buildTrustBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
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