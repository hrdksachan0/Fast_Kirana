import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/theme/design_system.dart';
import '../../data/repositories/auth_repository.dart';
import '../../widgets/brand_logo.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFocused = false;

  static const Color brandRed = Color(0xFFE11D48);
  static const Color brandRedEnd = Color(0xFFF43F5E);
  static const Color badgePink = Color(0xFFFDF2F4);

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();

    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });

    _phoneController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_phone');
    if (saved != null && saved.isNotEmpty && mounted) {
      final clean = saved.replaceAll('+91', '').replaceAll(' ', '').trim();
      if (clean.length == 10) {
        setState(() {
          _phoneController.text = clean;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
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
    });

    try {
      final authRepo = AuthRepository(ref.read(dioProvider));
      await authRepo.sendOtp(phone);

      if (!mounted) return;
      Navigator.push(
        context,
        FadeSlideRoute(page: OtpScreen(identifier: phone)),
      );
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        String msg = 'Failed to send OTP. Please check connection.';
        if (data is Map) {
          msg = data['error']?.toString() ??
              data['detail']?.toString() ??
              data['message']?.toString() ??
              'Failed to send OTP. Please check connection.';
        }
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSkipGuest() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_chosen_location', true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isValidPhone = _phoneController.text.trim().length == 10;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // ─── Bottom Background Decorative Layer (Gradient Wave + Doodles) ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    // Soft warm peach gradient wave
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFF8F9FA).withOpacity(0.0),
                              const Color(0xFFFFF1F2).withOpacity(0.55),
                              const Color(0xFFFFE4E6).withOpacity(0.70),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Left Bottom: Grocery Basket Outline Doodle
                    Positioned(
                      left: 12,
                      bottom: 4,
                      child: SizedBox(
                        width: 110,
                        height: 105,
                        child: CustomPaint(
                          painter: _GroceryBasketPainter(),
                        ),
                      ),
                    ),

                    // Right Bottom: "Good Food Nearby" Handwritten Stamp
                    const Positioned(
                      right: 18,
                      bottom: 16,
                      child: _GoodFoodNearbyStamp(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Main Content Scroll View ───
          SafeArea(
            child: Column(
              children: [
                // Top Bar: Clean "Skip to Browse >" link on Top Right
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleSkipGuest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Skip to Browse',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF0F172A),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ResponsiveContainer(
                      maxWidth: Responsive.formMaxContentWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),

                            // 1. Center FastKirana Red Logo Badge
                            const Center(
                              child: FastKiranaLogoWidget(size: 78),
                            ),

                            const SizedBox(height: 14),

                            // 2. Brand Wordmark ("Fast" dark, "Kirana" red)
                            Center(
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 32),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    height: 1.1,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Fast',
                                      style: TextStyle(color: Color(0xFF0F172A)),
                                    ),
                                    TextSpan(
                                      text: 'Kirana',
                                      style: TextStyle(color: brandRed),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // 3. Subtitle: "Groceries & Food, Delivered Fast"
                            Center(
                              child: Text(
                                'Groceries & Food, Delivered Fast',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // 4. Three Feature Badges in a Row (Fast Delivery, Wide Selection, Trusted Local)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildFeatureBadge(
                                  context: context,
                                  icon: Icons.bolt_rounded,
                                  label: 'Fast\nDelivery',
                                ),
                                const SizedBox(width: 32),
                                _buildFeatureBadge(
                                  context: context,
                                  icon: Icons.shopping_bag_rounded,
                                  label: 'Wide\nSelection',
                                ),
                                const SizedBox(width: 32),
                                _buildFeatureBadge(
                                  context: context,
                                  icon: Icons.favorite_rounded,
                                  label: 'Trusted\nLocal',
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // 5. Elevated White Card Container with Input & CTA
                            Container(
                              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Card Title
                                  Text(
                                    'Login or Sign Up',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 22),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Enter your mobile number to continue',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 13.5),
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Phone Input Field Container
                                  Container(
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: _isFocused ? Colors.white : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _isFocused
                                            ? brandRed
                                            : const Color(0xFFE2E8F0),
                                        width: _isFocused ? 1.5 : 1.2,
                                      ),
                                      boxShadow: [
                                        if (_isFocused)
                                          BoxShadow(
                                            color: brandRed.withOpacity(0.08),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Flag + Country Code
                                        Padding(
                                          padding: const EdgeInsets.only(left: 14, right: 10),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '🇮🇳',
                                                style: TextStyle(
                                                  fontSize: Responsive.scaledFontSize(context, 18),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+91',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: Responsive.scaledFontSize(context, 15.5),
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Divider Line
                                        Container(
                                          width: 1,
                                          height: 24,
                                          color: const Color(0xFFE2E8F0),
                                        ),

                                        // Text Input Field
                                        Expanded(
                                          child: TextField(
                                            controller: _phoneController,
                                            focusNode: _focusNode,
                                            keyboardType: TextInputType.phone,
                                            cursorColor: brandRed,
                                            cursorWidth: 2,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(10),
                                            ],
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: Responsive.scaledFontSize(context, 15.5),
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                              letterSpacing: 0.6,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Enter 10-digit number',
                                              hintStyle: GoogleFonts.plusJakartaSans(
                                                fontSize: Responsive.scaledFontSize(context, 14),
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF94A3B8),
                                                letterSpacing: 0.2,
                                              ),
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                            ),
                                            onSubmitted: (_) => _handleContinue(),
                                          ),
                                        ),

                                        // Green checkmark badge when 10 digits entered
                                        if (isValidPhone)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 14),
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF16A34A),
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                size: 15,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ).animate().scale(duration: 200.ms),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // WhatsApp Notice Below Input
                                  Row(
                                    children: [
                                      const _WhatsAppIcon(size: 19),
                                      const SizedBox(width: 8),
                                      Text(
                                        'OTP will be sent to your WhatsApp',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(context, 12.5),
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Error Message Banner (if any)
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFEE2E2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            size: 15,
                                            color: brandRed,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: Responsive.scaledFontSize(context, 12),
                                                fontWeight: FontWeight.w600,
                                                color: brandRed,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 18),

                                  // Continue with OTP Button
                                  Bounceable(
                                    onTap: _isLoading ? null : _handleContinue,
                                    child: Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [brandRed, brandRedEnd],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: brandRed.withOpacity(0.35),
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
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Continue with OTP',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: Responsive.scaledFontSize(context, 15.5),
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 19,
                                                    color: Colors.white,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 26),

                            // 6. Clickable Terms & Privacy Policy Footer
                            Center(
                              child: GestureDetector(
                                onTap: () => _showTermsAndPrivacyModal(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'By continuing, you agree to our',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(context, 12),
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Terms & Privacy Policy',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(context, 12),
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Feature badge with pink circular background and 2-line title
  Widget _buildFeatureBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: badgePink,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: brandRed,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: Responsive.scaledFontSize(context, 11.5),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            height: 1.25,
          ),
        ),
      ],
    );
  }

  void _showTermsAndPrivacyModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms & Conditions',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 18),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'FastKirana Services & Privacy Policy',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppDesignSystem.slate200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate900),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppDesignSystem.slate200),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTncSection(
                      context,
                      '1. Service Overview',
                      'FastKirana provides on-demand grocery, dairy, snacks, beverages, and local restaurant food express delivery across Ghatampur (UP 209206).',
                    ),
                    _buildTncSection(
                      context,
                      '2. User Account & OTP Verification',
                      'To place orders, customers authenticate securely via a 6-digit OTP sent to their valid Indian mobile number. Users are responsible for keeping their account details secure.',
                    ),
                    _buildTncSection(
                      context,
                      '3. Orders, Pricing & Delivery Zones',
                      'All prices listed in the FastKirana app are inclusive of applicable taxes. Delivery charges and surge fees (if applicable during extreme weather or late nights) are clearly itemized before checkout.',
                    ),
                    _buildTncSection(
                      context,
                      '4. Payment Options',
                      'FastKirana supports 100% secure Online Payments (UPI - Google Pay, PhonePe, Paytm, BHIM, Net Banking, Credit/Debit Cards) and Cash on Delivery (COD). All online transactions are protected with 256-bit SSL encryption.',
                    ),
                    _buildTncSection(
                      context,
                      '5. Cancellation & Refund Policy',
                      'Orders can be cancelled before store acceptance without penalty. In case of prepaid orders, cancelled order refunds will be credited back to your original payment method in 2-4 business days.',
                    ),
                    _buildTncSection(
                      context,
                      '6. Privacy & Data Protection',
                      'We respect your privacy. Customer phone numbers and addresses are strictly used for order processing, delivery navigation, and customer support. We never sell personal data to third parties.',
                    ),
                    _buildTncSection(
                      context,
                      '7. Customer Support & Grievances',
                      'For any queries, missing items, or delivery assistance, reach our Ghatampur Central Support directly at +91 81128 49854 or email fastkiranadelivery@gmail.com.',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.slate900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'I Understand & Agree',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTncSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: Responsive.scaledFontSize(context, 13.5),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: GoogleFonts.plusJakartaSans(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// WhatsApp Official Green Circle Icon with Handset
class _WhatsAppIcon extends StatelessWidget {
  final double size;
  const _WhatsAppIcon({this.size = 19});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF25D366),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.phone_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
      ),
    );
  }
}

/// Left Bottom Grocery Basket Doodle Painter
class _GroceryBasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFFF43F5E).withOpacity(0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Motion lines on the left
    canvas.drawLine(const Offset(2, 68), const Offset(14, 68), stroke);
    canvas.drawLine(const Offset(0, 80), const Offset(10, 80), stroke);
    canvas.drawLine(const Offset(4, 92), const Offset(12, 92), stroke);

    // Basket rim (rounded rect)
    final rimRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 44, 76, 9),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(rimRect, stroke);

    // Basket body
    final basketPath = Path()
      ..moveTo(26, 53)
      ..lineTo(32, 90)
      ..cubicTo(34, 96, 40, 100, 46, 100)
      ..lineTo(70, 100)
      ..cubicTo(76, 100, 82, 96, 84, 90)
      ..lineTo(90, 53);
    canvas.drawPath(basketPath, stroke);

    // Vertical slat pills
    for (double x = 40; x <= 72; x += 11) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 60, 4.5, 22),
          const Radius.circular(2.25),
        ),
        stroke,
      );
    }

    // Milk bottle on the right
    final bottlePath = Path()
      ..moveTo(68, 44)
      ..lineTo(68, 24)
      ..lineTo(72, 18)
      ..lineTo(72, 10)
      ..lineTo(80, 10)
      ..lineTo(80, 18)
      ..lineTo(84, 24)
      ..lineTo(84, 44);
    canvas.drawPath(bottlePath, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(71, 7, 10, 3.5),
        const Radius.circular(1.75),
      ),
      stroke,
    );

    // Vegetables / leafy produce on the left
    final leaf1 = Path()
      ..moveTo(34, 44)
      ..cubicTo(26, 32, 26, 18, 38, 16)
      ..cubicTo(44, 20, 42, 34, 38, 44);
    canvas.drawPath(leaf1, stroke);

    final leaf2 = Path()
      ..moveTo(42, 44)
      ..cubicTo(40, 28, 48, 14, 58, 20)
      ..cubicTo(60, 30, 52, 40, 46, 44);
    canvas.drawPath(leaf2, stroke);

    // Carrot
    final carrotPath = Path()
      ..moveTo(50, 44)
      ..lineTo(56, 24)
      ..lineTo(60, 26)
      ..lineTo(54, 44);
    canvas.drawPath(carrotPath, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Right Bottom "Good Food Nearby" Handwritten Stamp
class _GoodFoodNearbyStamp extends StatelessWidget {
  const _GoodFoodNearbyStamp();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.14, // ~ -8 degrees tilt
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Good\nFood\nNearby',
            style: GoogleFonts.caveat(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF43F5E).withOpacity(0.55),
              height: 0.90,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 58,
            height: 2.2,
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withOpacity(0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}