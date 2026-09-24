import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class PickerScanScreen extends StatefulWidget {
  final String? orderId;
  final String? readableId;
  final List<dynamic>? expectedItems;
  final Function(String itemId)? onItemScanned;

  const PickerScanScreen({
    super.key,
    this.orderId,
    this.readableId,
    this.expectedItems,
    this.onItemScanned,
  });

  @override
  State<PickerScanScreen> createState() => _PickerScanScreenState();
}

class _PickerScanScreenState extends State<PickerScanScreen> {
  final TextEditingController _barcodeInputController = TextEditingController();
  String? _lastScannedName;
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _barcodeInputController.dispose();
    super.dispose();
  }

  void _handleBarcodeSubmitted(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return;
    _barcodeInputController.clear();

    final items = widget.expectedItems;
    if (items == null || items.isEmpty) {
      // Generic scan mode
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      setState(() {
        _lastScannedName = 'Barcode: $code';
        _errorMessage = null;
        _isSuccess = true;
      });
      return;
    }

    // Match against expected items
    final cleanCode = code.toLowerCase();
    Map<String, dynamic>? matchedItem;

    for (final it in items) {
      if (it is! Map) continue;
      final itBarcode = (it['barcode'] ?? (it['product'] is Map ? it['product']['barcode'] : null))?.toString().toLowerCase();
      final itId = (it['id'] ?? it['productId'] ?? '').toString().toLowerCase();
      final itName = (it['name'] ?? it['title'] ?? '').toString().toLowerCase();

      if ((itBarcode != null && itBarcode.isNotEmpty && itBarcode == cleanCode) ||
          itId == cleanCode ||
          itName.contains(cleanCode)) {
        matchedItem = Map<String, dynamic>.from(it);
        break;
      }
    }

    if (matchedItem != null) {
      // Valid item match
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      final itemId = (matchedItem['id'] ?? matchedItem['productId'] ?? '').toString();
      final name = (matchedItem['name'] ?? matchedItem['title'] ?? 'Item').toString();

      setState(() {
        _lastScannedName = '$name (Matched)';
        _errorMessage = null;
        _isSuccess = true;
      });

      widget.onItemScanned?.call(itemId);
    } else {
      // Error: Wrong item
      HapticFeedback.heavyImpact();
      setState(() {
        _lastScannedName = null;
        _errorMessage = 'Wrong item scanned! Barcode "$code" not found in Order #${widget.readableId ?? widget.orderId ?? ""}';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        title: Text(
          widget.readableId != null ? 'Scan Order #${widget.readableId}' : 'Scan Barcode',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 18),
            fontWeight: FontWeight.w800,
            color: AppDesignSystem.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Scanner Target Frame
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorMessage != null
                        ? AppDesignSystem.rose500
                        : (_isSuccess ? AppDesignSystem.success : AppDesignSystem.borderLight),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _errorMessage != null
                            ? Icons.error_outline_rounded
                            : (_isSuccess ? Icons.check_circle_outline_rounded : Icons.qr_code_scanner_rounded),
                        size: 110,
                        color: _errorMessage != null
                            ? AppDesignSystem.rose500
                            : (_isSuccess ? AppDesignSystem.success : AppDesignSystem.textMuted),
                      ),
                    ),
                    Positioned(top: 0, left: 0, child: _corner(true, true)),
                    Positioned(top: 0, right: 0, child: _corner(true, false)),
                    Positioned(bottom: 0, left: 0, child: _corner(false, true)),
                    Positioned(bottom: 0, right: 0, child: _corner(false, false)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Position barcode or enter code below',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  color: AppDesignSystem.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // Barcode Input Field (Instant USB / Keyboard scanner compatible)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeInputController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Enter or scan barcode...',
                        prefixIcon: const Icon(Icons.barcode_reader, color: AppDesignSystem.blue600),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: _handleBarcodeSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _handleBarcodeSubmitted(_barcodeInputController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Success Notification
              if (_isSuccess && _lastScannedName != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lastScannedName!,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Error Notification
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Expected items checklist
              if (widget.expectedItems != null && widget.expectedItems!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Items in this Order (${widget.expectedItems!.length}):',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.expectedItems!.length,
                  itemBuilder: (ctx, idx) {
                    final it = widget.expectedItems![idx];
                    final name = (it is Map ? (it['name'] ?? it['title']) : null) ?? 'Item';
                    final qty = (it is Map ? it['quantity'] : 1) ?? 1;
                    final barcode = (it is Map ? (it['barcode'] ?? (it['product'] is Map ? it['product']['barcode'] : null)) : null);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Text('${idx + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Expanded(
                            child: Text(
                              '$name (x$qty)',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (barcode != null && barcode.toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                barcode.toString(),
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppDesignSystem.slate600),
                              ),
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
      ),
    );
  }

  Widget _corner(bool top, bool left) {
    final color = _errorMessage != null
        ? AppDesignSystem.rose500
        : (_isSuccess ? AppDesignSystem.success : AppDesignSystem.success);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color, width: 4) : BorderSide.none,
          left: left ? BorderSide(color: color, width: 4) : BorderSide.none,
          right: !left ? BorderSide(color: color, width: 4) : BorderSide.none,
          bottom: !top ? BorderSide(color: color, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}