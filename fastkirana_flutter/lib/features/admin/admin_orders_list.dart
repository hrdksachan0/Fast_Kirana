import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../orders/order_detail_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _selectedStatus = 'ALL';
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _error;

  static const Color primaryRed = Color(0xFFE20A22);

  final List<String> _statusTabs = [
    'ALL',
    'PENDING',
    'CONFIRMED',
    'PACKED',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAdminOrders();
  }

  Future<void> _fetchAdminOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/api/admin/orders',
        queryParameters: {
          if (_selectedStatus != 'ALL') 'status': _selectedStatus,
          'limit': 50,
        },
      );

      final data = response.data;
      List rawList = [];
      if (data is Map && data['orders'] is List) {
        rawList = data['orders'];
      } else if (data is List) {
        rawList = data;
      }

      if (mounted) {
        setState(() {
          _orders = rawList.map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to /api/orders?all=true
      try {
        final repo = OrderRepository(ref.read(dioProvider));
        final orders = await repo.getOrders('admin');
        if (mounted) {
          setState(() {
            _orders = _selectedStatus == 'ALL'
                ? orders
                : orders.where((o) => o.status?.name.toUpperCase() == _selectedStatus).toList();
            _isLoading = false;
          });
        }
      } catch (err) {
        if (mounted) {
          setState(() {
            _error = err.toString().replaceAll('Exception: ', '');
            _isLoading = false;
          });
        }
      }
    }
  }

  Color _getStatusColor(OrderStatus? status) {
    if (status == null) return const Color(0xFF64748B);
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF0284C7);
      case OrderStatus.packed:
        return const Color(0xFF7C3AED);
      case OrderStatus.shipped:
        return const Color(0xFFEA580C);
      case OrderStatus.delivered:
        return const Color(0xFF16A34A);
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Live Order Feed (Admin)',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchAdminOrders();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusTabs.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStatus = status);
                        _fetchAdminOrders();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryRed : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Orders Feed
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryRed))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No orders found for $_selectedStatus',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchAdminOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            final statusColor = _getStatusColor(order.status);

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.shopping_bag_rounded, size: 20, color: statusColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                order.readableId ?? order.id,
                                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                              ),
                                              Text(
                                                '₹${order.total.toStringAsFixed(0)}',
                                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: primaryRed),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${order.items?.length ?? 0} items • ${order.paymentMethod ?? "COD"}',
                                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  order.status?.name.toUpperCase() ?? 'PENDING',
                                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusColor),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}