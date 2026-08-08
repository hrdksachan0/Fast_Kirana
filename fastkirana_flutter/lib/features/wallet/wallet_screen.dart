import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> transactions = List.generate(10, (i) => {
      'title': ['Cashback earned', 'Order refund', 'Wallet top-up', 'Referral bonus', 'Cashback earned'][i % 5],
      'amount': ['+₹50', '+₹120', '+₹500', '+₹50', '+₹25'][i % 5],
      'date': 'Aug ${(i % 7) + 1}',
      'isCredit': i % 3 != 1,
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Wallet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Column(
              children: [
                Text('Wallet Balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9))),
                const SizedBox(height: 8),
                Text('₹1,250', style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _action('Add Money', Icons.add_rounded, () {}),
                    _action('Send', Icons.send_rounded, () {}),
                    _action('Withdraw', Icons.arrow_downward_rounded, () {}),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Transaction History', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
          const SizedBox(height: 12),
          ...transactions.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppDesignSystem.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppDesignSystem.borderLight), boxShadow: AppDesignSystem.shadowSm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: ((t['isCredit'] as bool) ? AppDesignSystem.success : AppDesignSystem.danger).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Icon((t['isCredit'] as bool) ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: (t['isCredit'] as bool) ? AppDesignSystem.success : AppDesignSystem.danger)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                      Text(t['date'] as String, style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                ),
                Text(t['amount'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: (t['isCredit'] as bool) ? AppDesignSystem.success : AppDesignSystem.danger)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _action(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}