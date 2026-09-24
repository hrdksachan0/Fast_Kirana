import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/responsive.dart';
import '../admin/vendor_console_screen.dart';

class VendorLoginScreen extends ConsumerStatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  ConsumerState<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends ConsumerState<VendorLoginScreen> {
  final _phoneOrCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateCard = Color(0xFF1E293B);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color primaryRed = Color(0xFFE20A22);

  @override
  void dispose() {
    _phoneOrCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleVendorLogin() async {
    final input = _phoneOrCodeController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Please enter your registered phone number or vendor code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/api/vendors/login',
        data: {
          'phone': input,
          'vendorCode': input,
        },
      );

      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final token = data['token']?.toString() ?? '';
        final vendor = data['vendor'] as Map<String, dynamic>? ?? {};
        final vendorId = vendor['id']?.toString() ?? '';
        final vendorName = vendor['name']?.toString() ?? 'Supplier Partner';
        final phone = vendor['phone']?.toString() ?? input;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'VENDOR');
        await prefs.setString('vendor_id', vendorId);
        await prefs.setString('vendor_name', vendorName);
        await prefs.setString('vendor_phone', phone);
        await prefs.setString('auth_token', token);
        await prefs.setString('vendor_data', jsonEncode(vendor));

        await SecureStorage.write('user_role', 'VENDOR');
        await SecureStorage.write('vendor_id', vendorId);
        await SecureStorage.write('vendor_name', vendorName);
        await SecureStorage.write('vendor_phone', phone);
        await SecureStorage.write('auth_token', token);
        await SecureStorage.write('vendor_data', jsonEncode(vendor));

        // Subscribe to vendor-specific FCM push notification topics
        try {
          await FirebaseMessaging.instance.subscribeToTopic('vendor_$vendorId');
          final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (cleanPhone.length >= 10) {
            await FirebaseMessaging.instance.subscribeToTopic('phone_${cleanPhone.substring(cleanPhone.length - 10)}');
          }
        } catch (_) {}

        HapticFeedback.heavyImpact();
        if (!mounted) return;

        setState(() => _isLoading = false);

        Navigator.pushReplacement(
          context,
          FadeSlideRoute(
            page: VendorConsoleScreen(
              initialVendorId: vendorId,
              isVendorSelf: true,
            ),
          ),
        );
      } else {
        throw Exception('Login failed. Please check credentials.');
      }
    } catch (e) {
      HapticFeedback.vibrate();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No active supplier account found for "$input". Please contact FastKirana Store Admin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slateDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Partner Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: slateCard,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF334155), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.storefront_rounded, color: primaryRed, size: 42),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Brand & Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'FastKirana',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 20),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'PARTNER',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 9),
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supplier & Vendor Portal',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 17),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Live order alerts, stock rates, daily bikri & payouts',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: slateCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registered Phone or Vendor Code',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneOrCodeController,
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'e.g. 6393257145 or BIDIT01',
                            hintStyle: GoogleFonts.inter(color: slateMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.phone_android_rounded, color: primaryRed, size: 20),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF334155)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF334155)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: primaryRed, width: 1.5),
                            ),
                          ),
                          onSubmitted: (_) => _handleVendorLogin(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _handleVendorLogin,
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    'Enter Vendor Console',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Help & Back to customer login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 14, color: slateMuted),
                      const SizedBox(width: 5),
                      Text(
                        'New supplier partner? ',
                        style: GoogleFonts.inter(fontSize: 12, color: slateMuted),
                      ),
                      Text(
                        'Contact Store Operations',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF38BDF8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFF94A3B8)),
                    label: Text(
                      'Back to Store',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
