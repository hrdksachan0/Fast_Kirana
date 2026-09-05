import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../orders/order_tracking_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isLoading = true;
  List<Order> _userOrders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final phone = prefs.getString('user_phone') ?? '';

    // Auto-enable all notifications in background
    await prefs.setBool('notif_order_updates', true);
    await prefs.setBool('notif_offers_promos', true);
    await prefs.setBool('notif_delivery_alerts', true);

    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final orders = await repo.getOrders(userId.isNotEmpty ? userId : phone);
      if (mounted) {
        setState(() {
          _userOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) { LoggerService.error('NotificationsScreen: silent catch', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final localDt = dt.isUtc ? dt.toLocal() : dt;
    final diff = DateTime.now().difference(localDt);
    if (diff.isNegative || diff.inMinutes < 2) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${localDt.day.toString().padLeft(2, '0')}/${localDt.month.toString().padLeft(2, '0')}/${localDt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 18),
            fontWeight: FontWeight.w800,
            color: AppDesignSystem.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppDesignSystem.primary,
              child: _userOrders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: AppDesignSystem.slate100,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  size: 32,
                                  color: AppDesignSystem.slate400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Notifications Yet',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 16),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Live updates on your orders and delivery alerts will appear here automatically.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                color: AppDesignSystem.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _userOrders.length,
                      itemBuilder: (context, index) {
                        final order = _userOrders[index];
                        String icon = '📦';
                        String title = 'Order Placed';
                        String body = 'Your order #${order.displayId} (₹${order.total.toInt()}) has been received.';
                        bool isUnread = order.status != OrderStatus.delivered && order.status != OrderStatus.cancelled;

                        if (order.status == OrderStatus.delivered) {
                          icon = '🛵';
                          title = 'Order Delivered!';
                          body = 'Your order #${order.displayId} (₹${order.total.toInt()}) has been delivered successfully.';
                          isUnread = false;
                        } else if (order.status == OrderStatus.shipped) {
                          icon = '🛵';
                          title = 'Rider On The Way!';
                          body = 'Delivery partner is on the way with order #${order.displayId}.';
                        } else if (order.status == OrderStatus.packed) {
                          icon = '📦';
                          title = 'Order Packed & Sealed';
                          body = 'Items for order #${order.displayId} are packed and ready.';
                        } else if (order.status == OrderStatus.confirmed) {
                          icon = '✅';
                          title = 'Order Confirmed';
                          body = 'Order #${order.displayId} is confirmed and being prepared.';
                        } else if (order.status == OrderStatus.cancelled) {
                          icon = '❌';
                          title = 'Order Cancelled';
                          body = 'Order #${order.displayId} was cancelled.';
                          isUnread = false;
                        }

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingScreen(orderId: order.id),
                              ),
                            );
                          },
                          child: _buildNotificationTile(
                            icon: icon,
                            title: title,
                            body: body,
                            time: _formatTimeAgo(order.createdAt),
                            isUnread: isUnread,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationTile({
    required String icon,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread ? AppDesignSystem.statusCancelled : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppDesignSystem.red200 : AppDesignSystem.slate100,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isUnread ? Colors.white : AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppDesignSystem.slate100),
            ),
            child: Center(
              child: Text(icon, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 20))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                          color: AppDesignSystem.textPrimary,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppDesignSystem.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    color: AppDesignSystem.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    color: AppDesignSystem.textMuted,
                    fontWeight: FontWeight.w600,
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
