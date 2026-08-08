import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final List<Map<String, String>> _notifications = const [
    {
      'title': '⚡ Order Delivered!',
      'body': 'Your order #FK-98214 has been delivered by Rahul in 8 mins. Enjoy fresh groceries!',
      'time': '10 mins ago',
      'icon': '🛵',
    },
    {
      'title': '🎉 Cashback Credited',
      'body': '₹25 FastKirana cashback credited to your wallet for ordering via UPI.',
      'time': '2 hours ago',
      'icon': '💰',
    },
    {
      'title': '🏷️ Weekend Mega Sale Live',
      'body': 'Get up to 60% OFF on Atta, Dal, Oil & Rice. Tap to shop now.',
      'time': '1 day ago',
      'icon': '🏷️',
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
          'Notifications',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final item = _notifications[index];
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['icon']!, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title']!,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['body']!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['time']!,
                        style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
