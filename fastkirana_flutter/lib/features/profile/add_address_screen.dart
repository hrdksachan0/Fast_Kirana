import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../widgets/brand_button.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  int _type = 0;
  bool _isDefault = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Add Address', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Type Selector
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Row(
                children: [
                  _typeChip('Home', Icons.home_rounded, 0),
                  _typeChip('Work', Icons.work_rounded, 1),
                  _typeChip('Other', Icons.location_on_rounded, 2),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildField(_houseController, 'House / Flat No.', Icons.home_work_rounded),
            const SizedBox(height: 12),
            _buildField(_streetController, 'Street / Society', Icons.signpost_rounded),
            const SizedBox(height: 12),
            _buildField(_areaController, 'Area / Locality', Icons.map_rounded),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField(_cityController, 'City', Icons.location_city_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(_pincodeController, 'Pincode', Icons.pin_drop_rounded, maxLength: 6)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.borderLight),
              ),
              child: SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: Text('Set as default address', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                activeColor: AppDesignSystem.primary,
              ),
            ),
            const SizedBox(height: 24),
            BrandButton(
              text: 'Save Address',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Address saved!'), backgroundColor: AppDesignSystem.success, behavior: SnackBarBehavior.floating),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, IconData icon, int value) {
    final isSelected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignSystem.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : AppDesignSystem.textSecondary),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppDesignSystem.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {int? maxLength}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
          icon: Icon(icon, color: AppDesignSystem.primary),
          labelText: label,
          border: InputBorder.none,
          counterText: maxLength != null ? '' : null,
        ),
      ),
    );
  }
}