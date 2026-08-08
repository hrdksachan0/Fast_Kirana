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
              text: 'Add New Address',
              onPressed: () {},
            ),
          ),
        ],
      ),
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