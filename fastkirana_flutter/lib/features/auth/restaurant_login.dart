import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/routes/page_transitions.dart';
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

  void _navigateBackToStore() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
                        decoration: const InputDecoration(
                          labelText: 'Email',
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
                        text: 'Login',
                        onPressed: () async {
                          await ref.read(staffCustomerModeProvider.notifier).setCustomerMode(false);
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            FadeSlideRoute(page: const RestaurantDashboard()),
                            (route) => false,
                          );
                        },
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