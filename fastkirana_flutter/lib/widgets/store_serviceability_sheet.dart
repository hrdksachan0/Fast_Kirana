import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/services/logger_service.dart';

class StoreServiceabilitySheet extends StatefulWidget {
  final String targetType; // 'HUB' | 'RESTAURANT'
  final String targetId;
  final String storeName;
  final bool currentIsOpen;
  final String? pauseUntil;
  final String? closeReason;
  final Dio dio;
  final Function(bool isOpen, String? pauseUntil)? onStatusChanged;

  const StoreServiceabilitySheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.storeName,
    required this.currentIsOpen,
    this.pauseUntil,
    this.closeReason,
    required this.dio,
    this.onStatusChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String storeName,
    required bool currentIsOpen,
    String? pauseUntil,
    String? closeReason,
    required Dio dio,
    Function(bool isOpen, String? pauseUntil)? onStatusChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoreServiceabilitySheet(
        targetType: targetType,
        targetId: targetId,
        storeName: storeName,
        currentIsOpen: currentIsOpen,
        pauseUntil: pauseUntil,
        closeReason: closeReason,
        dio: dio,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  State<StoreServiceabilitySheet> createState() => _StoreServiceabilitySheetState();
}

class _StoreServiceabilitySheetState extends State<StoreServiceabilitySheet> {
  int _selectedDuration = 30; // 15, 30, 60, -1 (Today)
  String _selectedReason = 'HIGH_ORDER_SURGE';
  final TextEditingController _customReasonCtrl = TextEditingController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _reasons = [
    {
      'id': 'HIGH_ORDER_SURGE',
      'label': 'High Order Rush / Surge Backlog',
      'icon': Icons.local_fire_department,
    },
    {
      'id': 'HEAVY_RAIN',
      'label': 'Heavy Rain / Bad Weather',
      'icon': Icons.thunderstorm,
    },
    {
      'id': 'RIDER_SHORTAGE',
      'label': 'Delivery Riders Unavailable',
      'icon': Icons.two_wheeler,
    },
    {
      'id': 'STOCK_AUDIT',
      'label': 'Stock Restocking / Inward',
      'icon': Icons.inventory_2,
    },
    {
      'id': 'TECHNICAL_MAINTENANCE',
      'label': 'Power Cut / Maintenance',
      'icon': Icons.build,
    },
    {
      'id': 'OTHER',
      'label': 'Other Operational Reason',
      'icon': Icons.help_outline,
    },
  ];

  Future<void> _submitToggle(String action) async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.dio.post(
        '/api/admin/serviceability/toggle',
        data: {
          'targetType': widget.targetType,
          'targetId': widget.targetId,
          'action': action,
          'pauseMinutes': action == 'PAUSE' ? _selectedDuration : null,
          'reason': _selectedReason,
          'customReasonText': _selectedReason == 'OTHER' ? _customReasonCtrl.text.trim() : null,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final bool newOpen = data['status'] == 'ONLINE';
        final String? newPause = data['pauseUntil']?.toString();

        if (mounted) {
          Navigator.of(context).pop();
          widget.onStatusChanged?.call(newOpen, newPause);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Store status updated successfully!'),
              backgroundColor: newOpen ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          );
        }
      }
    } catch (e) {
      LoggerService.error('StoreServiceabilitySheet: toggle failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Serviceability',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.storeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 1: Choose Duration (Zepto Busy Mode)
            const Text(
              '⏱️ 1. CHOOSE PAUSE DURATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDurationChip(15, '15 Mins', 'Quick rush'),
                const SizedBox(width: 8),
                _buildDurationChip(30, '30 Mins', 'Restock'),
                const SizedBox(width: 8),
                _buildDurationChip(60, '1 Hour', 'Break'),
                const SizedBox(width: 8),
                _buildDurationChip(-1, 'Full Day', 'Manual'),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Choose Reason
            const Text(
              '📋 2. SELECT REASON (AUDITED)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            ..._reasons.map((r) {
              final isSelected = _selectedReason == r['id'];
              return InkWell(
                onTap: () => setState(() => _selectedReason = r['id'] as String),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.amber : Colors.grey.withOpacity(0.25),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        r['icon'] as IconData,
                        size: 20,
                        color: isSelected ? Colors.amber.shade800 : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.amber.shade900 : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, size: 18, color: Colors.amber),
                    ],
                  ),
                ),
              );
            }),

            if (_selectedReason == 'OTHER') ...[
              const SizedBox(height: 6),
              TextField(
                controller: _customReasonCtrl,
                decoration: InputDecoration(
                  hintText: 'Type specific operational reason...',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_selectedDuration == -1) {
                          _submitToggle('CLOSE_TODAY');
                        } else {
                          _submitToggle('PAUSE');
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleWidget(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.power_settings_new, size: 20),
                label: Text(
                  _isLoading
                      ? 'Updating...'
                      : _selectedDuration == -1
                          ? 'Close Store For Today'
                          : 'Pause Store ($_selectedDuration Mins)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(int value, String label, String sub) {
    final isSelected = _selectedDuration == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDuration = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundedRectangleWidget extends RoundedRectangleBorder {
  const RoundedRectangleWidget({required BorderRadiusGeometry borderRadius})
      : super(borderRadius: borderRadius);
}
