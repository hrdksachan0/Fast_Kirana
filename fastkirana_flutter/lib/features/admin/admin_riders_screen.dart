import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/admin_authorization.dart';
import '../../../core/utils/app_toast.dart';

class AdminRidersScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final String? assignedStoreId;

  const AdminRidersScreen({
    super.key,
    this.showAppBar = true,
    this.assignedStoreId,
  });

  @override
  ConsumerState<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends ConsumerState<AdminRidersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _riders = [];
  Map<String, dynamic>? _summary;
  String _searchQuery = '';
  String? _currentStoreId;

  @override
  void initState() {
    super.initState();
    _currentStoreId = widget.assignedStoreId;
    _fetchRidersData();
  }

  @override
  void didUpdateWidget(covariant AdminRidersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assignedStoreId != widget.assignedStoreId) {
      _currentStoreId = widget.assignedStoreId;
      _fetchRidersData();
    }
  }

  Future<void> _fetchRidersData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final prefs = await SharedPreferences.getInstance();
      final storeId = _currentStoreId ?? prefs.getString('assigned_store_id');

      final response = await dio.get(
        '/api/admin/rider-cash',
        queryParameters: {
          if (storeId != null && storeId.isNotEmpty && storeId != 'all') 'storeId': storeId,
        },
        options: await AdminAuthorization.optionsAsync(),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _riders = (data['riders'] as List? ?? [])
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList();
            _summary = data['summary'] != null ? Map<String, dynamic>.from(data['summary'] as Map) : null;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load rider cash balances';
          });
        }
      }
    } catch (e) {
      debugPrint('[AdminRidersScreen] fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Unable to connect to server';
        });
      }
    }
  }

  Future<void> _settleCashModal(Map<String, dynamic> rider) async {
    HapticFeedback.mediumImpact();
    final amountController = TextEditingController(
      text: (rider['cashInHand'] as num? ?? 0.0) > 0 ? (rider['cashInHand'] as num).toString() : '',
    );
    final notesController = TextEditingController(text: 'Daily Cash Deposit to Store Admin');
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
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
                        color: AppDesignSystem.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.emerald50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.account_balance_wallet_rounded, color: AppDesignSystem.emerald700, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settle Cash with ${rider['name'] ?? 'Rider'}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                            ),
                            Text(
                              'Unsettled Cash in Hand: ₹${(rider['cashInHand'] as num? ?? 0.0).toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppDesignSystem.emerald700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cash Amount Received (₹)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppDesignSystem.slate700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.slate500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Deposit Notes',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppDesignSystem.slate700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.emerald700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text.trim());
                              if (amt == null || amt <= 0) {
                                AppToast.showError(context, 'Invalid Amount', subtitle: 'Please enter a valid deposit amount');
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                final dio = ref.read(dioProvider);
                                final res = await dio.post(
                                  '/api/admin/rider-cash',
                                  data: {
                                    'riderId': rider['id'],
                                    'amount': amt,
                                    'notes': notesController.text.trim(),
                                  },
                                  options: await AdminAuthorization.optionsAsync(),
                                );
                                if (res.statusCode == 200) {
                                  if (mounted) {
                                    Navigator.of(ctx).pop();
                                    AppToast.showSuccess(
                                      context,
                                      'Cash Settled Successfully! ✅',
                                      subtitle: '₹${amt.toStringAsFixed(0)} deposited by ${rider['name']}',
                                    );
                                    _fetchRidersData();
                                  }
                                }
                              } catch (err) {
                                debugPrint('[AdminRidersScreen] settlement error: $err');
                                if (mounted) {
                                  AppToast.showError(context, 'Settlement Failed', subtitle: 'Could not record cash deposit');
                                }
                              } finally {
                                if (modalCtx.mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Confirm Cash Received',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
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

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String phone, String riderName) async {
    var clean = phone.replaceAll(RegExp(r'\D'), '');
    if (!clean.startsWith('91') && clean.length == 10) clean = '91$clean';
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$clean?text=Hi%20$riderName,%20Store%20Admin%20FastKirana:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRiders = _riders.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (r['name'] ?? '').toString().toLowerCase();
      final phone = (r['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                'Rider Fleet & Cash Ledger',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppDesignSystem.slate700),
                  onPressed: _fetchRidersData,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _fetchRidersData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _fetchRidersData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // 1. KPI Summary Cards
                      if (_summary != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Riders in Store',
                                value: '${_summary!['activeRidersCount'] ?? _riders.length}',
                                icon: Icons.two_wheeler_rounded,
                                color: AppDesignSystem.cyan600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Pending Cash',
                                value: '₹${(_summary!['pendingRiderCash'] as num? ?? 0.0).toStringAsFixed(0)}',
                                icon: Icons.account_balance_wallet_rounded,
                                color: AppDesignSystem.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'COD Delivered Today',
                                value: '₹${(_summary!['deliveredCodToday'] as num? ?? 0.0).toStringAsFixed(0)}',
                                icon: Icons.payments_rounded,
                                color: AppDesignSystem.emerald700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Cash Deposited Today',
                                value: '₹${(_summary!['totalCashDepositedToday'] as num? ?? 0.0).toStringAsFixed(0)}',
                                icon: Icons.savings_rounded,
                                color: AppDesignSystem.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 2. Search Field
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppDesignSystem.slate200),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search rider by name or phone...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.slate400),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.slate400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. Rider Cards List
                      if (filteredRiders.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Text(
                            'No delivery partners found for this store',
                            style: GoogleFonts.inter(fontSize: 13, color: AppDesignSystem.slate500, fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        ...filteredRiders.map((rider) => _buildRiderCard(rider)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.slate200),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppDesignSystem.slate900)),
        ],
      ),
    );
  }

  Widget _buildRiderCard(Map<String, dynamic> rider) {
    final name = (rider['name'] ?? 'Delivery Partner').toString();
    final phone = (rider['phone'] ?? '').toString();
    final cashInHand = (rider['cashInHand'] as num? ?? 0.0).toDouble();
    final cashLimit = (rider['cashLimit'] as num? ?? 10000.0).toDouble();
    final isLocked = cashInHand >= cashLimit;
    final isWarning = cashInHand >= cashLimit * 0.75;
    final todayCodOrders = (rider['todayCodOrdersCount'] as num? ?? 0).toInt();
    final todayOnlineOrders = (rider['todayOnlineOrdersCount'] as num? ?? 0).toInt();
    final todayTotalOrders = todayCodOrders + todayOnlineOrders;
    final todayCodTotal = (rider['todayCodTotal'] as num? ?? 0.0).toDouble();
    final todayOnlineTotal = (rider['todayOnlineTotal'] as num? ?? 0.0).toDouble();
    final todayTotalMoney = todayCodTotal + todayOnlineTotal;
    final todayDeposited = (rider['todayDepositedTotal'] as num? ?? 0.0).toDouble();
    final storeName = (rider['storeName'] ?? 'Store Hub').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocked ? Colors.red.shade300 : (isWarning ? Colors.amber.shade300 : AppDesignSystem.slate200),
          width: isLocked || isWarning ? 1.5 : 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Phone, Store Hub & Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppDesignSystem.cyan600.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'R',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppDesignSystem.cyan700, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.slate100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              storeName,
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppDesignSystem.slate600),
                            ),
                          ),
                        ],
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          '📞 $phone',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                        ),
                    ],
                  ),
                ),
                // Quick Call & WhatsApp
                if (phone.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.chat_rounded, color: AppDesignSystem.green600, size: 18),
                    onPressed: () => _openWhatsApp(phone, name),
                    tooltip: 'WhatsApp Rider',
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppDesignSystem.emerald700, size: 18),
                    onPressed: () => _callPhone(phone),
                    tooltip: 'Call Rider',
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Work & Money Section (Grid 2x2)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    // Work Metric
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📦 WORK TODAY', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppDesignSystem.slate400)),
                            const SizedBox(height: 2),
                            Text(
                              '$todayTotalOrders Orders',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                            ),
                            Text(
                              'COD: $todayCodOrders · Online: $todayOnlineOrders',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Money / Delivered Volume Metric
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💰 ORDER VALUE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppDesignSystem.slate400)),
                            const SizedBox(height: 2),
                            Text(
                              '₹${todayTotalMoney.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                            ),
                            Text(
                              'Deposited: ₹${todayDeposited.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppDesignSystem.emerald700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Cash in Hand Banner with Settlement Action
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFFFFEBEB)
                        : (isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLocked
                          ? Colors.red.shade200
                          : (isWarning ? Colors.amber.shade200 : const Color(0xFFDCFCE7)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '💵 CASH IN HAND',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isLocked ? Colors.red.shade800 : (isWarning ? Colors.amber.shade900 : AppDesignSystem.emerald700),
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 4),
                                const Text('🔒 LIMIT REACHED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${cashInHand.toStringAsFixed(0)} / ₹${cashLimit.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isLocked ? Colors.red.shade900 : AppDesignSystem.slate900,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.emerald700,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _settleCashModal(rider),
                        icon: const Icon(Icons.savings_rounded, color: Colors.white, size: 14),
                        label: Text(
                          'Settle Cash',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
