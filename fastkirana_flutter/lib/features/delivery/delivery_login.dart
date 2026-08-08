import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class DeliveryLoginScreen extends ConsumerStatefulWidget {
  const DeliveryLoginScreen({super.key});

  @override
  ConsumerState<DeliveryLoginScreen> createState() => _DeliveryLoginScreenState();
}

class _DeliveryLoginScreenState extends ConsumerState<DeliveryLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _showOtp = false;
  bool _isLoading = false;

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
                  gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppDesignSystem.shadowGlow,
                ),
                child: Icon(Icons.delivery_dining_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text(
                'Delivery Partner Login',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to start delivering',
                style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary),
              ),
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
                    if (!_showOtp) ...[
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixText: '+91 ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      BrandButton(
                        text: 'Send OTP',
                        onPressed: _isLoading ? null : () {
                          setState(() => _showOtp = true);
                        },
                        isLoading: _isLoading,
                      ),
                    ] else ...[
                      Text('Enter 4-digit OTP', style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(4, (i) => SizedBox(
                          width: 56,
                          height: 56,
                          child: TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 4,
                            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(borderSide: BorderSide(width: 2)),
                            ),
                          ),
                        )),
                      ),
                      const SizedBox(height: 24),
                      BrandButton(
                        text: 'Login',
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeliveryDashboard()));
                        },
                      ),
                    ],
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