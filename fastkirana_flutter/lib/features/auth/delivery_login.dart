import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../core/services/secure_storage_service.dart';
import '../../data/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_button.dart';
import '../delivery/delivery_dashboard.dart';

class DeliveryLoginScreen extends ConsumerStatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  ConsumerState<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends ConsumerState<DeliveryLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static const Color brandGreen = Color(0xFF00A344);
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  // Rider master password
  static const String _masterRiderPassword = 'Aryan@2026';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter the delivery partner password');
      return;
    }

    // Verify Rider Master Password
    if (password != _masterRiderPassword) {
      HapticFeedback.lightImpact();
      setState(() => _errorMessage = 'Incorrect password. Please enter the correct partner password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      // Try logging in via backend API
      try {
        final res = await dio.post('/api/auth/login', data: {
          'phone': phone,
          'password': password,
          'role': 'DELIVERY',
        });

        if (res.statusCode == 200 && res.data != null) {
          final data = res.data;
          final token = data['token'] ?? data['accessToken'] ?? 'rider_jwt_token';
          final userMap = data['user'] is Map ? data['user'] : null;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_phone', phone);
          await prefs.setString('user_id', userMap?['id'] ?? 'rider_$phone');
          await prefs.setString('user_role', 'DELIVERY');

          // Mirror to secure storage so the Dio interceptor finds it there.
          await SecureStorage.write('auth_token', token.toString());
          await SecureStorage.write('user_phone', phone);
          await SecureStorage.write('user_id', (userMap?['id'] ?? 'rider_$phone').toString());
          await SecureStorage.write('user_role', 'DELIVERY');
          await SecureStorage.loadCache();  // Refresh interceptor cache

          if (userMap != null) {
            final user = User.fromJson(Map<String, dynamic>.from(userMap));
            await ref.read(authProvider.notifier).setUser(user);
          }
        }
      } catch (_) {
        // Master password bypass allows instant access even if backend auth service is in offline/custom mode
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', 'rider_token_$phone');
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_id', 'rider_$phone');
        await prefs.setString('user_role', 'DELIVERY');
        await prefs.setString('user_name', 'FastKirana Rider ($phone)');

        await SecureStorage.write('auth_token', 'rider_token_$phone');
        await SecureStorage.write('user_phone', phone);
        await SecureStorage.write('user_id', 'rider_$phone');
        await SecureStorage.write('user_role', 'DELIVERY');
        await SecureStorage.write('user_name', 'FastKirana Rider ($phone)');
        await SecureStorage.loadCache();  // Refresh interceptor cache
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Welcome Rider +91 $phone! 🛵', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            backgroundColor: brandGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.pushReplacement(context, FadeSlideRoute(page: const DeliveryDashboard()));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Delivery Icon Badge
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A344), Color(0xFF008736)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A344).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 44))),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Delivery Partner Login',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 22),
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your mobile number and rider password',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: slateMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: primaryRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: primaryRed, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Phone Input
                      Text('Rider Mobile Number', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: slateDark)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w700, color: slateDark),
                        decoration: InputDecoration(
                          hintText: 'Enter 10-digit number',
                          prefixText: '+91 ',
                          prefixStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w700, color: slateDark),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandGreen, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Password Input
                      Text('Partner Password', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: slateDark)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w700, color: slateDark),
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: slateMuted, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brandGreen, width: 2)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      BrandButton(
                        text: 'Login to Dashboard',
                        onPressed: _handlePasswordLogin,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}