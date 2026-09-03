import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../widgets/brand_card.dart';
import '../../widgets/brand_button.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text('Saved Addresses', style: GoogleFonts.inter(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppDesignSystem.primary,
        onRefresh: () async {
          ref.invalidate(addressesProvider);
        },
        child: addressesAsync.when(
          data: (addresses) {
            if (addresses.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 64, color: Color(0xFFCCCCCC)),
                      const SizedBox(height: 16),
                      Text(
                        'No addresses saved yet',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w600, color: AppDesignSystem.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Add Address" to save your first delivery address',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) => _buildAddressCard(context, ref, addresses[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: AppDesignSystem.danger),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load addresses',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  BrandButton(
                    text: 'Retry',
                    onPressed: () => ref.invalidate(addressesProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: Text('Add Address', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppDesignSystem.primary,
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, WidgetRef ref, Address addr) {
    return BrandCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForLabel(addr.label),
                color: AppDesignSystem.primary,
              ),
              const SizedBox(width: 12),
              Text(
                addr.label,
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w700),
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
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
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
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Phone: ${addr.phone}',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.textSecondary),
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
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete this address?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref.read(addressRepositoryProvider).deleteAddress(addr.id);
                      ref.invalidate(addressesProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete: $e')),
                        );
                      }
                    }
                  }
                },
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
  }

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower == 'home') return Icons.home_rounded;
    if (lower == 'work' || lower == 'office') return Icons.work_rounded;
    return Icons.location_on_rounded;
  }
}
