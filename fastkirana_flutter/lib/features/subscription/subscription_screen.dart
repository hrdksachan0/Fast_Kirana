import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  final List<Map<String, dynamic>> _subscriptions = [
    {
      'id': 'sub_1',
      'name': 'Amul Taaza Homogenised Milk',
      'unit': '500 ml Pouch',
      'icon': '🥛',
      'frequency': 'Daily (7 days)',
      'slot': '6:30 AM Morning',
      'price': 28,
      'status': 'active',
      'nextDelivery': 'Tomorrow, 6:30 AM',
    },
    {
      'id': 'sub_2',
      'name': 'Harvest Gold White Bread',
      'unit': '400 g Pack',
      'icon': '🍞',
      'frequency': 'Alternate Days',
      'slot': '6:30 AM Morning',
      'price': 35,
      'status': 'active',
      'nextDelivery': 'Tomorrow, 6:30 AM',
    },
    {
      'id': 'sub_3',
      'name': 'Farm Fresh White Eggs (6 pcs)',
      'unit': '6 Pack Box',
      'icon': '🥚',
      'frequency': 'Daily (Mon-Sat)',
      'slot': '7:00 AM Morning',
      'price': 45,
      'status': 'paused',
      'nextDelivery': 'Paused by you',
    },
  ];

  final List<Map<String, dynamic>> _availableCatalog = [
    {
      'name': 'Amul Gold Full Cream Milk',
      'unit': '500 ml',
      'price': 34,
      'icon': '🥛',
      'popular': true,
    },
    {
      'name': 'Amul Taaza Toned Milk',
      'unit': '500 ml',
      'price': 28,
      'icon': '🥛',
      'popular': true,
    },
    {
      'name': 'Harvest Gold Brown Bread',
      'unit': '400 g',
      'price': 45,
      'icon': '🍞',
      'popular': false,
    },
    {
      'name': 'Amul Salted Butter (100g)',
      'unit': '100 g',
      'price': 60,
      'icon': '🧈',
      'popular': false,
    },
    {
      'name': 'Farm Fresh Eggs (12 pcs)',
      'unit': '12 Pack',
      'price': 85,
      'icon': '🥚',
      'popular': true,
    },
  ];

  void _togglePause(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      final current = _subscriptions[index]['status'];
      _subscriptions[index]['status'] = current == 'active' ? 'paused' : 'active';
      _subscriptions[index]['nextDelivery'] =
          current == 'active' ? 'Paused by you' : 'Tomorrow, 6:30 AM';
    });

    final name = _subscriptions[index]['name'];
    final newStatus = _subscriptions[index]['status'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: newStatus == 'active' ? brandGreen : primaryRed,
        content: Text(
          newStatus == 'active'
              ? '✅ $name resumed! Next delivery tomorrow 6:30 AM.'
              : '⏸️ $name paused. No delivery tomorrow.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _skipTomorrow(int index) {
    HapticFeedback.lightImpact();
    final name = _subscriptions[index]['name'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF334155),
        content: Text('⏭️ Skipped tomorrow for $name. Resumes day after tomorrow!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNewSubscriptionModal(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    String frequency = 'Daily';
    String slot = '6:30 AM';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(item['icon'], style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            Text(
                              '${item['unit']} • ₹${item['price']}/day',
                              style: GoogleFonts.inter(fontSize: 12, color: slateMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Frequency',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Daily', 'Alternate Days', 'Mon-Sat'].map((f) {
                      final isSelected = frequency == f;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => frequency = f),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                f,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? primaryRed : slateDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Morning Delivery Slot',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['6:30 AM (Recommended)', '7:30 AM'].map((s) {
                      final isSelected = slot.startsWith(s.substring(0, 4));
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => slot = s),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? brandGreen : const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                s,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? brandGreen : slateDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _subscriptions.insert(0, {
                            'id': 'sub_${DateTime.now().millisecondsSinceEpoch}',
                            'name': item['name'],
                            'unit': item['unit'],
                            'icon': item['icon'],
                            'frequency': frequency,
                            'slot': slot,
                            'price': item['price'],
                            'status': 'active',
                            'nextDelivery': 'Tomorrow, 6:30 AM',
                          });
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: brandGreen,
                            content: Text('🎉 Subscribed to ${item['name']}! Delivered daily at 6:30 AM.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Confirm Subscription • ₹${item['price']}/day',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _subscriptions.where((s) => s['status'] == 'active').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daily Subscriptions',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: slateDark),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 1. Header Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE20A22), Color(0xFFFF4742)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.alarm_on_rounded, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeCount Active Subscriptions',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Fresh milk & bread delivered daily by 6:30 AM',
                        style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Active Subscriptions List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Active Plans',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: slateDark),
              ),
              Text(
                'Auto-Deliver 6:30 AM',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: brandGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._subscriptions.asMap().entries.map((entry) {
            final idx = entry.key;
            final sub = entry.value;
            final isActive = sub['status'] == 'active';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(child: Text(sub['icon'], style: const TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub['name'],
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${sub['frequency']} • ₹${sub['price']}/day',
                              style: GoogleFonts.inter(fontSize: 11, color: slateMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sub['status'].toString().toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: isActive ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 13, color: slateMuted),
                          const SizedBox(width: 4),
                          Text(
                            sub['nextDelivery'],
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: slateMuted),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _skipTomorrow(idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Skip Next',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: slateDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _togglePause(idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Pause' : 'Resume',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isActive ? primaryRed : brandGreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // 3. Daily Essentials Catalog (Add to subscription)
          Row(
            children: [
              const Text('🥛', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'Subscribe to Daily Essentials',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: slateDark),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._availableCatalog.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Text(item['icon'], style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: slateDark),
                        ),
                        Text(
                          '${item['unit']} • ₹${item['price']}/day',
                          style: GoogleFonts.inter(fontSize: 11, color: slateMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showNewSubscriptionModal(item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: primaryRed,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '+ Subscribe',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}