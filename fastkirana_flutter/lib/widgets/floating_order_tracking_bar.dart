import '../core/theme/design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/routes/page_transitions.dart';
import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';
import '../data/models/order.dart';
import '../data/repositories/order_repository.dart';
import '../features/orders/order_tracking_screen.dart';
import '../features/orders/orders_screen.dart';
import '../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FloatingOrderTrackingBar extends ConsumerStatefulWidget {
  final double bottomOffset;

  const FloatingOrderTrackingBar({
    super.key,
    this.bottomOffset = 16.0,
  });

  @override
  ConsumerState<FloatingOrderTrackingBar> createState() => _FloatingOrderTrackingBarState();
}

class _FloatingOrderTrackingBarState extends ConsumerState<FloatingOrderTrackingBar>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  RealtimeChannel? _ordersSubscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _setupRealtimeAndPolling();
  }

  void _setupRealtimeAndPolling() {
    // 1. Calm auto-poll and live order verification (runs every 12 seconds only when active orders exist)
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      if (!mounted) return;

      final currentOrders = ref.read(ordersProvider('')).valueOrNull ?? [];
      final active = currentOrders.where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.delivered).toList();
      
      // Only make network calls if there is actually an active order to track
      if (active.isNotEmpty) {
        ref.invalidate(ordersProvider(''));
        final topOrder = active.first;
        try {
          final repo = OrderRepository(ref.read(dioProvider));
          final cleanId = (topOrder.readableId ?? topOrder.id).replaceAll('#', '').trim();
          final liveOrder = await repo.getOrder(cleanId);
          if (liveOrder == null) return;
          if (liveOrder.status == OrderStatus.cancelled || liveOrder.status == OrderStatus.delivered) {
            await NotificationService().clearLiveOrderActivity(liveOrder.id, readableId: liveOrder.readableId);
            await repo.savePlacedOrderLocally(liveOrder);
            if (mounted) ref.invalidate(ordersProvider(''));
          } else {
            NotificationService().updateLiveOrderActivity(order: liveOrder);
          }
        } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
      }
    });

    // 2. Supabase Realtime Broadcast + Postgres Changes (0ms instant sync)
    try {
      _ordersSubscription = SupabaseService.subscribeToAllOrdersRealtime(
        onOrderChange: (record) {
          if (!mounted) return;
          final oid = (record['orderId'] ?? record['id'])?.toString();
          final rid = record['readableId']?.toString();
          final statusStr = (record['status'] ?? '').toString().toUpperCase().trim();
          final current = ref.read(ordersProvider('')).valueOrNull ?? [];
          final matchedOrders = current.where((o) =>
            (oid != null && o.id == oid) ||
            (rid != null && rid.isNotEmpty && o.readableId == rid),
          ).toList();
          if (matchedOrders.isNotEmpty || current.isNotEmpty) {
            if (statusStr == 'CANCELLED' || statusStr == 'DELIVERED') {
              for (final m in matchedOrders) {
                NotificationService().clearLiveOrderActivity(m.id, readableId: m.readableId);
              }
              if (oid != null || rid != null) {
                NotificationService().clearLiveOrderActivity(oid ?? '', readableId: rid);
              }
            }
            ref.invalidate(ordersProvider(''));
          }
        },
      );
    } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    if (_ordersSubscription != null) {
      try {
        SupabaseService.client?.removeChannel(_ordersSubscription!);
      } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
    }
    super.dispose();
  }

  double _getOrderProgress(OrderStatus status) {
    switch (status) {
      case OrderStatus.adminPending:
      case OrderStatus.pending:
        return 0.20;
      case OrderStatus.confirmed:
        return 0.45;
      case OrderStatus.packed:
        return 0.72;
      case OrderStatus.shipped:
        return 0.92;
      case OrderStatus.delivered:
        return 1.0;
      case OrderStatus.cancelled:
        return 0.0;
    }
  }

  String _getOrderSubtitle(Order order) {
    switch (order.status) {
      case OrderStatus.shipped:
        return 'Delivery partner on the way';
      case OrderStatus.packed:
        return 'Order packed & awaiting pickup';
      case OrderStatus.confirmed:
        return 'Order confirmed • Preparing';
      case OrderStatus.adminPending:
        return 'Verifying order details';
      case OrderStatus.pending:
        return 'Order received • Confirming';
      default:
        final shop = order.shopName;
        if (shop != null && shop.isNotEmpty) {
          final cleanShop = shop.replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');
          return cleanShop.toLowerCase().contains('dark') ? 'FastMinute Dark Store' : cleanShop;
        }
        return 'FastMinute Dark Store';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider(''));
    final allOrders = ordersAsync.valueOrNull ?? [];
    
    // Strictly filter out CANCELLED and DELIVERED orders
    final activeOrders = allOrders.where((o) {
      return o.status != OrderStatus.cancelled && o.status != OrderStatus.delivered;
    }).toList();

    if (activeOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestOrder = activeOrders.first;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 390;
    final barWidth = (screenWidth * (isCompact ? 0.94 : 0.92)).clamp(290.0, 440.0);

    // Dynamic styling based on order status
    final Color dotColor;
    final Color statusBgColor;
    final Color statusBorderColor;
    final Color statusTextColor;
    final List<Color> iconGradient;
    final Color iconBorder;
    final String iconEmoji;

    switch (latestOrder.status) {
      case OrderStatus.shipped:
        dotColor = const Color(0xFF0284C7);
        statusBgColor = const Color(0xFFF0F9FF);
        statusBorderColor = const Color(0xFFBAE6FD);
        statusTextColor = const Color(0xFF0369A1);
        iconGradient = const [Color(0xFFE0F2FE), Color(0xFFBAE6FD)];
        iconBorder = const Color(0xFF7DD3FC);
        iconEmoji = '🛵';
        break;
      case OrderStatus.packed:
        dotColor = const Color(0xFFD97706);
        statusBgColor = const Color(0xFFFFFBEB);
        statusBorderColor = const Color(0xFFFDE68A);
        statusTextColor = const Color(0xFFB45309);
        iconGradient = const [Color(0xFFFEF3C7), Color(0xFFFDE68A)];
        iconBorder = const Color(0xFFFCD34D);
        iconEmoji = '📦';
        break;
      case OrderStatus.adminPending:
        dotColor = const Color(0xFFEA580C);
        statusBgColor = const Color(0xFFFFF7ED);
        statusBorderColor = const Color(0xFFFED7AA);
        statusTextColor = const Color(0xFFC2410C);
        iconGradient = const [Color(0xFFFFEDD5), Color(0xFFFED7AA)];
        iconBorder = const Color(0xFFFDBA74);
        iconEmoji = '⏳';
        break;
      case OrderStatus.pending:
        dotColor = const Color(0xFFD97706);
        statusBgColor = const Color(0xFFFFFBEB);
        statusBorderColor = const Color(0xFFFDE68A);
        statusTextColor = const Color(0xFFB45309);
        iconGradient = const [Color(0xFFFEF3C7), Color(0xFFFDE68A)];
        iconBorder = const Color(0xFFFCD34D);
        iconEmoji = '⏳';
        break;
      default: // confirmed / others
        dotColor = const Color(0xFF16A34A);
        statusBgColor = const Color(0xFFF0FDF4);
        statusBorderColor = const Color(0xFFBBF7D0);
        statusTextColor = const Color(0xFF15803D);
        iconGradient = const [Color(0xFFDCFCE7), Color(0xFFBBF7D0)];
        iconBorder = const Color(0xFF86EFAC);
        iconEmoji = '⚡';
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: widget.bottomOffset,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: barWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  FadeSlideRoute(page: OrderTrackingScreen(orderId: latestOrder.readableId ?? latestOrder.id)),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    // 1. Deep ambient drop shadow lifting tracking bar off product list
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    // 2. Direct crisp elevation shadow
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                    // 3. Subtle live accent aura
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    children: [
                      // Top live order micro-progress line
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 2.5,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final progress = _getOrderProgress(latestOrder.status);
                            return Container(
                              width: constraints.maxWidth,
                              color: const Color(0xFFF1F5F9),
                              alignment: Alignment.centerLeft,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                width: constraints.maxWidth * progress,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      dotColor.withValues(alpha: 0.8),
                                      dotColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Main Bar Content
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8.0 : 10.0,
                          vertical: isCompact ? 7.0 : 9.0,
                        ),
                        child: Row(
                          children: [
                            // 1. Left Animated Status Icon Badge
                            Container(
                              width: isCompact ? 33 : 38,
                              height: isCompact ? 33 : 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: iconGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
                                border: Border.all(
                                  color: iconBorder,
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  iconEmoji,
                                  style: TextStyle(
                                    fontSize: isCompact ? 15.5 : 18.0,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isCompact ? 7 : 9),

                            // 2. Middle Content (Line 1: Order ID + Status Pill | Line 2: Contextual Status Subtitle)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Builder(
                                          builder: (context) {
                                            var cleanId = (latestOrder.readableId != null && latestOrder.readableId!.isNotEmpty)
                                                ? latestOrder.readableId!
                                                : (latestOrder.id.length > 6 ? latestOrder.id.substring(latestOrder.id.length - 6).toUpperCase() : latestOrder.id);
                                            if (cleanId.startsWith('FK-') && cleanId.length > 8) {
                                              cleanId = cleanId.substring(cleanId.length - 4);
                                            }
                                            final formattedId = cleanId.startsWith('#') ? cleanId : '#$cleanId';
                                            return Text(
                                              formattedId,
                                              style: GoogleFonts.inter(
                                                fontSize: isCompact ? 11.5 : 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: AppDesignSystem.slate900,
                                                letterSpacing: -0.2,
                                              ),
                                            );
                                          },
                                        ),
                                        SizedBox(width: isCompact ? 4.5 : 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 5.5 : 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: statusBorderColor,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AnimatedBuilder(
                                                animation: _pulseAnimation,
                                                builder: (context, child) {
                                                  return Container(
                                                    width: isCompact ? 5 : 6,
                                                    height: isCompact ? 5 : 6,
                                                    decoration: BoxDecoration(
                                                      color: dotColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: dotColor.withValues(alpha: 0.6 * _pulseAnimation.value),
                                                          blurRadius: 4 + 4 * _pulseAnimation.value,
                                                          spreadRadius: 1 * _pulseAnimation.value,
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                latestOrder.status.displayName,
                                                style: GoogleFonts.inter(
                                                  fontSize: isCompact ? 9.0 : 10.0,
                                                  fontWeight: FontWeight.w800,
                                                  color: statusTextColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Line 2: Contextual Status Subtitle with Auto-Scale (Zero Truncation on Moto/Compact)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _getOrderSubtitle(latestOrder),
                                      style: GoogleFonts.inter(
                                        fontSize: isCompact ? 9.5 : 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppDesignSystem.slate600,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: isCompact ? 6 : 8),

                            // 3. Right: Compact Vibrant Track Pill Button
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 9 : 12,
                                vertical: isCompact ? 5.5 : 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF00B047), Color(0xFF008A38)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00B047).withValues(alpha: 0.38),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Track',
                                    style: GoogleFonts.inter(
                                      fontSize: isCompact ? 10.5 : 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: isCompact ? 11.5 : 13),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

