import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppDesignSystem.cafeAccent, const Color(0xFFEA580C)]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppDesignSystem.shadowGlow,
                ),
                child: Center(child: Text('☕', style: TextStyle(fontSize: 56))),
              ),
              const SizedBox(height: 32),
              Text('Restaurant Owner Login', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Manage your cafe/restaurant orders', style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 40),
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
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: AppDesignSystem.primary),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppDesignSystem.primary),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BrandButton(
                      text: 'Login',
                      onPressed: () {
                        Navigator.pushReplacement(context, FadeSlideRoute(page: const RestaurantDashboard()));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}