import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.person_outline_rounded, 'title': 'My Profile', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.location_on_outlined, 'title': 'My Addresses', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.wallet_outlined, 'title': 'Wallet & Offers', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.card_giftcard_outlined, 'title': 'Refer & Earn', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.help_outline_rounded, 'title': 'Help & Support', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.info_outline_rounded, 'title': 'About Us', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.privacy_tip_outlined, 'title': 'Privacy Policy', 'trailing': Icons.arrow_forward_ios_rounded},
    {'icon': Icons.logout_rounded, 'title': 'Logout', 'trailing': null, 'isDestructive': true},
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Spacer(),
                  const Text(
                    'My Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.settings_outlined,
                      size: 20, color: AppTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Profile card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primary.withOpacity(0.1),
                                  AppTheme.primary.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.person_outlined,
                              size: 28, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.userName ?? 'Guest User',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  auth.phone ?? '+91 00000 00000',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Menu items
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                      ),
                      child: Column(
                        children: List.generate(_menuItems.length, (index) {
                          final item = _menuItems[index];
                          final isLast = index == _menuItems.length - 1;
                          final isDestructive = item['isDestructive'] ?? false;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (isDestructive) {
                                _showLogoutDialog(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: AppTheme.border.withOpacity(0.5),
                                          width: 0.5,
                                        ),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDestructive
                                          ? const Color(0xFFFEE2E2)
                                          : AppTheme.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      size: 20,
                                      color: isDestructive
                                          ? const Color(0xFFEF4444)
                                          : AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item['title'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDestructive
                                            ? const Color(0xFFEF4444)
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    item['trailing'],
                                    size: 16,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App version
                    Text(
                      'FastKirana v1.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted.withOpacity(0.5),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout?',
          style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
            child: Text('Logout',
              style: TextStyle(color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
