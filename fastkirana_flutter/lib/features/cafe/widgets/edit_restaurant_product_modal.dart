import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../../../widgets/app_confirmation_dialog.dart';

class EditRestaurantProductModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  final String restaurantId;
  final VoidCallback onProductUpdated;
  final VoidCallback? onProductDeleted;

  const EditRestaurantProductModal({
    super.key,
    required this.item,
    required this.restaurantId,
    required this.onProductUpdated,
    this.onProductDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> item,
    required String restaurantId,
    required VoidCallback onProductUpdated,
    VoidCallback? onProductDeleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditRestaurantProductModal(
        item: item,
        restaurantId: restaurantId,
        onProductUpdated: onProductUpdated,
        onProductDeleted: onProductDeleted,
      ),
    );
  }

  @override
  ConsumerState<EditRestaurantProductModal> createState() =>
      _EditRestaurantProductModalState();
}

class _EditRestaurantProductModalState
    extends ConsumerState<EditRestaurantProductModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _mrpController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _unitController;

  late bool _isAvailable;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item['name']?.toString() ?? '');
    _priceController = TextEditingController(text: (item['price'] ?? '').toString());
    _mrpController = TextEditingController(
      text: (item['mrp'] ?? item['price'] ?? '').toString(),
    );
    _descriptionController = TextEditingController(text: item['description']?.toString() ?? '');
    _imageUrlController = TextEditingController(text: item['imageUrl']?.toString() ?? item['image']?.toString() ?? '');
    _unitController = TextEditingController(text: item['unit']?.toString() ?? '1 Serving');
    _isAvailable = item['isAvailable'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _mrpController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final dio = ref.read(dioProvider);
      final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
      final mrp = double.tryParse(_mrpController.text.trim()) ?? price;
      final itemId = widget.item['id'].toString();

      final payload = {
        'name': _nameController.text.trim(),
        'price': price,
        'mrp': mrp,
        'unit': _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : '1 Serving',
        'description': _descriptionController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'isAvailable': _isAvailable,
        if (widget.restaurantId.isNotEmpty) 'restaurantId': widget.restaurantId,
      };

      final response = await dio.patch(
        '/api/restaurant-dashboard/products/$itemId',
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
            'Dish Updated Successfully! 🍲',
            subtitle: '${_nameController.text.trim()} rates are now live on menu.',
          );
          widget.onProductUpdated();
        }
      } else {
        throw Exception(response.data?['detail'] ?? 'Failed to update dish');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'Could not update dish',
          subtitle: e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteDish() async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      icon: Icons.delete_forever_rounded,
      type: ConfirmationDialogType.danger,
      title: 'Remove Dish from Menu?',
      message: 'Are you sure you want to delete "${widget.item['name']}" from your restaurant menu?',
      confirmLabel: 'Delete Dish',
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);

    try {
      final dio = ref.read(dioProvider);
      final itemId = widget.item['id'].toString();

      final response = await dio.delete(
        '/api/restaurant-dashboard/products/$itemId',
        queryParameters: {
          if (widget.restaurantId.isNotEmpty) 'restaurantId': widget.restaurantId,
        },
        options: Options(
          headers: {
            'x-user-role': 'RESTAURANT_OWNER',
            if (widget.restaurantId.isNotEmpty) 'x-restaurant-id': widget.restaurantId,
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pop(context);
          AppToast.showSuccess(
            context,
            'Dish Deleted',
            subtitle: 'Removed from restaurant menu',
          );
          widget.onProductDeleted?.call();
        }
      } else {
        throw Exception(response.data?['detail'] ?? 'Failed to delete dish');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          'Could not delete dish',
          subtitle: e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Dish Rates & Info',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppDesignSystem.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Update price, MRP and live availability',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppDesignSystem.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Availability Switch Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isAvailable ? AppDesignSystem.green50 : AppDesignSystem.statusCancelled,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAvailable ? AppDesignSystem.emerald200 : AppDesignSystem.red200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isAvailable ? Icons.check_circle_rounded : Icons.block_flipped,
                          color: _isAvailable ? AppDesignSystem.emerald600 : AppDesignSystem.red600,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAvailable ? 'Dish is IN STOCK (Live)' : 'Marked OUT OF STOCK (86)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _isAvailable ? AppDesignSystem.green900 : AppDesignSystem.red900,
                              ),
                            ),
                            Text(
                              _isAvailable ? 'Customers can order right now' : 'Hidden from active customer menu',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _isAvailable ? AppDesignSystem.green700 : AppDesignSystem.red600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isAvailable,
                      activeThumbColor: AppDesignSystem.emerald600,
                      activeTrackColor: AppDesignSystem.emerald200,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _isAvailable = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dish Name
              Text(
                'DISH NAME *',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Dish name is required' : null,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'e.g. Special Paneer Butter Masala',
                  prefixIcon: const Icon(Icons.restaurant_rounded, size: 20, color: AppDesignSystem.slate400),
                  filled: true,
                  fillColor: AppDesignSystem.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Price & MRP Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELLING PRICE (₹) *',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Enter price';
                            final num? n = num.tryParse(val.trim());
                            if (n == null || n <= 0) return 'Valid price';
                            return null;
                          },
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                          decoration: InputDecoration(
                            hintText: '180',
                            prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20, color: AppDesignSystem.emerald600),
                            filled: true,
                            fillColor: AppDesignSystem.slate50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORIGINAL MRP (₹)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.slate500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _mrpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppDesignSystem.slate600),
                          decoration: InputDecoration(
                            hintText: '220',
                            prefixIcon: const Icon(Icons.money_off_rounded, size: 20, color: AppDesignSystem.slate400),
                            filled: true,
                            fillColor: AppDesignSystem.slate50,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unit / Portion Size
              Text(
                'PORTION / SERVING SIZE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _unitController,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Half / Full / 1 Plate / 2 Pcs',
                  prefixIcon: const Icon(Icons.scale_rounded, size: 20, color: AppDesignSystem.slate400),
                  filled: true,
                  fillColor: AppDesignSystem.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'DISH DESCRIPTION (OPTIONAL)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Fresh cottage cheese cooked in creamy tomato butter gravy',
                  filled: true,
                  fillColor: AppDesignSystem.slate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons Row: Delete & Save
              Row(
                children: [
                  Bounceable(
                    onTap: _isDeleting ? null : _deleteDish,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusCancelled,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.red200),
                      ),
                      child: Center(
                        child: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.red600),
                              )
                            : const Icon(Icons.delete_outline_rounded, color: AppDesignSystem.red600, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Bounceable(
                      onTap: _isSubmitting ? null : _saveChanges,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : Text(
                                  'Save Changes',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
