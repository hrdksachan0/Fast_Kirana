import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/order_item_helper.dart';
import '../../core/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorConsoleScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final String? initialVendorId;
  final bool isVendorSelf;
  const VendorConsoleScreen({
    super.key,
    this.showAppBar = true,
    this.initialVendorId,
    this.isVendorSelf = false,
  });

  @override
  ConsumerState<VendorConsoleScreen> createState() => _VendorConsoleScreenState();
}

class _VendorConsoleScreenState extends ConsumerState<VendorConsoleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingVendors = true;
  bool _isLoadingDetails = false;
  List<Map<String, dynamic>> _vendors = [];
  String? _selectedVendorId;

  // Selected Vendor Details
  Map<String, dynamic>? _vendorProfile;
  Map<String, dynamic> _kpis = {
    'totalProducts': 0,
    'totalUnitsSold': 0,
    'totalPayableAmount': 0.0,
    'totalPaidInPeriod': 0.0,
    'pendingBalance': 0.0,
    'totalPaidLifetime': 0.0,
    'lowStockCount': 0,
  };
  List<Map<String, dynamic>> _itemizedSales = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _liveOrders = [];
  bool _isLoadingLiveOrders = false;
  Timer? _liveOrdersPollingTimer;

  // Search filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Order quantities for WhatsApp PO (productId -> qty)
  final Map<String, int> _poQuantities = {};

  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateCard = Color(0xFF1E293B);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);
  static const Color brandOrange = Color(0xFFEA580C);
  static const Color brandGreen = Color(0xFF10B981);
  static const Color primaryRed = Color(0xFFE20A22);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    if (widget.initialVendorId != null && widget.initialVendorId!.isNotEmpty) {
      _selectedVendorId = widget.initialVendorId;
      _fetchVendorDetails(widget.initialVendorId!);
      _fetchLiveOrders(widget.initialVendorId!);
      if (!widget.isVendorSelf) {
        _fetchVendors();
      } else {
        _isLoadingVendors = false;
      }
    } else {
      _fetchVendors();
    }

    // Auto-refresh live orders every 15s (Kitchen/Store KDS polling)
    _liveOrdersPollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _selectedVendorId != null) {
        _fetchLiveOrders(_selectedVendorId!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveOrdersPollingTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveOrders(String vendorId, {bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingLiveOrders = true);
    }
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/vendors/$vendorId/live-orders?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['orders'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
        if (mounted) {
          setState(() {
            _liveOrders = list;
          });
        }
      }
    } catch (e) {
      debugPrint('[VendorConsole] Error fetching live orders: $e');
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoadingLiveOrders = false);
      }
    }
  }

  String _resolveImgUrl(dynamic rawImg) {
    if (rawImg == null) return '';
    final str = rawImg.toString().trim();
    if (str.isEmpty) return '';
    if (str.startsWith('http://') || str.startsWith('https://') || str.startsWith('data:image')) {
      return str;
    }
    if (str.startsWith('/')) {
      return 'https://www.fastkirana.in$str';
    }
    return '${AppConfig.apiBaseUrl}/$str';
  }

  Future<void> _fetchVendors() async {
    setState(() => _isLoadingVendors = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/vendors?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null) {
        final list = (res.data['vendors'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];

        setState(() {
          _vendors = list;
          if (list.isNotEmpty && _selectedVendorId == null) {
            _selectedVendorId = list.first['id']?.toString();
          }
        });

        if (_selectedVendorId != null) {
          await _fetchVendorDetails(_selectedVendorId!);
          await _fetchLiveOrders(_selectedVendorId!);
        }
      }
    } catch (e) {
      debugPrint('[VendorConsole] Error fetching vendors: $e');
    } finally {
      if (mounted) setState(() => _isLoadingVendors = false);
    }
  }

  Future<void> _fetchVendorDetails(String vendorId) async {
    setState(() => _isLoadingDetails = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/vendors/$vendorId?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final vProfile = data['vendor'] != null ? Map<String, dynamic>.from(data['vendor']) : null;
        final kpisMap = data['kpis'] != null ? Map<String, dynamic>.from(data['kpis']) : <String, dynamic>{};
        final salesList = (data['itemizedSales'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
        final prodsList = (data['products'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
        final paysList = (data['payouts'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
        final lowList = (data['lowStockItems'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];

        // Preload default PO quantities
        for (final item in lowList) {
          final id = item['id']?.toString() ?? '';
          final stock = (item['stock'] as num?)?.toInt() ?? 0;
          final minStock = (item['minStock'] as num?)?.toInt() ?? 5;
          _poQuantities[id] = (minStock * 2 - stock).clamp(10, 500);
        }

        if (mounted) {
          setState(() {
            _vendorProfile = vProfile;
            _kpis = kpisMap;
            _itemizedSales = salesList;
            _products = prodsList;
            _payouts = paysList;
            _lowStockItems = lowList;
          });
        }
      }
    } catch (e) {
      debugPrint('[VendorConsole] Error fetching vendor details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _sendWhatsAppPO() async {
    if (_vendorProfile == null) return;
    final phone = (_vendorProfile!['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor phone number not found in profile!'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_lowStockItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No low stock items to order!'), backgroundColor: Colors.blue),
      );
      return;
    }

    final vendorName = _vendorProfile!['name'] ?? 'Vendor';
    final vendorCode = _vendorProfile!['vendorCode'] ?? 'VND';
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('*PURCHASE ORDER - FASTKIRANA*');
    buffer.writeln('Vendor: *$vendorName* ($vendorCode)');
    buffer.writeln('Date: $dateStr');
    buffer.writeln('Store: FastKirana Dark Store Hub\n');
    buffer.writeln('*Items Required Immediately:*');

    int idx = 1;
    for (final item in _lowStockItems) {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? 'Product';
      final unit = (item['unit'] ?? '').toString().trim();
      final qty = _poQuantities[id] ?? 10;
      final stock = item['stock'] ?? 0;
      final unitLabel = unit.isNotEmpty ? ' ($unit)' : '';
      buffer.writeln('$idx. *$name$unitLabel* - *Qty: $qty* (Current Stock: $stock)');
      idx++;
    }

    buffer.writeln('\nPlease confirm dispatch time and estimated invoice. Thank you!');
    buffer.writeln('— FastKirana Procurement Team');

    final cleanPhone = phone.length == 10 ? '91$phone' : phone;
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp PO text copied to clipboard!'), backgroundColor: brandGreen),
        );
      }
    }
  }

  void _openRecordPayoutModal() {
    if (_vendorProfile == null || _selectedVendorId == null) return;

    final amountController = TextEditingController();
    final txnController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'UPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Vendor Payout',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark),
                      ),
                      Text(
                        'Vendor: ${_vendorProfile!['name']}',
                        style: GoogleFonts.inter(fontSize: 12, color: slateMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: slateMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text('Payout Amount (₹) *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark)),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'Enter amount paid',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              Text('Payment Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark)),
              const SizedBox(height: 6),
              Row(
                children: ['UPI', 'BANK_TRANSFER', 'CASH', 'CHEQUE'].map((m) {
                  final isSel = method == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(m.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isSel ? Colors.white : slateDark)),
                      selected: isSel,
                      selectedColor: primaryRed,
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (_) => setModalState(() => method = m),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('UTR / Reference ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark)),
              const SizedBox(height: 6),
              TextField(
                controller: txnController,
                decoration: InputDecoration(
                  hintText: 'Optional bank ref / UPI txn id',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              Text('Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'e.g. Weekly settlement cleared',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount!'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    try {
                      final dio = ref.read(dioProvider);
                      final res = await dio.post(
                        '/api/vendors/$_selectedVendorId/payouts',
                        data: {
                          'amount': amt,
                          'paymentMethod': method,
                          'transactionId': txnController.text.trim(),
                          'notes': notesController.text.trim(),
                        },
                      );

                      if (res.statusCode == 200) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Recorded payout of ₹$amt!'), backgroundColor: brandGreen),
                          );
                        }
                        if (_selectedVendorId != null) {
                          _fetchVendorDetails(_selectedVendorId!);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to record payout: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Text('Confirm Payout', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleVendorSignOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text('Are you sure you want to sign out from the Vendor Partner Portal?', style: GoogleFonts.inter(fontSize: 13, color: slateMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: slateMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await SecureStorage.delete('user_role');
      await SecureStorage.delete('vendor_id');
      await SecureStorage.delete('vendor_data');
      await SecureStorage.delete('auth_token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('vendor_id');
      await prefs.remove('vendor_data');
      await prefs.remove('auth_token');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/vendor/login', (route) => false);
      }
    }
  }

  void _showEditPriceBottomSheet(Map<String, dynamic> prod) {
    HapticFeedback.lightImpact();
    final String prodId = prod['id']?.toString() ?? '';
    final String prodName = prod['name']?.toString() ?? 'Product';
    final String unit = prod['unit']?.toString() ?? '';
    final double initialCost = (prod['costPrice'] as num?)?.toDouble() ?? (prod['cost'] as num?)?.toDouble() ?? 0.0;
    final double initialPrice = (prod['price'] as num?)?.toDouble() ?? 0.0;
    final double initialMrp = (prod['mrp'] as num?)?.toDouble() ?? initialPrice;
    final int initialStock = (prod['stock'] as num?)?.toInt() ?? 0;

    final costCtrl = TextEditingController(text: initialCost > 0 ? initialCost.toStringAsFixed(initialCost.truncateToDouble() == initialCost ? 0 : 2) : '');
    final sellCtrl = TextEditingController(text: initialPrice > 0 ? initialPrice.toStringAsFixed(initialPrice.truncateToDouble() == initialPrice ? 0 : 2) : '');
    final mrpCtrl = TextEditingController(text: initialMrp > 0 ? initialMrp.toStringAsFixed(initialMrp.truncateToDouble() == initialMrp ? 0 : 2) : '');
    final stockCtrl = TextEditingController(text: initialStock.toString());

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final double costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
          final double sellVal = double.tryParse(sellCtrl.text.trim()) ?? 0.0;
          final double mrpVal = double.tryParse(mrpCtrl.text.trim()) ?? sellVal;
          final double profit = sellVal - costVal;
          final double marginPct = sellVal > 0 ? (profit / sellVal) * 100 : 0.0;

          Color marginColor = slateMuted;
          String marginLabel = 'Break-even';
          if (profit > 0) {
            marginColor = brandGreen;
            marginLabel = '+₹${profit.toStringAsFixed(1)} profit (${marginPct.toStringAsFixed(1)}% margin)';
          } else if (profit < 0) {
            marginColor = Colors.red;
            marginLabel = '-₹${(-profit).toStringAsFixed(1)} loss (Cost > Selling price!)';
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Rates & Stock',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark),
                            ),
                            Text(
                              prodName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: slateMuted),
                            ),
                          ],
                        ),
                      ),
                      if (unit.isNotEmpty)
                        OrderItemHelper.buildWeightBadge(context, unit),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Live Margin Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: profit >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: profit >= 0 ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          profit >= 0 ? Icons.trending_up_rounded : Icons.warning_amber_rounded,
                          color: marginColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Real-Time Margin Calculation',
                                style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: slateMuted),
                              ),
                              Text(
                                marginLabel,
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: marginColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Cost Price Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cost Price (₹)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.blue.shade800),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: costCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '0.00',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Supplier supply rate', style: GoogleFonts.inter(fontSize: 9.5, color: slateMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Selling Price Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selling Price (₹)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: slateDark),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: sellCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '0.00',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Customer retail price', style: GoogleFonts.inter(fontSize: 9.5, color: slateMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // MRP Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Printed MRP (₹)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: mrpCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                hintText: '0.00',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Stock Quantity Input
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Stock',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: slateDark),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'units',
                                hintText: '0',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final dio = ref.read(dioProvider);
                          final res = await dio.patch(
                            '/api/vendors/products/$prodId/prices',
                            data: {
                              'costPrice': costVal,
                              'price': sellVal,
                              'mrp': mrpVal,
                              'stock': int.tryParse(stockCtrl.text.trim()) ?? initialStock,
                            },
                          );
                          if (res.statusCode == 200) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Updated rates for "$prodName"!'),
                                  backgroundColor: brandGreen,
                                ),
                              );
                            }
                            if (_selectedVendorId != null) {
                              _fetchVendorDetails(_selectedVendorId!);
                            }
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update rates: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Save Rates', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: slateDark,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.isVendorSelf ? 'Vendor Portal' : 'Vendor Console',
                        style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: widget.isVendorSelf ? const Color(0xFF10B981).withValues(alpha: 0.2) : primaryRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: widget.isVendorSelf ? const Color(0xFF10B981).withValues(alpha: 0.4) : primaryRed.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.isVendorSelf ? 'LIVE' : 'ADMIN',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: widget.isVendorSelf ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.isVendorSelf
                        ? (_vendorProfile?['name'] ?? 'Supplier Hub · Live')
                        : 'Live Dispatch, Sales & Inventory',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () {
                    if (widget.isVendorSelf && _selectedVendorId != null) {
                      _fetchVendorDetails(_selectedVendorId!);
                      _fetchLiveOrders(_selectedVendorId!);
                    } else {
                      _fetchVendors();
                    }
                  },
                ),
                if (widget.isVendorSelf)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                    tooltip: 'Sign Out',
                    onPressed: _handleVendorSignOut,
                  ),
              ],
            )
          : null,
      body: (_isLoadingVendors && !widget.isVendorSelf)
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : (!widget.isVendorSelf && _vendors.isEmpty)
              ? _buildEmptyVendorsView()
              : Column(
                  children: [
                    // Vendor Selector Header Strip
                    _buildVendorSelectorStrip(),

                    // Financial Summary Banner
                    _buildFinancialKPIBanner(),

                    // Navigation Tabs
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: primaryRed,
                        unselectedLabelColor: slateMuted,
                        indicatorColor: primaryRed,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerColor: const Color(0xFFF1F5F9),
                        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
                        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🔔 Live Orders'),
                                if (_liveOrders.where((o) => o['status'] != 'DELIVERED').isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: primaryRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_liveOrders.where((o) => o['status'] != 'DELIVERED').length}',
                                      style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: '📊 Sales (Bikri)'),
                          Tab(text: '📦 Products (${_products.length})'),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📱 Reorder'),
                                if (_lowStockItems.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                    child: Text('${_lowStockItems.length}', style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: '💵 Payouts'),
                        ],
                      ),
                    ),

                    // Search Strip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.inter(fontSize: 12.5, color: slateDark, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search product name, weight or barcode...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: slateMuted),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: slateMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: slateMuted),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          ),
                        ),
                      ),
                    ),

                    // Tab Content
                    Expanded(
                      child: _isLoadingDetails
                          ? const Center(child: CircularProgressIndicator(color: primaryRed))
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildLiveOrdersTab(),
                                _buildSalesTab(),
                                _buildProductsTab(),
                                _buildReorderTab(),
                                _buildPayoutsTab(),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyVendorsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.store_mall_directory_rounded, size: 48, color: slateMuted),
            ),
            const SizedBox(height: 16),
            Text('No Vendors Registered Yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark)),
            const SizedBox(height: 6),
            Text('Vendors mapped in backend will appear here with sales and attached products.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: slateMuted)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primaryRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
              onPressed: _fetchVendors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorSelectorStrip() {
    if (widget.isVendorSelf) {
      final name = _vendorProfile?['name'] ?? _vendorProfile?['companyName'] ?? 'Supplier Partner';
      final phone = _vendorProfile?['phone'] ?? '';
      final code = _vendorProfile?['vendorCode'] ?? '';
      return Container(
        color: slateDark,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: slateCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryRed.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.storefront_rounded, color: primaryRed, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 12, color: brandGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Authorized Supplier Partner',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('·  $phone', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: slateDark,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _vendors.map((v) {
                final id = v['id']?.toString() ?? '';
                final isSelected = id == _selectedVendorId;
                final name = v['name'] ?? 'Vendor';
                final code = v['vendorCode'] ?? 'VND';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Bounceable(
                    onTap: () {
                      if (_selectedVendorId == id) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedVendorId = id);
                      _fetchVendorDetails(id);
                      _fetchLiveOrders(id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFFE20A22), Color(0xFFFF3B30)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : const Color(0xFF334155),
                          width: 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_vendorProfile != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if ((_vendorProfile!['phone'] ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 5),
                        Text(
                          _vendorProfile!['phone'],
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE2E8F0)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if ((_vendorProfile!['companyName'] ?? _vendorProfile!['category'] ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.category_rounded, size: 12, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 5),
                        Text(
                          _vendorProfile!['companyName'] ?? _vendorProfile!['category'] ?? 'Supplier',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE2E8F0)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialKPIBanner() {
    final units = (_kpis['totalUnitsSold'] as num?)?.toInt() ?? 0;
    final payable = (_kpis['totalPayableAmount'] as num?)?.toDouble() ?? 0.0;
    final balance = (_kpis['pendingBalance'] as num?)?.toDouble() ?? 0.0;
    final productsCount = (_kpis['totalProducts'] as num?)?.toInt() ?? _products.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: _buildKPITile(
              label: 'ATTACHED',
              value: '$productsCount items',
              icon: Icons.layers_rounded,
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFDBEAFE),
              textColor: const Color(0xFF1D4ED8),
              iconColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKPITile(
              label: 'SOLD (BIKRI)',
              value: '$units units',
              icon: Icons.shopping_bag_rounded,
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFFA7F3D0),
              textColor: const Color(0xFF047857),
              iconColor: const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKPITile(
              label: 'PAYABLE',
              value: '₹${payable.toStringAsFixed(0)}',
              icon: Icons.payments_rounded,
              bgColor: const Color(0xFFF8FAFC),
              borderColor: const Color(0xFFE2E8F0),
              textColor: slateDark,
              iconColor: slateDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildKPITile(
              label: 'BALANCE DUE',
              value: '₹${balance.toStringAsFixed(0)}',
              icon: Icons.account_balance_wallet_rounded,
              bgColor: const Color(0xFFFFF7ED),
              borderColor: const Color(0xFFFED7AA),
              textColor: const Color(0xFFC2410C),
              iconColor: const Color(0xFFEA580C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPITile({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: textColor.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Product-Wise Sales (Bikri) ──
  Widget _buildSalesTab() {
    final filtered = _itemizedSales.where((it) {
      if (_searchQuery.isEmpty) return true;
      final name = (it['name'] ?? '').toString().toLowerCase();
      final barcode = (it['barcode'] ?? '').toString().toLowerCase();
      final unit = (it['unit'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || barcode.contains(_searchQuery) || unit.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No product sales recorded in period', style: GoogleFonts.inter(color: slateMuted, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = filtered[index];
        final name = item['name'] ?? 'Product';
        final units = (item['unitsSold'] as num?)?.toInt() ?? 0;
        final cost = (item['unitCostPrice'] as num?)?.toDouble() ?? 0.0;
        final total = (item['totalPayable'] as num?)?.toDouble() ?? 0.0;
        final stock = (item['currentStock'] as num?)?.toInt() ?? 0;
        final imgUrl = _resolveImgUrl(item['imageUrl']);
        final weightVariant = OrderItemHelper.resolveWeightOrVariant(item, name);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: slateBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo Thumbnail
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: imgUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 22),
                        )
                      : const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 22),
                ),
              ),
              const SizedBox(width: 10),

              // Title, Unit Badge & Stock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (weightVariant.isNotEmpty) ...[
                          OrderItemHelper.buildWeightBadge(context, weightVariant),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: stock <= 5 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stock: $stock',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: stock <= 5 ? Colors.red : slateMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Units Sold & Cost Price Payable
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: units > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$units SOLD',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: units > 0 ? const Color(0xFF15803D) : slateMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: slateDark),
                  ),
                  Text(
                    '@ ₹${cost.toStringAsFixed(0)}/unit',
                    style: GoogleFonts.inter(fontSize: 9.5, color: slateMuted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 2: Attached Products (Catalog) ──
  Widget _buildProductsTab() {
    final filtered = _products.where((p) {
      if (_searchQuery.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      final unit = (p['unit'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || barcode.contains(_searchQuery) || unit.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text('No attached products found for this vendor', style: GoogleFonts.inter(color: slateMuted, fontSize: 13)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final prod = filtered[index];
        final name = prod['name'] ?? 'Product';
        final barcode = prod['barcode'] ?? '';
        final cost = (prod['costPrice'] as num?)?.toDouble() ?? 0.0;
        final price = (prod['price'] as num?)?.toDouble() ?? 0.0;
        final mrp = (prod['mrp'] as num?)?.toDouble() ?? price;
        final stock = (prod['stock'] as num?)?.toInt() ?? 0;
        final imgUrl = _resolveImgUrl(prod['imageUrl']);
        final weightVariant = OrderItemHelper.resolveWeightOrVariant(prod, name);

        final margin = (price > 0 && cost > 0) ? (((price - cost) / price) * 100).round() : null;

        return GestureDetector(
          onTap: () => _showEditPriceBottomSheet(prod),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: slateBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: imgUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 22),
                          )
                        : const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (weightVariant.isNotEmpty) ...[
                            OrderItemHelper.buildWeightBadge(context, weightVariant),
                            const SizedBox(width: 6),
                          ],
                          if (barcode.isNotEmpty)
                            Text('Code: $barcode', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: slateMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Cost: ₹${cost.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blue.shade700)),
                          const SizedBox(width: 8),
                          Text('Sell: ₹${price.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: slateDark)),
                          if (mrp > price) ...[
                            const SizedBox(width: 6),
                            Text('₹${mrp.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 9.5, color: slateMuted, decoration: TextDecoration.lineThrough)),
                          ],
                          if (margin != null) ...[
                            const SizedBox(width: 8),
                            Text('$margin% margin', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: margin >= 15 ? brandGreen : brandOrange)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stock <= 5 ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$stock units',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: stock <= 5 ? Colors.red.shade700 : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () => _showEditPriceBottomSheet(prod),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 14, color: Colors.blue),
                            const SizedBox(width: 2),
                            Text(
                              'Edit Rates',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: Reorder / Low Stock (WhatsApp PO) ──
  Widget _buildReorderTab() {
    if (_lowStockItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: brandGreen),
            const SizedBox(height: 12),
            Text('All Products Well Stocked!', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: slateDark)),
            const SizedBox(height: 4),
            Text('No low-stock replenishment alerts for this vendor.', style: GoogleFonts.inter(fontSize: 12, color: slateMuted)),
          ],
        ),
      );
    }

    double totalEstCost = 0.0;
    for (final item in _lowStockItems) {
      final id = item['id']?.toString() ?? '';
      final qty = _poQuantities[id] ?? 10;
      final cost = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
      totalEstCost += qty * cost;
    }

    return Column(
      children: [
        // Action PO Header
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_lowStockItems.length} Low Stock Alert Items',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: primaryRed),
                  ),
                  Text(
                    'Est. PO Value: ₹${totalEstCost.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: slateDark),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                label: Text('Send WhatsApp PO', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                onPressed: _sendWhatsAppPO,
              ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
            itemCount: _lowStockItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _lowStockItems[index];
              final id = item['id']?.toString() ?? '';
              final name = item['name'] ?? 'Product';
              final stock = item['stock'] ?? 0;
              final cost = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
              final currentQty = _poQuantities[id] ?? 10;
              final weightVariant = OrderItemHelper.resolveWeightOrVariant(item, name);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: slateBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (weightVariant.isNotEmpty) ...[
                                OrderItemHelper.buildWeightBadge(context, weightVariant),
                                const SizedBox(width: 6),
                              ],
                              Text('Stock: $stock left', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                              const SizedBox(width: 8),
                              Text('@ ₹${cost.toStringAsFixed(0)} cost', style: GoogleFonts.inter(fontSize: 10, color: slateMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quantity adjuster
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: slateMuted),
                          onPressed: () {
                            if (currentQty > 5) {
                              setState(() => _poQuantities[id] = currentQty - 5);
                            }
                          },
                        ),
                        Container(
                          width: 44,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: slateBorder),
                          ),
                          child: Text(
                            '$currentQty',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: slateDark),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: brandGreen),
                          onPressed: () {
                            setState(() => _poQuantities[id] = currentQty + 5);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 4: Payouts History ──
  Widget _buildPayoutsTab() {
    return Column(
      children: [
        // Action Bar: Record Payout
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Settlement History', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: slateDark)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: Text('Record Payout', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                onPressed: _openRecordPayoutModal,
              ),
            ],
          ),
        ),

        Expanded(
          child: _payouts.isEmpty
              ? Center(
                  child: Text('No payouts recorded yet for this vendor', style: GoogleFonts.inter(color: slateMuted, fontSize: 13)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 80),
                  itemCount: _payouts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pay = _payouts[index];
                    final amt = (pay['amount'] as num?)?.toDouble() ?? 0.0;
                    final method = pay['paymentMethod'] ?? 'UPI';
                    final txn = pay['transactionId'] ?? '';
                    final notes = pay['notes'] ?? '';
                    final dateStr = pay['paidAt'] != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(pay['paidAt']) ?? DateTime.now())
                        : 'Settled';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: slateBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${amt.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark),
                                ),
                                const SizedBox(height: 2),
                                Text(dateStr, style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted)),
                                if (txn.isNotEmpty)
                                  Text('Ref: $txn', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: slateMuted)),
                                if (notes.isNotEmpty)
                                  Text(notes, style: GoogleFonts.inter(fontSize: 10.5, color: slateDark, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              method.toString().replaceAll('_', ' '),
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: slateDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _shareVendorOrderWhatsApp(Map<String, dynamic> ord) async {
    final orderId = ord['orderId']?.toString() ?? '';
    final readableId = ord['readableId']?.toString() ?? (orderId.length > 6 ? orderId.substring(0, 6) : orderId);
    final items = (ord['items'] as List<dynamic>?) ?? [];
    final totalVal = (ord['totalVendorValue'] as num?)?.toDouble() ?? 0.0;
    final status = (ord['status'] ?? 'PENDING').toString();
    final vendorName = _vendorProfile?['name'] ?? 'Supplier';

    final buffer = StringBuffer();
    buffer.writeln('📦 *VENDOR DISPATCH SLIP - FASTKIRANA*');
    buffer.writeln('Order: *#$readableId* (${status.toUpperCase()})');
    buffer.writeln('Supplier: *$vendorName*');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}\n');
    buffer.writeln('*Products to Dispatch / Pack:*');

    int idx = 1;
    for (final it in items) {
      final name = it['name'] ?? 'Product';
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final weight = OrderItemHelper.resolveWeightOrVariant(it, name);
      final weightLabel = weight.isNotEmpty ? ' [$weight]' : '';
      final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
      final itemTotal = (it['totalCost'] as num?)?.toDouble() ?? (cost * qty);
      buffer.writeln('$idx. *$name$weightLabel* x *$qty* (@ ₹${cost.toStringAsFixed(0)} = ₹${itemTotal.toStringAsFixed(0)})');
      idx++;
    }

    buffer.writeln('\n*Total Supplier Supply Value: ₹${totalVal.toStringAsFixed(0)}*');
    buffer.writeln('Dark Store FastKirana Hub · Please ensure accurate weight & packing.');

    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(buffer.toString())}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      Clipboard.setData(ClipboardData(text: buffer.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispatch slip copied to clipboard!'), backgroundColor: brandGreen),
        );
      }
    }
  }

  // ── Tab 0: Live Orders (Restaurant / Kitchen KDS style) ──
  Widget _buildLiveOrdersTab() {
    final activeOrders = _liveOrders.where((ord) {
      if (_searchQuery.isEmpty) return true;
      final readableId = (ord['readableId'] ?? ord['orderId'] ?? '').toString().toLowerCase();
      final status = (ord['status'] ?? '').toString().toLowerCase();
      final items = (ord['items'] as List<dynamic>?) ?? [];
      final matchesItem = items.any((it) => (it['name'] ?? '').toString().toLowerCase().contains(_searchQuery));
      return readableId.contains(_searchQuery) || status.contains(_searchQuery) || matchesItem;
    }).toList();

    final nonDeliveredCount = _liveOrders.where((o) => o['status'] != 'DELIVERED').length;
    final totalVendorPendingVal = _liveOrders
        .where((o) => o['status'] != 'DELIVERED')
        .fold<double>(0.0, (sum, o) => sum + ((o['totalVendorValue'] as num?)?.toDouble() ?? 0.0));

    return Column(
      children: [
        // Live Header Summary Strip
        Container(
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: brandGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Store Dispatch Queue',
                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: slateDark),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: nonDeliveredCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$nonDeliveredCount Active',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: nonDeliveredCount > 0 ? primaryRed : slateMuted,
                  ),
                ),
              ),
              if (totalVendorPendingVal > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    '₹${totalVendorPendingVal.toStringAsFixed(0)} Due',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: _isLoadingLiveOrders && _liveOrders.isEmpty
              ? const Center(child: CircularProgressIndicator(color: primaryRed))
              : activeOrders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.notifications_active_outlined, size: 40, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No Active Live Orders Right Now',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'When dark store orders contain products attached to this vendor, they will appear here in real-time with instant alerts and pack sizes.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 12, color: slateMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: primaryRed,
                      onRefresh: () async {
                        if (_selectedVendorId != null) {
                          await _fetchLiveOrders(_selectedVendorId!);
                        }
                      },
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                        itemCount: activeOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final ord = activeOrders[index];
                          final orderId = ord['orderId']?.toString() ?? '';
                          final readableId = ord['readableId']?.toString() ?? (orderId.length > 6 ? orderId.substring(0, 6) : orderId);
                          final status = (ord['status'] ?? 'PENDING').toString();
                          final isDelivered = ord['isDelivered'] == true || status == 'DELIVERED';
                          final totalVal = (ord['totalVendorValue'] as num?)?.toDouble() ?? 0.0;
                          final items = (ord['items'] as List<dynamic>?) ?? [];
                          final createdAt = ord['createdAt']?.toString() ?? '';

                          Color statusBg;
                          Color statusFg;
                          IconData statusIcon;
                          if (isDelivered) {
                            statusBg = const Color(0xFFDCFCE7);
                            statusFg = const Color(0xFF15803D);
                            statusIcon = Icons.check_circle_rounded;
                          } else if (status == 'CONFIRMED' || status == 'PENDING') {
                            statusBg = const Color(0xFFDBEAFE);
                            statusFg = const Color(0xFF1D4ED8);
                            statusIcon = Icons.timelapse_rounded;
                          } else if (status == 'PACKED') {
                            statusBg = const Color(0xFFFFEDD5);
                            statusFg = const Color(0xFFC2410C);
                            statusIcon = Icons.inventory_rounded;
                          } else {
                            statusBg = const Color(0xFFF3E8FF);
                            statusFg = const Color(0xFF7E22CE);
                            statusIcon = Icons.info_outline_rounded;
                          }

                          String timeFormatted = '';
                          if (createdAt.isNotEmpty) {
                            final dt = DateTime.tryParse(createdAt);
                            if (dt != null) {
                              final diff = DateTime.now().difference(dt.toLocal());
                              if (diff.inMinutes < 1) {
                                timeFormatted = 'Just now';
                              } else if (diff.inMinutes < 60) {
                                timeFormatted = '${diff.inMinutes}m ago';
                              } else if (diff.inHours < 24) {
                                timeFormatted = '${diff.inHours}h ago';
                              } else {
                                timeFormatted = DateFormat('dd MMM, hh:mm a').format(dt.toLocal());
                              }
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDelivered ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
                                width: isDelivered ? 1.0 : 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order Header Strip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
                                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: slateDark,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#$readableId',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (timeFormatted.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_rounded, size: 12, color: slateMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeFormatted,
                                              style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(statusIcon, size: 11, color: statusFg),
                                            const SizedBox(width: 4),
                                            Text(
                                              status,
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
                                                color: statusFg,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Items List (Prominent Quantities & Pack Sizes)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                  child: Column(
                                    children: items.map((it) {
                                      final name = (it['name'] ?? 'Product').toString();
                                      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                                      final cost = (it['cost'] as num?)?.toDouble()
                                          ?? (it['costPrice'] as num?)?.toDouble()
                                          ?? 0.0;
                                      final itemTotal = (it['totalCost'] as num?)?.toDouble() ?? (cost * qty);
                                      final imgUrl = _resolveImgUrl(it['imageUrl']);
                                      final weightVariant = OrderItemHelper.resolveWeightOrVariant(it, name);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Prominent Quantity Box
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                                              ),
                                              child: Text(
                                                '${qty}x',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                  color: primaryRed,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Product Image
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                ),
                                                child: imgUrl.isNotEmpty
                                                    ? CachedNetworkImage(
                                                        imageUrl: imgUrl,
                                                        fit: BoxFit.contain,
                                                        errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, size: 18, color: slateMuted),
                                                      )
                                                    : const Icon(Icons.shopping_bag_outlined, size: 20, color: slateMuted),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Title and Pack Size
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: slateDark,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      if (weightVariant.isNotEmpty) ...[
                                                        OrderItemHelper.buildWeightBadge(context, weightVariant),
                                                        const SizedBox(width: 6),
                                                      ],
                                                      Text(
                                                        '@ ₹${cost.toStringAsFixed(0)}',
                                                        style: GoogleFonts.inter(fontSize: 11, color: slateMuted, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Total Cost
                                            Text(
                                              '₹${itemTotal.toStringAsFixed(0)}',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: slateDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),

                                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                // Footer: Vendor Payout Value and Action Buttons
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Supplier Payout Value',
                                            style: GoogleFonts.inter(fontSize: 10.5, color: slateMuted, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '₹${totalVal.toStringAsFixed(0)}',
                                            style: GoogleFonts.inter(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF15803D),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Bounceable(
                                        onTap: () => _shareVendorOrderWhatsApp(ord),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFBBF7D0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.share_rounded, size: 14, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Dispatch Slip',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF15803D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
