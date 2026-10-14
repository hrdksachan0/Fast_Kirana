import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard.dart';
import '../admin/vendor_console_screen.dart';
import '../cafe/restaurant_dashboard.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/picker_dashboard.dart';

typedef StaffLoginScreen = VendorLoginScreen;

class VendorLoginScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  final bool initialPasswordMode;

  const VendorLoginScreen({
    super.key,
    this.initialPhone,
    this.initialPasswordMode = false,
  });

  @override
  ConsumerState<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends ConsumerState<VendorLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  late bool _usePasswordLogin;
  bool _obscurePassword = true;
  int _resendCooldown = 0;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _usePasswordLogin = widget.initialPasswordMode;
    if (widget.initialPhone != null && widget.initialPhone!.trim().isNotEmpty) {
      _phoneController.text = widget.initialPhone!.trim();
    }
  }

  static const Color slateMuted = Color(0xFF64748B);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryGreen = Color(0xFF16A34A);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    final phone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      await authRepo.sendOtp(phone);

      if (!mounted) return;
      setState(() {
        _isOtpSent = true;
        _isLoading = false;
        _successMessage = 'OTP code sent to +91 $phone';
      });
      _startResendCooldown();
      HapticFeedback.mediumImpact();
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Failed to send OTP. Please check connection.';
      if (data is Map) {
        msg = data['error']?.toString() ??
            data['detail']?.toString() ??
            data['message']?.toString() ??
            'Failed to send OTP. Please check connection.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      HapticFeedback.vibrate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error. Please try again.';
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    final phone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
    final otp = _otpController.text.replaceAll(RegExp(r'\D'), '').trim();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP code');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      final response = await authRepo.verifyOtp(phone, otp);

      if (response.success && response.token != null) {
        final prefs = await SharedPreferences.getInstance();

        User user = response.user ??
            User(
              id: '',
              name: '',
              email: '',
              phone: phone,
              role: 'USER',
              isBlocked: false,
            );

        final isMasterAdminUser = phone.contains('7054470303') ||
            phone.contains('9170942500') ||
            (user.phone?.contains('7054470303') ?? false) ||
            (user.phone?.contains('9170942500') ?? false) ||
            user.email.toLowerCase().startsWith('admin@') ||
            user.email.toLowerCase().startsWith('superadmin@');

        String roleUpper = isMasterAdminUser ? 'ADMIN' : user.role.toUpperCase();
        if (isMasterAdminUser && user.role != 'ADMIN') {
          user = user.copyWith(role: 'ADMIN');
        }

        // Also check if this number is a registered supplier/vendor in database
        String? activeVendorId;
        try {
          final dio = ref.read(dioProvider);
          final vRes = await dio.post('/api/vendors/login', data: {'phone': phone});
          if (vRes.statusCode == 200 && vRes.data != null) {
            final vData = vRes.data;
            final vMap = vData['vendor'] as Map<String, dynamic>?;
            activeVendorId = vMap?['id']?.toString() ?? vData['vendorId']?.toString();
            if (roleUpper == 'USER') {
              roleUpper = 'VENDOR';
              user = user.copyWith(role: 'VENDOR');
            }
          }
        } catch (_) {}

        // Persist session
        await prefs.setString('user_id', user.id);
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_role', roleUpper);
        await prefs.setString('user_data', jsonEncode(user.toJson()));

        await SecureStorage.write('user_id', user.id);
        await SecureStorage.write('user_phone', phone);
        await SecureStorage.write('user_role', roleUpper);
        await SecureStorage.write('user_data', jsonEncode(user.toJson()));
        await SecureStorage.write('auth_token', response.token!);
        await SecureStorage.loadCache();

        await ref.read(authProvider.notifier).setUser(user);

        // Topic subscriptions
        try {
          if (activeVendorId != null) {
            await FirebaseMessaging.instance.subscribeToTopic('vendor_$activeVendorId');
          }
          await FirebaseMessaging.instance.subscribeToTopic('phone_$phone');
        } catch (_) {}

        HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Direct Console Navigation for Staff Login (Clear auth backstack so back press doesn't show login page)
        await ref.read(staffCustomerModeProvider.notifier).setCustomerMode(false);
        if (!mounted) return;

        Widget targetConsole;
        if (roleUpper == 'ADMIN') {
          targetConsole = const AdminDashboard();
        } else if (roleUpper == 'DELIVERY' || roleUpper == 'RIDER' || roleUpper == 'DELIVERY_PARTNER') {
          targetConsole = const DeliveryDashboard();
        } else if (roleUpper == 'RESTAURANT_OWNER' || roleUpper == 'CHEF' || roleUpper == 'RESTAURANT') {
          targetConsole = RestaurantDashboard(initialRestaurantId: user.assignedRestaurantId);
        } else if (roleUpper == 'PICKER') {
          targetConsole = const PickerDashboard();
        } else if (roleUpper == 'VENDOR' || activeVendorId != null) {
          targetConsole = VendorConsoleScreen(
            initialVendorId: activeVendorId,
            isVendorSelf: true,
          );
        } else {
          // Standard customer without staff role
          _showNonStaffDialog();
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          FadeSlideRoute(page: targetConsole),
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = 'Invalid OTP code. Please try again.');
        HapticFeedback.vibrate();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      String msg = 'Invalid or expired OTP code.';
      if (data is Map) {
        msg = data['error']?.toString() ?? data['detail']?.toString() ?? data['message']?.toString() ?? msg;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      HapticFeedback.vibrate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed. Please check connection.';
      });
    }
  }

  Future<void> _handlePasswordLogin() async {
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    final phone = rawPhone.length > 10 ? rawPhone.substring(rawPhone.length - 10) : rawPhone;
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter phone number and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/auth/login', data: {
        'phone': phone,
        'email': phone,
        'password': password,
      });

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final token = data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
        final userData = data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : (data is Map<String, dynamic> ? data : <String, dynamic>{});
        final role = (userData['role'] ?? data['role'] ?? 'USER').toString().toUpperCase();

        final user = User.fromJson(userData);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(user.toJson()));
        await prefs.setString('user_role', role);
        await prefs.setString('user_phone', phone);

        await SecureStorage.write('user_data', jsonEncode(user.toJson()));
        await SecureStorage.write('auth_token', token);
        await SecureStorage.write('user_role', role);
        await SecureStorage.write('user_phone', phone);
        await SecureStorage.loadCache();

        ref.read(authProvider.notifier).setUser(user);

        HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() => _isLoading = false);

        final roleUpper = role.toUpperCase();
        await ref.read(staffCustomerModeProvider.notifier).setCustomerMode(false);
        if (!mounted) return;

        Widget targetConsole;
        if (roleUpper == 'ADMIN') {
          targetConsole = const AdminDashboard();
        } else if (roleUpper == 'DELIVERY' || roleUpper == 'RIDER' || roleUpper == 'DELIVERY_PARTNER') {
          targetConsole = const DeliveryDashboard();
        } else if (roleUpper == 'RESTAURANT_OWNER' || roleUpper == 'CHEF' || roleUpper == 'RESTAURANT') {
          targetConsole = RestaurantDashboard(initialRestaurantId: user.assignedRestaurantId);
        } else if (roleUpper == 'PICKER') {
          targetConsole = const PickerDashboard();
        } else if (roleUpper == 'VENDOR') {
          targetConsole = const VendorConsoleScreen(isVendorSelf: true);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          FadeSlideRoute(page: targetConsole),
          (route) => false,
        );
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid credentials or staff account not active.';
      });
      HapticFeedback.vibrate();
    }
  }

  void _navigateBackToStore() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _showNonStaffDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: primaryBlue),
            SizedBox(width: 8),
            Text('Customer Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Logged in successfully! This phone number has customer privileges. You can browse and order from the store.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            child: const Text('Shop as Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBackToStore();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0F1D),
        body: SafeArea(
          child: Stack(
            children: [
              // Ambient soft radiant glow behind header
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2563EB).withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
                  ),
                  child: IconButton(
                    onPressed: _navigateBackToStore,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Back to Store',
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Icon Container with radiant glowing border
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.shield_rounded, color: Color(0xFF60A5FA), size: 40),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Brand & Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FastKirana',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 21),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'STAFF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Staff & Partner Portal',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 16.5),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Store Operations • Delivery • Kitchen • Partners',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Main Login Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D31),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_usePasswordLogin) ...[
                                // ─── OTP LOGIN FLOW ───
                                Text(
                                  'REGISTERED MOBILE NUMBER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  enabled: !_isOtpSent,
                                  maxLength: 10,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: '10-digit number',
                                    hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13.5),
                                    prefixIcon: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      alignment: Alignment.centerLeft,
                                      width: 58,
                                      child: Text('+91', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    suffixIcon: _isOtpSent
                                        ? IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF60A5FA), size: 18),
                                            onPressed: () {
                                              setState(() {
                                                _isOtpSent = false;
                                                _otpController.clear();
                                                _errorMessage = null;
                                                _successMessage = null;
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFF0A0F1D),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                                  ),
                                  onSubmitted: (_) {
                                    if (!_isOtpSent) _handleSendOtp();
                                  },
                                ),

                                if (_isOtpSent) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ENTER 6-DIGIT OTP',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(context, 11),
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF94A3B8),
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      if (_resendCooldown > 0)
                                        Text(
                                          'Resend in ${_resendCooldown}s',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w600),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: _handleSendOtp,
                                          child: Text(
                                            'Resend OTP',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF60A5FA), fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    autofocus: true,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 8,
                                    ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '••••••',
                                      hintStyle: GoogleFonts.plusJakartaSans(color: slateMuted, fontSize: 18, letterSpacing: 6),
                                      filled: true,
                                      fillColor: const Color(0xFF0A0F1D),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
                                    ),
                                    onSubmitted: (_) => _handleVerifyOtp(),
                                  ),
                                ],

                                if (_successMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF052E16),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF86EFAC), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _successMessage!,
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFF86EFAC), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF450A0A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isOtpSent
                                          ? const [Color(0xFF16A34A), Color(0xFF15803D)]
                                          : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isOtpSent ? const Color(0xFF16A34A) : const Color(0xFF2563EB))
                                            .withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: _isLoading ? null : (_isOtpSent ? _handleVerifyOtp : _handleSendOtp),
                                    child: _isLoading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            _isOtpSent ? 'Verify & Enter Console' : 'Get Login OTP',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ] else ...[
                                // ─── PASSWORD LOGIN FLOW ───
                                Text(
                                  'PHONE / STAFF ID',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.text,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: 'Phone or username',
                                    hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13.5),
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF60A5FA), size: 19),
                                    filled: true,
                                    fillColor: const Color(0xFF0A0F1D),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'PASSWORD',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: 'Enter password',
                                    hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13.5),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF60A5FA), size: 19),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 19),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF0A0F1D),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                                  ),
                                  onSubmitted: (_) => _handlePasswordLogin(),
                                ),

                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF450A0A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: _isLoading ? null : _handlePasswordLogin,
                                    child: _isLoading
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            'Login with Password',
                                            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 18),
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _usePasswordLogin = !_usePasswordLogin;
                                      _errorMessage = null;
                                      _successMessage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A0F1D),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF1E293B)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _usePasswordLogin ? Icons.sms_outlined : Icons.lock_outline_rounded,
                                          size: 14,
                                          color: const Color(0xFF60A5FA),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _usePasswordLogin ? 'Use OTP Verification Instead' : 'Staff Password Login',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF93C5FD),
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

                        const SizedBox(height: 24),
                        // Back to store pill button
                        GestureDetector(
                          onTap: _navigateBackToStore,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131D31),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Store (Customer App)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
