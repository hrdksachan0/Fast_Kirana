import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/network/api_client.dart';

class TableBookingScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;
  const TableBookingScreen({super.key, required this.restaurantId, required this.restaurantName});

  @override
  ConsumerState<TableBookingScreen> createState() => _TableBookingScreenState();
}

class _TableBookingScreenState extends ConsumerState<TableBookingScreen> {
  int _guests = 2;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '7:00 PM';
  String _selectedSlot = 'Dinner';
  final _specialRequestController = TextEditingController();
  bool _isLoading = false;

  final List<String> _timeSlots = [
    '11:00 AM', '12:00 PM', '1:00 PM', '2:00 PM',
    '7:00 PM', '8:00 PM', '9:00 PM', '10:00 PM',
  ];

  final List<String> _slots = ['Lunch', 'Dinner'];

  @override
  void dispose() {
    _specialRequestController.dispose();
    super.dispose();
  }

  Future<void> _bookTable() async {
    setState(() => _isLoading = true);
    try {
      // API call to book table
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Table booked at ${widget.restaurantName}!'),
          backgroundColor: AppDesignSystem.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e'), backgroundColor: AppDesignSystem.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Reserve a Table',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppDesignSystem.cafeAccent, const Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppDesignSystem.shadowCard,
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text('☕', style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 28)))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.restaurantName, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('⭐ 4.5 • Cafe • ₹300 for two', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Guests
            Text('Number of Guests', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(8, (i) => i + 1).map((num) {
                  final isSelected = _guests == num;
                  return GestureDetector(
                    onTap: () => setState(() => _guests = num),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppDesignSystem.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('$num', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppDesignSystem.textPrimary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Date
            Text('Select Date', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppDesignSystem.primary : AppDesignSystem.borderLight),
                        boxShadow: AppDesignSystem.shadowSm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(DateFormat('EEE').format(date), style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: isSelected ? Colors.white : AppDesignSystem.textSecondary)),
                          const SizedBox(height: 4),
                          Text('${date.day}', style: GoogleFonts.poppins(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppDesignSystem.textPrimary)),
                          Text(DateFormat('MMM').format(date), style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), color: isSelected ? Colors.white70 : AppDesignSystem.textMuted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Slot
            Text('Meal Slot', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: _slots.map((slot) {
                final isSelected = _selectedSlot == slot;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      margin: EdgeInsets.only(right: slot == _slots.last ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppDesignSystem.primary : AppDesignSystem.borderLight),
                      ),
                      child: Center(
                        child: Text(slot, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppDesignSystem.textPrimary)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Time
            Text('Select Time', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((time) {
                final isSelected = _selectedTime == time;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = time),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppDesignSystem.primary : AppDesignSystem.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppDesignSystem.primary : AppDesignSystem.borderLight),
                    ),
                    child: Text(time, style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppDesignSystem.textPrimary)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Special Request
            Text('Special Requests (Optional)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: TextField(
                controller: _specialRequestController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Any special requests?',
                  hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textMuted),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Book Button
            BrandButton(
              text: 'Confirm Booking ($_guests guests, $_selectedTime)',
              onPressed: _bookTable,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}