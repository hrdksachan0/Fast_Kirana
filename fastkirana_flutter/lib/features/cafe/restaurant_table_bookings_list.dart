import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class RestaurantTableBookingListScreen extends StatelessWidget {
  const RestaurantTableBookingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookings = List.generate(8, (i) => {
      'name': ['Rahul S.', 'Priya K.', 'Amit V.', 'Neha G.', 'Karan P.', 'Sneha M.', 'Rohit V.', 'Anjali T.'][i],
      'guests': [2, 4, 2, 6, 3, 2, 5, 4][i],
      'time': ['7:00 PM', '8:00 PM', '7:30 PM', '12:00 PM', '8:00 PM', '1:00 PM', '7:00 PM', '9:00 PM'][i],
      'status': ['CONFIRMED', 'CONFIRMED', 'PENDING', 'CONFIRMED', 'CANCELLED', 'CONFIRMED', 'PENDING', 'CONFIRMED'][i],
      'date': 'Aug ${7 + (i % 5)}',
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Table Bookings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final b = bookings[index];
          final statusColor = b['status'] == 'CONFIRMED' ? AppDesignSystem.success : b['status'] == 'PENDING' ? AppDesignSystem.warning : AppDesignSystem.danger;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: AppDesignSystem.cafeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('👤', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(b['name']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(b['status']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${b['guests']} guests • ${b['time']} • ${b['date']}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
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