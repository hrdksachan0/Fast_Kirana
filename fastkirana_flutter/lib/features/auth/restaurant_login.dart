import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_button.dart';
import '../cafe/restaurant_dashboard.dart';

class RestaurantLoginScreen extends ConsumerStatefulWidget {
  const RestaurantLoginScreen({super.key});

  @override
  ConsumerState<RestaurantLoginScreen> createState() => _RestaurantLoginScreenState();
}

class _RestaurantLoginScreenState extends ConsumerState<RestaurantLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _navigateBackToStore() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _handleLogin() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter kitchen email/phone and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/auth/login', data: {
        'email': input,
        'password': password,
      });

      final data = response.data;
      final userData = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : (data is Map<String, dynamic> ? data : <String, dynamic>{});
      final role = (userData['role'] ?? data['role'] ?? '').toString().toUpperCase().trim();

      const allowedRoles = {'RESTAURANT_OWNER', 'CHEF', 'RESTAURANT', 'ADMIN', 'SUPER_ADMIN'};
      if (!allowedRoles.contains(role)) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Access denied: Restaurant kitchen account required.';
        });
        return;
      }

      final kitchenUser = User.fromJson(userData);
      final token = data['token']?.toString() ?? '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(kitchenUser.toJson()));
      await prefs.setString('user_role', role);

      await SecureStorage.write('user_data', jsonEncode(kitchenUser.toJson()));
      if (token.isNotEmpty) {
        await SecureStorage.write('auth_token', token);
      }
      await SecureStorage.write('user_role', role);

      await ref.read(authProvider.notifier).setUser(kitchenUser);
      await ref.read(staffCustomerModeProvider.notifier).setCustomerMode(false);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushAndRemoveUntil(
        FadeSlideRoute(
          page: RestaurantDashboard(
            initialRestaurantId: kitchenUser.assignedRestaurantId,
          ),
        ),
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = (e.response?.data is Map && e.response?.data['detail'] != null)
          ? e.response!.data['detail'].toString()
          : 'Invalid kitchen credentials or network unavailable.';
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Login failed. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
        backgroundColor: AppDesignSystem.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.textPrimary),
            onPressed: _navigateBackToStore,
            tooltip: 'Back to Store',
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.red600]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppDesignSystem.red600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Center(child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48)))),
                ),
                const SizedBox(height: 24),
                Text('Restaurant Kitchen Login', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 22), fontWeight: FontWeight.w900, color: AppDesignSystem.textPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Manage live kitchen orders, cooking timer & stock', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusCancelled,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.red200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.statusCancelledText,
                      ),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.borderLight),
                    boxShadow: AppDesignSystem.shadowSm,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email or Phone',
                          prefixIcon: Icon(Icons.email_outlined, color: AppDesignSystem.primary),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: AppDesignSystem.primary),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 16),
                      BrandButton(
                        text: _isLoading ? 'Signing in...' : 'Login',
                        onPressed: _isLoading ? () {} : _handleLogin,
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
