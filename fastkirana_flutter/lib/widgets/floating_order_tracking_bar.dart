import '../core/theme/design_system.dart';
import '../core/theme/responsive.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/routes/page_transitions.dart';
import '../core/network/api_client.dart';
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

class _FloatingOrderTrackingBarState extends ConsumerState<FloatingOrderTrackingBar> {
  Timer? _refreshTimer;
  RealtimeChannel? _ordersSubscription;

  @override
  void initState() {
    super.initState();
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
          if (liveOrder.status == OrderStatus.cancelled || liveOrder.status == OrderStatus.delivered) {
            await repo.updateOrderStatus(cleanId, liveOrder.status);
            if (mounted) ref.invalidate(ordersProvider(''));
          }
        } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
      }
    });

    // 2. Supabase Realtime Postgres Changes
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        _ordersSubscription = sb
            .channel('floating_order_bar_sync')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'orders',
              callback: (payload) {
                if (mounted) {
                  ref.invalidate(ordersProvider(''));
                }
              },
            )
            .subscribe();
      }
    } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_ordersSubscription != null) {
      try {
        SupabaseService.client?.removeChannel(_ordersSubscription!);
      } catch (e, _) { LoggerService.error('FloatingOrderTrackingBar: silent catch', e); }
    }
    super.dispose();
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
    final barWidth = (screenWidth * 0.92).clamp(320.0, 420.0);

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
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppDesignSystem.slate300,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: AppDesignSystem.accent.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 1. Left Animated Status Icon Badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusDelivered,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppDesignSystem.emerald200,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          latestOrder.status == OrderStatus.shipped
                              ? '🛵'
                              : (latestOrder.status == OrderStatus.packed ? '📦' : '⚡'),
                          style: TextStyle(fontSize: Responsive.scaledFontSize(context, 17)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),

                    // 2. Middle Content (Line 1: Order ID + Status Pill | Line 2: Store / ETA)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
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
                                      fontSize: Responsive.scaledFontSize(context, 12.5),
                                      fontWeight: FontWeight.w900,
                                      color: AppDesignSystem.slate900,
                                      letterSpacing: -0.2,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.statusDelivered,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.emerald200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4.5,
                                      height: 4.5,
                                      decoration: BoxDecoration(
                                        color: AppDesignSystem.success,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppDesignSystem.success.withValues(alpha: 0.8),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      latestOrder.status.displayName,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 9.5),
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.emerald600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Line 2: Store / Outlet Name
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '🏪 ${latestOrder.shopName != null && latestOrder.shopName!.isNotEmpty ? (latestOrder.shopName!.toLowerCase().contains('dark') ? 'FastKirana Dark Store' : latestOrder.shopName!) : (latestOrder.restaurantId != null ? 'Restaurant' : 'FastKirana Dark Store')}',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w600,
                                    color: AppDesignSystem.slate500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3. Right: Compact Emerald Track Pill Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppDesignSystem.accent, AppDesignSystem.accentDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignSystem.accent.withValues(alpha: 0.3),
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
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
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
    );
  }
}

