import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String? readableId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.readableId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = true;
  Order? _order;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _order = _getMockOrder();
        _isLoading = false;
      });
    }
  }

  Order _getMockOrder() {
    return Order(
      id: widget.orderId,
      readableId: widget.readableId ?? '#FK-2401',
      status: 'out_for_delivery',
      paymentMethod: 'COD',
      paymentStatus: 'pending',
      subtotal: 245,
      discount: 20,
      deliveryFee: 0,
      total: 245,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      estimatedDelivery: DateTime.now().add(const Duration(minutes: 5)),
      items: [
        OrderItem(id: '1', name: 'Amul Toned Milk', imageUrl: '', price: 42, quantity: 2, unit: '1L'),
        OrderItem(id: '2', name: 'Himalaya Cookies', imageUrl: '', price: 65, quantity: 1, unit: '300g'),
      ],
    );
  }

  List<Map<String, dynamic>> _getTrackingSteps() {
    return [
      {
        'title': 'Order Placed',
        'subtitle': 'Your order has been placed',
        'time': _order?.createdAt ?? DateTime.now().subtract(const Duration(minutes: 25)),
        'completed': true,
        'icon': Icons.check_circle_rounded,
      },
      {
        'title': 'Confirmed',
        'subtitle': 'Order confirmed by store',
        'time': DateTime.now().subtract(const Duration(minutes: 20)),
        'completed': true,
        'icon': Icons.check_circle_rounded,
      },
      {
        'title': 'Packed',
        'subtitle': 'Your items are packed',
        'time': DateTime.now().subtract(const Duration(minutes: 12)),
        'completed': true,
        'icon': Icons.check_circle_rounded,
      },
      {
        'title': 'Out for Delivery',
        'subtitle': 'Rider is on the way',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'completed': _order?.status != 'confirmed',
        'icon': _order?.status == 'out_for_delivery' ? Icons.motorcycle_rounded : Icons.radio_button_unchecked_rounded,
        'active': _order?.status == 'out_for_delivery',
      },
      {
        'title': 'Delivered',
        'subtitle': 'Order delivered successfully',
        'time': _order?.estimatedDelivery ?? DateTime.now().add(const Duration(minutes: 5)),
        'completed': false,
        'icon': Icons.radio_button_unchecked_rounded,
      },
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_rounded,
                            size: 22, color: AppTheme.textPrimary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Track Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Order ID
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.receipt_long_rounded,
                                  size: 22, color: AppTheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _order?.readableId ?? widget.readableId ?? '#FK-${widget.orderId}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '₹${_order?.total.toInt() ?? 0} • ${_order?.items.length ?? 0} items',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ETA card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary.withOpacity(0.08),
                                AppTheme.primary.withOpacity(0.02),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.12),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '🛵',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estimated Delivery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(_order?.estimatedDelivery != null ? _order!.estimatedDelivery!.difference(DateTime.now()).inMinutes : 5)} mins',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Tracking timeline
                        Text(
                          'Order Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        ..._getTrackingSteps().map((step) {
                          return _TrackingStep(step: step);
                        }).toList(),

                        const SizedBox(height: 24),

                        // Items
                        Text(
                          'Items in this order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ...(_order?.items ?? []).map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.border.withOpacity(0.5), width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.shopping_bag_outlined,
                                    size: 20, color: AppTheme.textMuted),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${item.unit} x${item.quantity}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${(item.price * item.quantity).toInt()}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  final Map<String, dynamic> step;

  const _TrackingStep({required this.step});

  @override
  Widget build(BuildContext context) {
    final isCompleted = step['completed'] as bool? ?? false;
    final isActive = step['active'] as bool? ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.primary
                    : isActive
                    ? AppTheme.primary.withOpacity(0.15)
                    : AppTheme.border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : (step['icon'] as IconData),
                size: 14,
                color: isCompleted
                    ? Colors.white
                    : isActive
                    ? AppTheme.primary
                    : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 1.5,
              height: 36,
              color: isCompleted
                  ? AppTheme.primary.withOpacity(0.3)
                  : AppTheme.border.withOpacity(0.3),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 2, bottom: isActive ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive || isCompleted ? FontWeight.w700 : FontWeight.w500,
                    color: isActive || isCompleted
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  step['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive || isCompleted
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(step['time'] as DateTime),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}
