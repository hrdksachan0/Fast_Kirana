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
import '../../core/services/notification_service.dart';
import '../../widgets/brand_logo.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String identifier;
  const OtpScreen({super.key, required this.identifier});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> with WidgetsBindingObserver {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  bool _isLoading = false;
  int _resendCooldown = 0;
  String? _errorMessage;
  String? _clipboardOtp;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color primaryRedLight = Color(0xFFDC2626);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controllers = List.generate(6, (i) => TextEditingController());
    _focusNodes = List.generate(6, (i) => FocusNode());

    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }

    _startResendCooldown();
    _checkClipboard();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  void _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';
      final digits = text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 6 && digits != _clipboardOtp) {
        if (mounted) {
          setState(() => _clipboardOtp = digits);
        }
      }
    } catch (_) {}
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _fillOtp(String code) {
    final clean = code.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < 6; i++) {
      if (i < clean.length) {
        _controllers[i].text = clean[i];
      } else {
        _controllers[i].clear();
      }
    }
    setState(() => _clipboardOtp = null);
    HapticFeedback.mediumImpact();
    if (clean.length >= 6) {
      _focusNodes[5].requestFocus();
      _handleVerifyOtp();
    } else if (clean.isNotEmpty) {
      _focusNodes[clean.length.clamp(0, 5)].requestFocus();
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

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Handle full paste into a single box
    if (digits.length > 1) {
      _fillOtp(digits);
      return;
    }

    if (digits.isNotEmpty) {
      _controllers[index].text = digits[0];
      HapticFeedback.selectionClick();
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentOtp.length == 6) {
          _handleVerifyOtp();
        }
      }
    } else {
      _controllers[index].clear();
    }
    setState(() {});
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        HapticFeedback.selectionClick();
        setState(() {});
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _currentOtp.replaceAll(RegExp(r'\D'), '');
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

        await prefs.setString('user_id', user.id);
        await prefs.setString('user_phone', widget.identifier);
        await prefs.setString('user_data', jsonEncode(user.toJson()));
        if (response.token != null && response.token!.isNotEmpty) {
          await prefs.setString('auth_token', response.token!);
        }

        try {
          NotificationService().registerDeviceToken(ref.read(dioProvider));
        } catch (_) {}

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
        setState(() => _errorMessage = 'Invalid OTP code. Please check and retry.');
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
                            Text(
                              'Enter your name to personalize your orders',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: errorText != null ? primaryRed : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
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
                            color: primaryRed.withValues(alpha: 0.32),
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
      if (!mounted) return;
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
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
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
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
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
        child: ResponsiveContainer(
          maxWidth: Responsive.formMaxContentWidth,
          fillHeight: true,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // 3D Brand Logo with Radiant Aura
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withValues(alpha: 0.18),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: BrandLogo(size: 40),
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 16),

                // Header Texts
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Enter Verification Code',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'We sent a 6-digit OTP code to',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇮🇳', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              '+91 ${widget.identifier}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 100.ms),

                const SizedBox(height: 20),

                // Elevated Luxury Card for OTP Input & Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error Banner if any
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: primaryRed, size: 15),
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

                      // Smart Clipboard Autofill Pill
                      if (_clipboardOtp != null && _currentOtp.length < 6) ...[
                        Center(
                          child: GestureDetector(
                            onTap: () => _fillOtp(_clipboardOtp!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📋', style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap to paste code $_clipboardOtp',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 250.ms),
                      ],

                      // 6 Tactile OTP Boxes with Full Interactive Focus & Backspace Control
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final controller = _controllers[index];
                          final focusNode = _focusNodes[index];
                          final hasFocus = focusNode.hasFocus;
                          final hasValue = controller.text.isNotEmpty;

                          return Container(
                            width: 44,
                            height: 54,
                            margin: EdgeInsets.only(right: index == 5 ? 0 : 7),
                            decoration: BoxDecoration(
                              color: hasFocus
                                  ? Colors.white
                                  : (hasValue ? const Color(0xFFFAFAFA) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasFocus
                                    ? primaryRed
                                    : (hasValue ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                                width: hasFocus ? 2.0 : (hasValue ? 1.4 : 1.0),
                              ),
                              boxShadow: [
                                if (hasFocus)
                                  BoxShadow(
                                    color: primaryRed.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Focus(
                              onKeyEvent: (node, event) {
                                _onKeyDown(index, event);
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                showCursor: hasFocus && !hasValue,
                                cursorColor: primaryRed,
                                cursorWidth: 2,
                                cursorHeight: 20,
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (val) => _onDigitChanged(index, val),
                                onTap: () {
                                  controller.selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: controller.text.length,
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 18),

                      // Resend Timer Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive code? ",
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: slateMuted,
                            ),
                          ),
                          GestureDetector(
                            onTap: _resendCooldown > 0 ? null : _handleResend,
                            child: Text(
                              _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'Resend OTP',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _resendCooldown > 0 ? slateLight : primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Big Red Continue / Verify Button
                      Bounceable(
                        onTap: _isLoading ? null : _handleVerifyOtp,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
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
                                        'Verify & Proceed',
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
                ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

                const SizedBox(height: 32),

                // Bottom Trust Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          '100% Secure & Encrypted Verification',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 250.ms),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}