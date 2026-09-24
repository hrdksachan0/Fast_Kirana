import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/config/app_config.dart';
import '../../../providers/product_provider.dart';

class EditPickerProductModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onProductUpdated;

  const EditPickerProductModal({
    super.key,
    required this.product,
    required this.onProductUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> product,
    required VoidCallback onProductUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditPickerProductModal(
        product: product,
        onProductUpdated: onProductUpdated,
      ),
    );
  }

  @override
  ConsumerState<EditPickerProductModal> createState() => _EditPickerProductModalState();
}

class _EditPickerProductModalState extends ConsumerState<EditPickerProductModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mrpController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _unitController;
  late bool _isAvailable;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _variants = [];

  static const Color brandOrange = Color(0xFFEA580C);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final num currentMrp = (p['mrp'] is num)
        ? (p['mrp'] as num)
        : (num.tryParse(p['mrp']?.toString() ?? '') ?? (p['price'] is num ? (p['price'] as num) : 0));
    final num currentPrice = (p['price'] is num)
        ? (p['price'] as num)
        : (num.tryParse(p['price']?.toString() ?? '0') ?? 0);
    final int currentStock = (p['stock'] is num)
        ? (p['stock'] as num).toInt()
        : (int.tryParse(p['stock']?.toString() ?? '20') ?? 20);

    _mrpController = TextEditingController(text: currentMrp > 0 ? currentMrp.toStringAsFixed(currentMrp.truncateToDouble() == currentMrp ? 0 : 2) : '');
    _priceController = TextEditingController(text: currentPrice > 0 ? currentPrice.toStringAsFixed(currentPrice.truncateToDouble() == currentPrice ? 0 : 2) : '');
    _stockController = TextEditingController(text: currentStock.toString());
    _unitController = TextEditingController(text: (p['unit'] ?? p['selectedVariant'] ?? '1 pc').toString());
    _isAvailable = p['isAvailable'] != false && currentStock > 0;

    final rawVars = p['variants'];
    if (rawVars is List) {
      _variants = rawVars.whereType<Map>().map((v) {
        final double vPrice = (v['price'] is num)
            ? (v['price'] as num).toDouble()
            : (double.tryParse(v['price']?.toString() ?? '0') ?? 0.0);
        final double vMrp = (v['mrp'] is num)
            ? (v['mrp'] as num).toDouble()
            : (double.tryParse(v['mrp']?.toString() ?? '') ?? vPrice);
        final int vStock = (v['stock'] is num)
            ? (v['stock'] as num).toInt()
            : (int.tryParse(v['stock']?.toString() ?? '20') ?? 20);
        return <String, dynamic>{
          'name': (v['name'] ?? '').toString(),
          'price': vPrice,
          'mrp': vMrp > 0 ? vMrp : vPrice,
          'stock': vStock,
        };
      }).toList();
    }
  }

  @override
  void dispose() {
    _mrpController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  int _calculateDiscount(double mrp, double price) {
    if (mrp <= 0 || price <= 0 || price > mrp) return 0;
    return (((mrp - price) / mrp) * 100).round();
  }

  void _removeVariant(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _variants.removeAt(index);
    });
  }

  Future<void> _openVariantDialog({Map<String, dynamic>? initial, int? index}) async {
    final nameController = TextEditingController(text: initial?['name']?.toString() ?? '');
    final mrpController = TextEditingController(
      text: initial?['mrp'] != null
          ? ((initial!['mrp'] is num)
              ? (initial['mrp'] as num).toStringAsFixed((initial['mrp'] as num).truncateToDouble() == initial['mrp'] ? 0 : 2)
              : initial['mrp'].toString())
          : '',
    );
    final priceController = TextEditingController(
      text: initial?['price'] != null
          ? ((initial!['price'] is num)
              ? (initial['price'] as num).toStringAsFixed((initial['price'] as num).truncateToDouble() == initial['price'] ? 0 : 2)
              : initial['price'].toString())
          : '',
    );
    final stockController = TextEditingController(
      text: initial?['stock'] != null ? initial!['stock'].toString() : '20',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final dMrp = double.tryParse(mrpController.text.trim()) ?? 0.0;
            final dPrice = double.tryParse(priceController.text.trim()) ?? 0.0;
            final dDiscount = _calculateDiscount(dMrp, dPrice);
            final bool isPriceInvalid = dPrice > dMrp && dMrp > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.layers_rounded, color: brandOrange, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      index != null ? 'Edit Pack Variant' : 'Add Pack Variant',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variant Name / Pack Size',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateMuted),
                      ),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: nameController,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'e.g. 500 g, 1 kg, Pack of 2',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: slateBorder),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MRP (₹)',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateMuted),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: mrpController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    hintText: '100',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: slateBorder),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final numVal = double.tryParse(v);
                                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price (₹)',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: brandOrange),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: brandOrange),
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    hintText: '85',
                                    filled: true,
                                    fillColor: const Color(0xFFFFF7ED),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isPriceInvalid ? Colors.red : const Color(0xFFFED7AA),
                                      ),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final numVal = double.tryParse(v);
                                    if (numVal == null || numVal <= 0) return 'Must be > 0';
                                    final m = double.tryParse(mrpController.text.trim()) ?? 0;
                                    if (numVal > m && m > 0) return 'Cannot > MRP';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stock Units',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateMuted),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: stockController,
                                  keyboardType: TextInputType.number,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                                  decoration: InputDecoration(
                                    hintText: '20',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: slateBorder),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final numVal = int.tryParse(v);
                                    if (numVal == null || numVal < 0) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discount',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateMuted),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isPriceInvalid ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isPriceInvalid ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    isPriceInvalid ? '⚠️ > MRP' : '$dDiscount% OFF',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: isPriceInvalid ? Colors.red : const Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: slateMuted, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final p = double.parse(priceController.text.trim());
                    final m = double.parse(mrpController.text.trim());
                    final s = int.parse(stockController.text.trim());
                    final n = nameController.text.trim();

                    final updated = <String, dynamic>{
                      'name': n,
                      'price': p,
                      'mrp': m,
                      'stock': s,
                    };

                    setState(() {
                      if (index != null && index >= 0 && index < _variants.length) {
                        _variants[index] = updated;
                      } else {
                        _variants.add(updated);
                      }
                    });
                    Navigator.pop(dialogCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Save Variant', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitPriceUpdate() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    final mrp = double.tryParse(_mrpController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final unit = _unitController.text.trim();

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

    // Validate variants if any
    for (final v in _variants) {
      final vName = (v['name'] ?? '').toString().trim();
      final double vPrice = (v['price'] as num?)?.toDouble() ?? 0.0;
      final double vMrp = (v['mrp'] as num?)?.toDouble() ?? vPrice;
      if (vName.isEmpty) {
        AppToast.showError(context, 'All variants must have a name');
        return;
      }
      if (vPrice <= 0) {
        AppToast.showError(context, 'Variant "$vName" price must be > ₹0');
        return;
      }
      if (vPrice > vMrp && vMrp > 0) {
        AppToast.showError(context, 'Variant "$vName" price cannot exceed MRP');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final dio = ref.read(dioProvider);
      final productId = (widget.product['productId'] ?? widget.product['id'] ?? '').toString();
      final barcode = widget.product['barcode']?.toString();

      final payload = <String, dynamic>{
        'productId': productId,
        if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
        'mrp': mrp,
        'price': price,
        'stock': stock,
        'unit': unit.isNotEmpty ? unit : '1 pc',
        'isAvailable': _isAvailable && stock > 0,
        'variants': _variants,
        if (AppConfig.darkstoreId.isNotEmpty) 'storeId': AppConfig.darkstoreId,
      };

      final response = await dio.patch(
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
          final discount = _calculateDiscount(mrp, price);
          AppToast.showSuccess(
            context,
            'Price & Variants Updated! 🛒',
            subtitle: '${widget.product['name']} set to ₹$price ($discount% OFF)',
          );
          ref.invalidate(productsProvider(null));
          ref.invalidate(homeProductCatalogProvider);
          widget.onProductUpdated();
        }
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to update price');
      }
    } catch (e) {
      debugPrint('[EditPickerProduct Error]: $e');
      if (mounted) {
        AppToast.showError(
          context,
          'Could not update price',
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final p = widget.product;
    final String name = (p['name'] ?? p['title'] ?? 'Grocery Product').toString();
    final String imgUrl = (p['imageUrl'] ?? p['image'] ?? '').toString();

    final currentMrp = double.tryParse(_mrpController.text.trim()) ?? 0.0;
    final currentPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final discount = _calculateDiscount(currentMrp, currentPrice);
    final bool isPriceInvalid = currentPrice > currentMrp && currentMrp > 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Icon(Icons.sell_rounded, color: brandOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Grocery Pricing',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 16),
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                        ),
                      ),
                      Text(
                        'FastKirana Dark Store Warehouse',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: slateMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: slateMuted, size: 22),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: slateBorder),

          // Content Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Summary Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: slateBorder),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: imgUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      fit: BoxFit.contain,
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Text('📦', style: TextStyle(fontSize: 22)),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('📦', style: TextStyle(fontSize: 22)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (p['barcode'] != null && p['barcode'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Barcode: ${p['barcode']}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: Responsive.scaledFontSize(context, 10.5),
                                      color: slateMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Price & MRP Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MRP
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MRP (₹)',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: slateMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _mrpController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: '100',
                                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: slateMuted),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: slateBorder),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final numVal = double.tryParse(v);
                                  if (numVal == null || numVal <= 0) return 'Must be > 0';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Selling Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selling Price (₹)',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: brandOrange,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: brandOrange),
                                decoration: InputDecoration(
                                  hintText: '85',
                                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: brandOrange),
                                  filled: true,
                                  fillColor: const Color(0xFFFFF7ED),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: isPriceInvalid ? Colors.red : const Color(0xFFFED7AA)),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final numVal = double.tryParse(v);
                                  if (numVal == null || numVal <= 0) return 'Must be > 0';
                                  final mrpVal = double.tryParse(_mrpController.text.trim()) ?? 0;
                                  if (numVal > mrpVal && mrpVal > 0) return 'Cannot > MRP';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Discount Live Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isPriceInvalid ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPriceInvalid ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPriceInvalid ? '⚠️ Price cannot exceed MRP' : 'Calculated Discount:',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12),
                              fontWeight: FontWeight.w700,
                              color: isPriceInvalid ? Colors.red : const Color(0xFF047857),
                            ),
                          ),
                          if (!isPriceInvalid)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: brandGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$discount% OFF',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Stock & Unit Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stock
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stock Units',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: slateMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '20',
                                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 16, color: slateMuted),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: slateBorder),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Unit
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit / Pack',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: slateMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _unitController,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '1 pc, 500g',
                                  prefixIcon: const Icon(Icons.scale_rounded, size: 16, color: slateMuted),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: slateBorder),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Product Variants Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: slateBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.layers_rounded, color: brandOrange, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pack Variants (${_variants.length})',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12.5),
                                      fontWeight: FontWeight.w800,
                                      color: slateDark,
                                    ),
                                  ),
                                ],
                              ),
                              Bounceable(
                                onTap: () => _openVariantDialog(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFED7AA)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_rounded, size: 14, color: brandOrange),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Add Variant',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: brandOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_variants.isEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: slateBorder),
                              ),
                              child: Text(
                                'No pack variants configured. The base price and unit above will apply.',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  color: slateMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _variants.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final v = _variants[idx];
                                final vName = (v['name'] ?? '').toString();
                                final double vPrice = (v['price'] as num?)?.toDouble() ?? 0.0;
                                final double vMrp = (v['mrp'] as num?)?.toDouble() ?? vPrice;
                                final int vStock = (v['stock'] as num?)?.toInt() ?? 0;
                                final int vDiscount = _calculateDiscount(vMrp, vPrice);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: slateBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              vName,
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                                fontWeight: FontWeight.w800,
                                                color: slateDark,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  '₹${vPrice.toInt() == vPrice ? vPrice.toInt() : vPrice.toStringAsFixed(2)}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: Responsive.scaledFontSize(context, 12),
                                                    fontWeight: FontWeight.w900,
                                                    color: brandOrange,
                                                  ),
                                                ),
                                                if (vMrp > vPrice) ...[
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '₹${vMrp.toInt() == vMrp ? vMrp.toInt() : vMrp.toStringAsFixed(2)}',
                                                    style: GoogleFonts.inter(
                                                      fontSize: Responsive.scaledFontSize(context, 10),
                                                      color: slateMuted,
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                  if (vDiscount > 0) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFD1FAE5),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        '$vDiscount% OFF',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w900,
                                                          color: const Color(0xFF047857),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                                const SizedBox(width: 8),
                                                Text(
                                                  '• Stock: $vStock',
                                                  style: GoogleFonts.inter(
                                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                                    color: slateMuted,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: slateMuted),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _openVariantDialog(initial: v, index: idx),
                                      ),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _removeVariant(idx),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Available in Store Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: slateBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'In Stock for Customers',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                Text(
                                  'Enables or disables visibility on FastKirana app',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    color: slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isAvailable,
                            activeTrackColor: brandGreen.withValues(alpha: 0.5),
                            activeThumbColor: brandGreen,
                            onChanged: (v) => setState(() => _isAvailable = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    Bounceable(
                      onTap: _isSubmitting || isPriceInvalid ? null : _submitPriceUpdate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: brandOrange.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
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
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Save New Pricing',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 14.5),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
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
          ),
        ],
      ),
    );
  }
}
