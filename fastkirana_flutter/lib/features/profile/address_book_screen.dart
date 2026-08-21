import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/address.dart';
import '../../widgets/brand_input.dart';
import '../../widgets/brand_button.dart';

class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  final _addresses = [
    Address(id: '1', label: 'Home', street: '123 Main Street', pincode: '208001', phone: '9876543210'),
    Address(id: '2', label: 'Work', street: '456 Office Park, Sector 5', pincode: '208002', phone: '9876543210'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text('My Addresses', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _addresses.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppDesignSystem.shadowCard,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                addr.label == 'Home' ? Icons.home_rounded : Icons.work_rounded,
                                size: 20,
                                color: AppDesignSystem.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(addr.label, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(addr.fullAddress, style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text('Pincode: ${addr.pincode}', style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.edit_rounded, size: 18),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: BrandButton(
              text: '📍 Add New Address (Map Picker)',
              onPressed: () => _showMapLocationPicker(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showMapLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String selectedLocationName = '📍 Ghatampur Main Market';
            String selectedCoordinates = '26.1534° N, 80.1714° E';
            String selectedPincode = '209206';
            String searchLocationQuery = '';

            final locationSuggestions = [
              {'name': 'Ghatampur Main Market', 'coords': '26.1534° N, 80.1714° E', 'pin': '209206'},
              {'name': 'Railway Station Road, Ghatampur', 'coords': '26.1582° N, 80.1755° E', 'pin': '209206'},
              {'name': 'Ghatampur Chauraha, Kanpur Road', 'coords': '26.1601° N, 80.1690° E', 'pin': '209206'},
              {'name': 'Nehru Nagar, Ghatampur', 'coords': '26.1510° N, 80.1680° E', 'pin': '209206'},
              {'name': 'Kanpur Nagar Darkstore Hub', 'coords': '26.1550° N, 80.1720° E', 'pin': '209206'},
            ];

            final filteredSuggestions = searchLocationQuery.isEmpty
                ? locationSuggestions
                : locationSuggestions
                    .where((l) => l['name']!.toLowerCase().contains(searchLocationQuery.toLowerCase()))
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📍 Search & Set Delivery Location',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 🔍 Searchable Location Bar
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      onChanged: (val) => setSheetState(() => searchLocationQuery = val),
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search area, street, or landmark in Ghatampur...',
                        hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppDesignSystem.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFEA580C)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search Suggestions List
                  if (searchLocationQuery.isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: AppDesignSystem.shadowSm,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredSuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final loc = filteredSuggestions[index];
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFEA580C)),
                              title: Text(loc['name']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                              subtitle: Text('Pincode: ${loc['pin']}', style: GoogleFonts.inter(fontSize: 10, color: AppDesignSystem.textSecondary)),
                              onTap: () {
                                setSheetState(() {
                                  selectedLocationName = '📍 ${loc['name']}';
                                  selectedCoordinates = loc['coords']!;
                                  selectedPincode = loc['pin']!;
                                  searchLocationQuery = '';
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Map Visual Canvas
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on_rounded, size: 54, color: Color(0xFFEA580C)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AppDesignSystem.shadowSm,
                                  ),
                                  child: Text(
                                    '$selectedLocationName ($selectedCoordinates)',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Pincode: $selectedPincode',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF0369A1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Street Address Input
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'House / Flat / Building Name',
                      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.home_outlined, size: 18, color: Color(0xFFEA580C)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  BrandButton(
                    text: 'Save Location & Proceed',
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF16A34A),
                          content: Text('Searchable map location saved to your Address Book!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.location_off_rounded, size: 64, color: AppDesignSystem.textMuted),
          const SizedBox(height: 16),
          Text('No addresses yet', style: GoogleFonts.inter(fontSize: 16, color: AppDesignSystem.textSecondary)),
        ],
      ),
    );
  }
}