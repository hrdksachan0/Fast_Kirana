import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class AdminBannersScreen extends StatelessWidget {
  const AdminBannersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = List.generate(5, (i) => {
      'title': ['Fresh Deals', 'Free Delivery', 'Cafe Combos', 'Weekend Sale', 'New Arrivals'][i],
      'active': i < 3,
      'impressions': [12000, 8500, 6400, 4300, 2100][i],
    });

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('Banners Management', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
        actions: [IconButton(icon: Icon(Icons.add_photo_alternate_rounded, color: AppDesignSystem.primary), onPressed: () {})],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final b = banners[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark]),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  ),
                  child: Center(child: Text(b['title'].toString(), style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: Colors.white))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b['title'].toString(), style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                        const SizedBox(height: 4),
                        Text('${b['impressions']} views', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (b['active'] as bool) ? AppDesignSystem.success.withOpacity(0.1) : AppDesignSystem.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text((b['active'] as bool) ? 'LIVE' : 'INACTIVE', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9), fontWeight: FontWeight.w800, color: (b['active'] as bool) ? AppDesignSystem.success : AppDesignSystem.danger)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(icon: Icon(Icons.edit_outlined, color: AppDesignSystem.primary), onPressed: () {}),
              ],
            ),
          );
        },
      ),
    );
  }
}