import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/admin_authorization.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../data/models/order.dart';

/// Modal bottom sheet for recording order item & general refunds
class AdminRefundSheet {
  static void show({
    required BuildContext context,
    required Order order,
    required WidgetRef ref,
    required VoidCallback onRefundSuccess,
  }) {
    final remainingRefundable = (order.total - order.refundAmount).clamp(0.0, double.infinity);
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final selectedItems = <String, double>{};
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          final items = order.items ?? [];
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
                      decoration: BoxDecoration(color: AppDesignSystem.slate300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.replay_rounded, color: Color(0xFFE11D48), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record Refund',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                            ),
                            Text(
                              'Order #${order.readableId ?? order.id} • Max: ₹${remainingRefundable.toInt()}',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppDesignSystem.slate500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppDesignSystem.slate500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Financial exclusion disclaimer
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Refunded amount is excluded from Restaurant Payouts & FastKirana Sales.',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (items.isNotEmpty) ...[
                    Text(
                      'Select Items to Refund (Optional):',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.slate700),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((it) {
                      final isSelected = selectedItems.containsKey(it.id);
                      final isAlreadyRefunded = it.isRefunded || it.refundAmount > 0;
                      final itemVal = (it.price * it.quantity);

                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: isSelected,
                        title: Text(
                          '${it.quantity}x ${it.name} (₹${itemVal.toInt()})',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isAlreadyRefunded ? AppDesignSystem.slate400 : AppDesignSystem.slate800,
                            decoration: isAlreadyRefunded ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: isAlreadyRefunded
                            ? Text('Already refunded (-₹${it.refundAmount.toInt()})', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFE11D48)))
                            : null,
                        onChanged: isAlreadyRefunded
                            ? null
                            : (val) {
                                setModalState(() {
                                  if (val == true && it.id.isNotEmpty) {
                                    selectedItems[it.id] = itemVal;
                                  } else if (it.id.isNotEmpty) {
                                    selectedItems.remove(it.id);
                                  }
                                  final totalSelected = selectedItems.values.fold<double>(0.0, (sum, v) => sum + v);
                                  if (totalSelected > 0) {
                                    amountController.text = totalSelected.toInt().toString();
                                  }
                                });
                              },
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  Text(
                    'Refund Amount (₹):',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.slate700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Enter amount (e.g. 165)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Refund Reason / Notes:',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppDesignSystem.slate700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Item unavailable / spoilt / customer cancelled',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppDesignSystem.slate300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                              if (amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid refund amount > 0')),
                                );
                                return;
                              }
                              if (amt > remainingRefundable) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Refund amount cannot exceed remaining balance (₹${remainingRefundable.toInt()})')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              try {
                                final dio = ref.read(dioProvider);
                                final itemsPayload = selectedItems.entries.map((e) => {
                                  'id': e.key,
                                  'refundAmount': e.value,
                                }).toList();

                                await dio.post(
                                  '/api/admin/orders/${order.id}/refund',
                                  data: {
                                    'amount': amt,
                                    'reason': reasonController.text.trim(),
                                    'items': itemsPayload,
                                  },
                                  options: AdminAuthorization.options(),
                                );

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Refund of ₹${amt.toInt()} recorded successfully!'),
                                      backgroundColor: const Color(0xFF059669),
                                    ),
                                  );
                                }
                                onRefundSuccess();
                              } catch (err) {
                                if (modalContext.mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to record refund: $err'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Confirm & Process Refund',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
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
}
