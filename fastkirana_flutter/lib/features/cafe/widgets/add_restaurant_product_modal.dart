import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

import '../../../core/theme/design_system.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../../../providers/product_provider.dart';

class AddRestaurantProductModal extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final VoidCallback onProductAdded;

  const AddRestaurantProductModal({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    required this.onProductAdded,
  });

  static Future<void> show({
    required BuildContext context,
    required String restaurantId,
    required String restaurantName,
    required VoidCallback onProductAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddRestaurantProductModal(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        onProductAdded: onProductAdded,
      ),
    );
  }

  @override
  ConsumerState<AddRestaurantProductModal> createState() =>
      _AddRestaurantProductModalState();
}

class _AddRestaurantProductModalState
    extends ConsumerState<AddRestaurantProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String _selectedFoodType = 'veg'; // 'veg', 'non-veg', 'egg'
  String _selectedUnit = '1 Plate';
  int _selectedPrepTime = 15; // minutes
  String? _selectedCategoryId;
  String? _selectedSectionId;
  List<Map<String, dynamic>> _menuSections = [];
  bool _isSubmitting = false;

  final List<String> _unitOptions = [
    '1 Plate',
    'Half',
    'Full',
    '1 Bowl',
    '1 Glass',
    '1 Cup',
    '2 Pcs',
    '4 Pcs',
    '1 Serving',
  ];

  final List<int> _prepTimeOptions = [10, 15, 20, 25, 30, 45];

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantSections();
  }

  Future<void> _fetchRestaurantSections() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/restaurants/${widget.restaurantId}/sections');
      if (res.statusCode == 200 && res.data is List) {
        if (mounted) {
          setState(() {
            _menuSections = (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (_menuSections.isNotEmpty) {
              _selectedSectionId = _menuSections.first['id']?.toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[FetchSections Error]: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitDish() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final mrpText = _mrpController.text.trim();
    final mrp = mrpText.isNotEmpty ? (double.tryParse(mrpText) ?? price) : price;

    if (price <= 0) {
      AppToast.showError(context, 'Price must be greater than ₹0');
      return;
    }

    if (price > mrp) {
      AppToast.showError(context, 'Selling price cannot exceed MRP (₹${mrp.toStringAsFixed(0)})');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final dio = ref.read(dioProvider);
      final selectedSec = _menuSections.firstWhere(
        (s) => s['id']?.toString() == _selectedSectionId,
        orElse: () => {},
      );
      final sectionId = _selectedSectionId ?? '';
      final searchTags = (selectedSec['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'price': price,
        'mrp': mrp,
        'unit': _selectedUnit,
        'restaurantId': widget.restaurantId,
        'foodType': _selectedFoodType,
        'prepTime': _selectedPrepTime,
        if (sectionId.isNotEmpty) 'sectionId': sectionId,
        if (sectionId.isNotEmpty) 'menuSectionId': sectionId,
        if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty)
          'categoryId': _selectedCategoryId,
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
        if (_imageUrlController.text.trim().isNotEmpty)
          'imageUrl': _imageUrlController.text.trim(),
        'tags': [
          if (sectionId.isNotEmpty) sectionId,
          if (selectedSec['slug'] != null) selectedSec['slug'].toString(),
          ...searchTags,
          'restaurant',
          _selectedFoodType,
          'prep-${_selectedPrepTime}m',
        ],
        'stock': 999,
        'isAvailable': true,
      };

      final response = await dio.post(
        '/api/restaurant-dashboard/products',
        data: payload,
        options: Options(
          headers: {
            'x-user-role': 'RESTAURANT_OWNER',
            if (widget.restaurantId.isNotEmpty) 'x-restaurant-id': widget.restaurantId,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context);
          AppToast.showSuccess(
            context,
            'Dish Added Successfully! 🍽️',
            subtitle: '${_nameController.text.trim()} is now active on the menu.',
          );
          widget.onProductAdded();
        }
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to add dish');
      }
    } catch (e) {
      debugPrint('[AddRestaurantDish Error]: $e');
      if (mounted) {
        AppToast.showError(
          context,
          'Could not add dish',
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
                    color: AppDesignSystem.rose50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: primaryRed, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add New Dish',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                        ),
                      ),
                      Text(
                        widget.restaurantName,
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
                  // 1. Food Type Selector (Veg / Non-Veg / Egg)
                  Text(
                    'Food Type',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildFoodTypeOption(
                        type: 'veg',
                        label: 'Pure Veg',
                        badgeColor: const Color(0xFF10B981),
                        icon: Icons.eco_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildFoodTypeOption(
                        type: 'non-veg',
                        label: 'Non-Veg',
                        badgeColor: const Color(0xFFEF4444),
                        icon: Icons.kebab_dining_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildFoodTypeOption(
                        type: 'egg',
                        label: 'Contains Egg',
                        badgeColor: const Color(0xFFF59E0B),
                        icon: Icons.egg_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. Dish Name
                  Text(
                    'Dish Name *',
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
                      hintText: 'e.g. Kadai Paneer, Butter Naan, Cold Coffee',
                      hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), color: AppDesignSystem.slate400),
                      filled: true,
                      fillColor: AppDesignSystem.slate50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter dish name';
                      if (val.trim().length < 2) return 'Dish name too short';
                      return null;
                    },
                  ),

                  // 3. Restaurant Menu Section Selector (ID-Based)
                  if (_menuSections.isNotEmpty) ...[
                    Text(
                      'Menu Section *',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSectionId ?? _menuSections.first['id']?.toString(),
                      items: _menuSections.map((s) {
                        final emoji = s['emoji']?.toString() ?? '🍽️';
                        final title = s['title']?.toString() ?? 'Section';
                        final id = s['id']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(
                            '$emoji $title',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSectionId = val),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppDesignSystem.slate50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 4. Category Selector (Filtered for Restaurant/Food)
                  categoriesAsync.when(
                    data: (categories) {
                      final restCats = categories.where((c) {
                        final slug = c.slug.toLowerCase();
                        return slug.contains('restaurant') ||
                            slug.contains('cafe') ||
                            slug.contains('food') ||
                            slug.contains('kitchen') ||
                            slug.contains('snack') ||
                            slug.contains('beverage') ||
                            slug.contains('drink');
                      }).toList();

                      final displayList = restCats.isNotEmpty ? restCats : categories;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menu Category',
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

                  // 4. Pricing Row (Selling Price & MRP)
                  Row(
                    children: [
                      // Selling Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selling Price (₹) *',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '199',
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final numVal = double.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // MRP (Optional / Cross price)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MRP (₹) (Optional)',
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
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '240',
                                filled: true,
                                fillColor: AppDesignSystem.slate50,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryRed, width: 1.5)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 5. Serving Unit Selection Chips
                  Text(
                    'Serving Portion / Unit',
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
                    children: _unitOptions.map((unit) {
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
                        selectedColor: primaryRed,
                        backgroundColor: AppDesignSystem.slate100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? primaryRed : slateBorder),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 6. Estimated Cooking / Preparation Time
                  Text(
                    'Estimated Cooking Time (Minutes)',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _prepTimeOptions.map((time) {
                      final isSelected = _selectedPrepTime == time;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Bounceable(
                            onTap: () => setState(() => _selectedPrepTime = time),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppDesignSystem.rose50 : AppDesignSystem.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? primaryRed : slateBorder,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$time m',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                    color: isSelected ? primaryRed : slateDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 7. Description / Chef Notes (Optional)
                  Text(
                    'Description / Ingredients (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Rich cottage cheese cooked in creamy tomato butter gravy with aromatic spices.',
                      hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate400),
                      filled: true,
                      fillColor: AppDesignSystem.slate50,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: slateBorder)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 8. Submit Button
                  Bounceable(
                    onTap: _isSubmitting ? null : _submitDish,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _isSubmitting ? AppDesignSystem.slate300 : primaryRed,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withValues(alpha: 0.25),
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
                                    'Add Dish to Menu',
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

  Widget _buildFoodTypeOption({
    required String type,
    required String label,
    required Color badgeColor,
    required IconData icon,
  }) {
    final isSelected = _selectedFoodType == type;

    return Expanded(
      child: Bounceable(
        onTap: () => setState(() => _selectedFoodType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? badgeColor.withValues(alpha: 0.1) : AppDesignSystem.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? badgeColor : slateBorder,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? badgeColor : AppDesignSystem.slate400, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? badgeColor : slateDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
