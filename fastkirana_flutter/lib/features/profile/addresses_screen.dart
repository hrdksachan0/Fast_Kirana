import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/address.dart';
import '../../widgets/brand_card.dart';
import '../../widgets/brand_button.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample addresses
    final addresses = [
      Address(
        id: '1',
        userId: 'user1',
        label: 'Home',
        houseNo: '123',
        street: 'Main Street',
        area: 'Ghatampur',
        city: 'Kanpur',
        pincode: '208001',
        phone: '9876543210',
        isDefault: true,
      ),
      Address(
        id: '2',
        userId: 'user1',
        label: 'Work',
        houseNo: '456',
        street: 'Office Road',
        area: 'Civil Lines',
        city: 'Kanpur',
        pincode: '208002',
        phone: '9876543211',
        isDefault: false,
      ),
    ];

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text('Saved Addresses', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: addresses.length,
        itemBuilder: (context, index) {
          final addr = addresses[index];
          return BrandCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      addr.label == 'Home' ? Icons.home_rounded : addr.label == 'Work' ? Icons.work_rounded : Icons.location_on_rounded,
                      color: AppDesignSystem.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      addr.label,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (addr.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppDesignSystem.success,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  addr.fullAddress,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppDesignSystem.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${addr.phone}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppDesignSystem.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Edit'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppDesignSystem.danger,
                        side: const BorderSide(color: AppDesignSystem.danger),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text('Add Address', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppDesignSystem.primary,
      ),
    );
  }
}