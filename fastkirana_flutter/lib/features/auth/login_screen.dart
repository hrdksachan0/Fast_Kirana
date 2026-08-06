import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/design_system.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/brand_input.dart';
import '../../widgets/brand_button.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerControllerStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      final response = await authRepo.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (response.success && response.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(response.user!.toJson()));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError('Invalid credentials. Please try again.');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleContinueWithOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      await authRepo.sendOtp(_emailController.text.trim());
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              OtpScreen(identifier: _emailController.text.trim()),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppDesignSystem.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDesignSystem.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    // Premium Logo
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppDesignSystem.shadowLg,
                        ),
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Welcome Text
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.textPrimary,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Sign in to continue shopping',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppDesignSystem.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Email Input
                    BrandInput(
                      label: 'Email or Phone',
                      hint: 'Enter your email or phone number',
                      controller: _emailController,
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email or phone';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password Input
                    BrandInput(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      onSuffixTap: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppDesignSystem.primary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login Button
                    BrandButton(
                      text: 'Sign In',
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppDesignSystem.borderLight)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppDesignSystem.textTertiary,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppDesignSystem.borderLight)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // OTP Button
                    BrandButton(
                      text: 'Continue with OTP',
                      onPressed: _isLoading ? null : _handleContinueWithOtp,
                      isOutlined: true,
                    ),

                    const SizedBox(height: 32),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}