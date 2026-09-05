import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../../core/theme/design_system.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../../../providers/product_provider.dart';

class AddPickerProductModal extends ConsumerStatefulWidget {
  final VoidCallback onProductAdded;

  const AddPickerProductModal({
    super.key,
    required this.onProductAdded,
  });

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onProductAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPickerProductModal(
        onProductAdded: onProductAdded,
      ),
    );
  }

  @override
  ConsumerState<AddPickerProductModal> createState() =>
      _AddPickerProductModalState();
}

class _AddPickerProductModalState
    extends ConsumerState<AddPickerProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _priceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _locationController = TextEditingController();
  final _stockController = TextEditingController(text: '20');
  final _minStockController = TextEditingController(text: '5');
  final _descriptionController = TextEditingController();

  String _selectedUnit = '1 pc';
  String? _selectedCategoryId;
  DateTime? _selectedExpiryDate;
  bool _isSubmitting = false;

  final List<String> _commonUnits = [
    '1 pc',
    '100 g',
    '250 g',
    '500 g',
    '1 kg',
    '2 kg',
    '5 kg',
    '200 ml',
    '500 ml',
    '1 L',
    'Pack of 2',
    'Pack of 4',
  ];

  static const Color brandOrange = Color(0xFFEA580C);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    _locationController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _openBarcodeScannerDialog() {
    final controller = TextEditingController(text: _barcodeController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppDesignSystem.blue50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: AppDesignSystem.blue600, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              'Scan / Enter Barcode',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the printed barcode or SKU code on product packaging:',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'e.g. 8901030000000',
                filled: true,
                fillColor: AppDesignSystem.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: slateBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: slateMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                _barcodeController.text = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: brandOrange,
              onPrimary: Colors.white,
              onSurface: slateDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedExpiryDate = picked);
    }
  }

  Future<void> _submitGroceryProduct() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    final mrp = double.tryParse(_mrpController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? 5;

    if (mrp <= 0) {
      AppToast.showError(context, 'MRP must be greater than ₹0');
      return;
    }

    if (price <= 0) {
      AppToast.showError(context, 'Selling price must be greater than ₹0');
      return;
    }

    if (price > mrp) {
      AppToast.showError(context, 'Selling price (₹$price) cannot exceed MRP (₹$mrp)');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'mrp': mrp,
        'price': price,
        'unit': _selectedUnit,
        'stock': stock,
        'minStock': minStock,
        if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty)
          'categoryId': _selectedCategoryId,
        if (_barcodeController.text.trim().isNotEmpty)
          'barcode': _barcodeController.text.trim(),
        if (_locationController.text.trim().isNotEmpty)
          'location': _locationController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
        if (_selectedExpiryDate != null)
          'expiryDate': _selectedExpiryDate!.toIso8601String(),
        'tags': ['grocery', 'darkstore'],
      };

      final response = await dio.post(
        '/api/picker/products',
        data: payload,
        options: Options(
          headers: {
            'x-user-role': 'PICKER',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context);
          AppToast.showSuccess(
            context,
            'Product Added to Dark Store! 🛒',
            subtitle: '${_nameController.text.trim()} added with $stock units stock.',
          );
          ref.invalidate(productsProvider(null));
          ref.invalidate(homeProductCatalogProvider);
          widget.onProductAdded();
        }
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to add product');
      }
    } catch (e) {
      debugPrint('[AddPickerProduct Error]: $e');
      if (mounted) {
        AppToast.showError(
          context,
          'Could not add grocery item',
          subtitle: e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Calculate live discount
    final mrp = double.tryParse(_mrpController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final discountPercent = (mrp > price && mrp > 0)
        ? (((mrp - price) / mrp) * 100).round()
        : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.orange50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_shopping_cart_rounded, color: brandOrange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Grocery Item',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                        ),
                      ),
                      Text(
                        'Dark Store Catalog & Picking Location',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: slateMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: slateMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: slateBorder),

          // Form Body
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // 1. Barcode Field with Scan Button
                  Text(
                    'Barcode / SKU (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'e.g. 8901030000000',
                            hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.slate400),
                            filled: true,
                            fillColor: AppDesignSystem.slate50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandOrange, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Bounceable(
                        onTap: _openBarcodeScannerDialog,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppDesignSystem.blue200),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: AppDesignSystem.blue700, size: 22),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Product Name
                  Text(
                    'Product Name *',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'e.g. Amul Taaza Toned Milk 500ml',
                      hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.slate400),
                      filled: true,
                      fillColor: AppDesignSystem.slate50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandOrange, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter product name';
                      if (val.trim().length < 2) return 'Product name too short';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // 3. Category Selector (Filtered Strictly for Grocery)
                  categoriesAsync.when(
                    data: (categories) {
                      final groceryCats = categories.where((c) {
                        final slug = c.slug.toLowerCase();
                        return !slug.contains('restaurant') &&
                            !slug.contains('cafe') &&
                            slug != 'fast-food-kitchen';
                      }).toList();

                      final displayList = groceryCats.isNotEmpty ? groceryCats : categories;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Grocery Category *',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w800,
                              color: slateDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId ?? (displayList.isNotEmpty ? displayList.first.id : null),
                            items: displayList.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCategoryId = val),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppDesignSystem.slate50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // 4. MRP & Selling Price with Live Discount Chip
                  Row(
                    children: [
                      // MRP
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MRP (₹) *',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _mrpController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '60',
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandOrange, width: 1.5)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'MRP is required';
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) return 'Invalid MRP';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Selling Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Price (₹) *',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                if (discountPercent > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: brandGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$discountPercent% OFF',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '55',
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandOrange, width: 1.5)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Price is required';
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) return 'Invalid price';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 5. Pack Size & Unit Selection Chips
                  Text(
                    'Pack Size / Unit',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _commonUnits.map((unit) {
                      final isSelected = _selectedUnit == unit;
                      return ChoiceChip(
                        label: Text(unit),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedUnit = unit);
                        },
                        labelStyle: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : slateDark,
                        ),
                        selectedColor: brandOrange,
                        backgroundColor: AppDesignSystem.slate100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? brandOrange : slateBorder),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 6. Rack Location & Stock Counts
                  Row(
                    children: [
                      // Rack Location
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shelf / Rack Location',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _locationController,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText: 'e.g. Aisle 2 - Shelf B',
                                hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: AppDesignSystem.slate400),
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Initial Stock
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Initial Stock',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                hintText: '20',
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                if (int.tryParse(val.trim()) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 7. Expiry Date (Optional, for Perishables)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry Date (Perishables)',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _pickExpiryDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.slate50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: slateBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedExpiryDate != null
                                          ? DateFormat('dd MMM yyyy').format(_selectedExpiryDate!)
                                          : 'Select Expiry Date',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: _selectedExpiryDate != null ? FontWeight.w800 : FontWeight.w600,
                                        color: _selectedExpiryDate != null ? slateDark : AppDesignSystem.slate400,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month_rounded, color: brandOrange, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedExpiryDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: slateMuted),
                          onPressed: () => setState(() => _selectedExpiryDate = null),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 8. Submit Button
                  Bounceable(
                    onTap: _isSubmitting ? null : _submitGroceryProduct,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isSubmitting ? AppDesignSystem.slate300 : brandOrange,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brandOrange.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Save to Dark Store',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 15),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
