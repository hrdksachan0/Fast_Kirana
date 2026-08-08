import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final List<Map<String, dynamic>> _subscriptions = [
    {
      'title': 'Amul Toned Milk (500ml)',
      'schedule': 'Everyday at 7:00 AM',
      'qty': '2 Packets',
      'price': '₹54 / day',
      'status': true,
      'emoji': '🥛',
    },
    {
      'title': 'Harvest Gold Brown Bread',
      'schedule': 'Mon, Wed, Fri at 7:30 AM',
      'qty': '1 Loaf',
      'price': '₹45 / day',
      'status': true,
      'emoji': '🍞',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Daily Subscriptions',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subscriptions.length,
        itemBuilder: (context, index) {
          final item = _subscriptions[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(item['emoji'], style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['schedule'],
                        style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['qty']} • ${item['price']}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: item['status'],
                  activeColor: AppDesignSystem.accent,
                  onChanged: (val) {
                    setState(() => item['status'] = val);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
