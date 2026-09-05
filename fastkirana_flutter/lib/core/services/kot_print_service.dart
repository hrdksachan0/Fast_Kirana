import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../utils/app_toast.dart';
import 'supabase_service.dart';

/// Exact 1:1 Port of Web App's KOT & POS Printing Engine (src/lib/kot-print.ts)
class KotPrintService {
  static final Map<String, DateTime> _recentPrintTimestamps = {};

  /// Send Remote KOT Broadcast to Web Kitchen Console:
  /// Single authoritative path via server-side HTTP API (`/api/kot-broadcast`)
  static Future<bool> sendRemoteKOTToKitchen({
    required String orderId,
    String? readableId,
    String? shopName,
    String? kotText,
    String? customerName,
    List<dynamic>? items,
    String? deliveryMethod,
    String? notes,
    Dio? dioClient,
  }) async {
    bool success = false;
    var cleanId = orderId.trim();
    if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);
    final cleanReadable = (readableId ?? '').replaceAll('#', '').trim();
    final baseReadable = cleanReadable.replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');

    // Multi-click cooldown guard (10 seconds)
    final now = DateTime.now();
    final lastTimeId = _recentPrintTimestamps[cleanId];
    final lastTimeReadable = cleanReadable.isNotEmpty ? _recentPrintTimestamps[cleanReadable] : null;
    final lastTimeBase = baseReadable.isNotEmpty ? _recentPrintTimestamps[baseReadable] : null;

    final lastTime = (lastTimeId != null || lastTimeReadable != null || lastTimeBase != null)
        ? [lastTimeId, lastTimeReadable, lastTimeBase].whereType<DateTime>().reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    if (lastTime != null && now.difference(lastTime).inSeconds < 10) {
      debugPrint('[KotPrintService] ⚠️ Multi-tap ignored for #$cleanReadable / #$cleanId (cooldown active)');
      return true;
    }
    _recentPrintTimestamps[cleanId] = now;
    if (cleanReadable.isNotEmpty) _recentPrintTimestamps[cleanReadable] = now;
    if (baseReadable.isNotEmpty) _recentPrintTimestamps[baseReadable] = now;

    final payload = {
      'orderId': cleanId,
      'readableId': readableId ?? cleanId,
      'shopName': shopName ?? 'Kitchen',
      'kotText': kotText ?? '',
      'customerName': customerName ?? 'Customer',
      'items': items ?? [],
      'deliveryMethod': deliveryMethod ?? 'DELIVERY',
      'notes': notes,
      'printedAt': DateTime.now().toIso8601String(),
    };

    // Path 1: Server-side HTTP API (Primary reliable gateway to web kitchen)
    bool apiSuccess = false;
    try {
      final dio = dioClient ??
          Dio(BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
          ));
      final res = await dio.post('/api/kot-broadcast', data: payload);
      if (res.statusCode == 200) {
        apiSuccess = true;
        success = true;
        debugPrint('[KotPrintService] Server-side KOT broadcast success for #$cleanId');
      }
    } catch (e) {
      debugPrint('[KotPrintService] Server KOT broadcast note/err: $e');
    }

    // Path 2: Direct Supabase Realtime Channel (Fallback ONLY if server API failed)
    // Also updates the order record as kot_sent in DB
    try {
      final sb = SupabaseService.client;
      if (sb != null) {
        // Update DB record
        try {
          await sb.from('orders').update({
            'kot_printed': true,
            'kot_sent': true,
            'kotPrintedAt': DateTime.now().toIso8601String(),
          }).eq('id', cleanId);
        } catch (_) {}

        // If the backend API already broadcasted, DO NOT send a duplicate broadcast!
        if (!apiSuccess) {
          final channel = sb.channel('restaurant-orders-live');
          channel.subscribe((status, [error]) async {
            if (status == RealtimeSubscribeStatus.subscribed) {
              await channel.sendBroadcastMessage(
                event: 'reprint-kot',
                payload: payload,
              );
              debugPrint('[KotPrintService] Supabase fallback KOT broadcast sent for #$cleanId');
            }
          });
          success = true;
        }
      }
    } catch (e) {
      debugPrint('[KotPrintService] Supabase direct broadcast error: $e');
    }

    return success;
  }
  /// Format date strictly in Indian Standard Time (IST)
  static String formatKOTDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateFormat('dd MMM, hh:mm a').format(DateTime.now());
    }
    try {
      DateTime dt;
      if (dateValue is DateTime) {
        dt = dateValue.toLocal();
      } else if (dateValue is num) {
        dt = DateTime.fromMillisecondsSinceEpoch(dateValue.toInt()).toLocal();
      } else {
        String s = dateValue.toString().trim();
        if (s.isEmpty) return DateFormat('dd MMM, hh:mm a').format(DateTime.now());
        if (!s.endsWith('Z') && !s.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(s)) {
          s = '${s.replaceAll(' ', 'T')}Z';
        }
        dt = DateTime.parse(s).toLocal();
      }
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return DateFormat('dd MMM, hh:mm a').format(DateTime.now());
    }
  }

  /// Strictly extracts restaurant dishes only, omitting any grocery items from combined orders
  static List<dynamic> extractRestaurantItems(Map<String, dynamic> order) {
    // 1. Explicit restaurantItems array
    if (order['restaurantItems'] is List && (order['restaurantItems'] as List).isNotEmpty) {
      return (order['restaurantItems'] as List).toList();
    }

    // 2. SubOrders with RESTAURANT type or restaurantId
    if (order['subOrders'] is List && (order['subOrders'] as List).isNotEmpty) {
      for (final s in (order['subOrders'] as List)) {
        if (s is Map && (s['type'] == 'RESTAURANT' || s['restaurantId'] != null || s['shopType'] == 'RESTAURANT')) {
          if (s['items'] is List && (s['items'] as List).isNotEmpty) {
            return (s['items'] as List).toList();
          }
        }
      }
    }

    // 3. Filter items array if combined or mixed
    if (order['items'] is List) {
      final allItems = (order['items'] as List);

      // Check if any items have explicit restaurant flags
      final explicitRestItems = allItems.where((it) {
        if (it is! Map) return false;
        final isRest = it['isRestaurantItem'] == true ||
            it['restaurantId'] != null ||
            it['type'] == 'RESTAURANT' ||
            (it['product'] is Map && (it['product']['isRestaurantItem'] == true || it['product']['restaurantId'] != null));
        return isRest;
      }).toList();

      if (explicitRestItems.isNotEmpty) {
        return explicitRestItems;
      }

      // Check if order is marked as combined
      final bool isCombined = order['isCombined'] == true ||
          order['shopName']?.toString().contains('Combined') == true ||
          order['shopName']?.toString().contains('+') == true;

      if (isCombined) {
        // Cooked food items should NEVER be excluded
        const cookedFoodWhitelists = [
          'dosa', 'burger', 'pizza', 'sandwich', 'roll', 'frankie', 'chowmein', 'noodles',
          'fried rice', 'paneer', 'manchurian', 'shake', 'cold coffee', 'tea', 'chai', 'coffee',
          'pasta', 'thali', 'roti', 'naan', 'gravy', 'curry', 'biryani', 'pav bhaji', 'fries',
          'momos', 'samosa', 'maggi', 'soup'
        ];
        const pureGroceryOnlyKeywords = [
          'atta', 'raw rice', 'dal packet', 'mustard oil', 'refined oil', 'washing powder',
          'soap', 'shampoo', 'toothpaste', 'brush', 'detergent', 'surf excel', 'toilet cleaner'
        ];

        final filteredRestItems = allItems.where((it) {
          if (it is! Map) return false;
          final name = (it['name'] ?? (it['product'] is Map ? it['product']['name'] : '')).toString().toLowerCase();
          if (cookedFoodWhitelists.any((cw) => name.contains(cw))) return true;
          final isGroceryStaple = pureGroceryOnlyKeywords.any((k) => name.contains(k));
          return !isGroceryStaple;
        }).toList();

        if (filteredRestItems.isNotEmpty) {
          return filteredRestItems;
        }
      }

      return allItems;
    }

    return [];
  }

  /// Exact 1:1 Thermal KOT Printing matching Web App (`src/lib/kot-print.ts`)
  static Future<void> printKOTReceipt(
    BuildContext context,
    Map<String, dynamic> order, {
    String shopType = 'RESTAURANT',
  }) async {
    try {
      final String orderId = (order['id'] ?? '').toString();
      final dynamic rawReadable = order['readableId'];
      final bool isCombined = order['isCombined'] == true;
      final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
          ? rawReadable.toString()
          : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

      final String orderIdText = isCombined ? '#$readableId-R' : '#$readableId';
      final String orderDateStr = formatKOTDate(order['createdAt']);
      final String printDateStr = formatKOTDate(DateTime.now());
      final String deliveryMethod = (order['deliveryMethod'] ?? 'DOORSTEP DELIVERY').toString().toUpperCase();
      final String customerName = (order['userName'] ??
              (order['user'] is Map ? order['user']['name'] : null) ??
              order['customerName'] ??
              'Customer')
          .toString();
      final String? orderNotes = order['notes']?.toString();

      // Extract restaurant items strictly (omit grocery items on combined orders)
      final List<dynamic> targetItems = extractRestaurantItems(order);

      final doc = await generateKOTPdfDocument(
        orderIdText: orderIdText,
        shopType: shopType,
        orderDateStr: orderDateStr,
        printDateStr: printDateStr,
        deliveryMethod: deliveryMethod,
        customerName: customerName,
        orderNotes: orderNotes,
        targetItems: targetItems,
      );

      final pdfBytes = await doc.save();
      if (pdfBytes.isEmpty) {
        throw Exception('Generated PDF is empty (0 bytes).');
      }

      // Trigger Direct System & POS Print Dialog on Android
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'KOT-$orderIdText',
        format: PdfPageFormat.roll80,
      );

      if (context.mounted) {
        AppToast.showSuccess(
          context,
          'KOT Print Sent! 🖨️',
          subtitle: 'Sent to thermal POS / printer',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          'Print Error',
          subtitle: e.toString(),
        );
      }
    }
  }

  /// Share KOT as guaranteed valid PDF file via system share (WhatsApp, Gmail, Bluetooth, Drive, etc.)
  static Future<void> shareKOTReceipt(
    BuildContext context,
    Map<String, dynamic> order, {
    String shopType = 'RESTAURANT',
  }) async {
    try {
      final String orderId = (order['id'] ?? '').toString();
      final dynamic rawReadable = order['readableId'];
      final bool isCombined = order['isCombined'] == true;
      final String readableId = (rawReadable != null && rawReadable.toString().isNotEmpty)
          ? rawReadable.toString()
          : (orderId.length > 4 ? orderId.substring(orderId.length - 4) : orderId);

      final String orderIdText = isCombined ? '#$readableId-R' : '#$readableId';
      final String orderDateStr = formatKOTDate(order['createdAt']);
      final String printDateStr = formatKOTDate(DateTime.now());
      final String deliveryMethod = (order['deliveryMethod'] ?? 'DOORSTEP DELIVERY').toString().toUpperCase();
      final String customerName = (order['userName'] ??
              (order['user'] is Map ? order['user']['name'] : null) ??
              order['customerName'] ??
              'Customer')
          .toString();
      final String? orderNotes = order['notes']?.toString();

      List<dynamic> targetItems = [];
      if (order['restaurantItems'] is List && (order['restaurantItems'] as List).isNotEmpty) {
        targetItems = order['restaurantItems'] as List;
      } else if (order['subOrders'] is List) {
        final subOrders = order['subOrders'] as List;
        dynamic restSub;
        for (final s in subOrders) {
          if (s is Map && (s['type'] == 'RESTAURANT' || s['restaurantId'] != null)) {
            restSub = s;
            break;
          }
        }
        if (restSub != null && restSub is Map && restSub['items'] is List) {
          targetItems = restSub['items'] as List;
        }
      }
      if (targetItems.isEmpty && order['items'] is List) {
        targetItems = order['items'] as List;
      }

      final doc = await generateKOTPdfDocument(
        orderIdText: orderIdText,
        shopType: shopType,
        orderDateStr: orderDateStr,
        printDateStr: printDateStr,
        deliveryMethod: deliveryMethod,
        customerName: customerName,
        orderNotes: orderNotes,
        targetItems: targetItems,
      );

      final pdfBytes = await doc.save();
      if (pdfBytes.isEmpty) {
        throw Exception('Generated PDF is 0 bytes.');
      }

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'KOT-$readableId.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(
          context,
          'Share Error',
          subtitle: e.toString(),
        );
      }
    }
  }

  /// Low-level guaranteed valid PDF Document Builder for 80mm POS Thermal
  static Future<pw.Document> generateKOTPdfDocument({
    required String orderIdText,
    required String shopType,
    required String orderDateStr,
    required String printDateStr,
    required String deliveryMethod,
    required String customerName,
    required String? orderNotes,
    required List<dynamic> targetItems,
  }) async {
    final doc = pw.Document();

    pw.Font monoFont;
    pw.Font monoRegular;
    try {
      monoFont = await PdfGoogleFonts.robotoMonoBold();
      monoRegular = await PdfGoogleFonts.robotoMonoRegular();
    } catch (_) {
      monoFont = pw.Font.courierBold();
      monoRegular = pw.Font.courier();
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.roll80.copyWith(
          marginTop: 4 * PdfPageFormat.mm,
          marginBottom: 6 * PdfPageFormat.mm,
          marginLeft: 4 * PdfPageFormat.mm,
          marginRight: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) => [
          // Header
          pw.Center(
            child: pw.Text(
              'FASTKIRANA',
              style: pw.TextStyle(font: monoFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'KITCHEN ORDER TICKET ($shopType)',
              style: pw.TextStyle(font: monoFont, fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 4),

          // Order Meta Table
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TICKET ID:', style: pw.TextStyle(font: monoFont, fontSize: 11)),
              pw.Text(orderIdText, style: pw.TextStyle(font: monoFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Order Placed:', style: pw.TextStyle(font: monoRegular, fontSize: 9.5)),
              pw.Text(orderDateStr, style: pw.TextStyle(font: monoFont, fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('KOT Printed:', style: pw.TextStyle(font: monoRegular, fontSize: 9.5)),
              pw.Text(printDateStr, style: pw.TextStyle(font: monoRegular, fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Order Type:', style: pw.TextStyle(font: monoRegular, fontSize: 9.5)),
              pw.Text(deliveryMethod, style: pw.TextStyle(font: monoFont, fontSize: 9.5)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Customer:', style: pw.TextStyle(font: monoRegular, fontSize: 9.5)),
              pw.Text(customerName, style: pw.TextStyle(font: monoFont, fontSize: 9.5)),
            ],
          ),
          if (orderNotes != null && orderNotes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Order Note:', style: pw.TextStyle(font: monoFont, fontSize: 9.5)),
                pw.Expanded(
                  child: pw.Text(
                    orderNotes,
                    style: pw.TextStyle(font: monoFont, fontSize: 9.5),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ],

          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 4),

          // Items Section Title
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'PREPARATION DISHES:',
              style: pw.TextStyle(font: monoFont, fontSize: 10.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),

          // Dishes List
          ...targetItems.map((item) {
            final String name = (item['name'] ?? (item['product'] is Map ? item['product']['name'] : 'Item')).toString();
            final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
            final String? variant = (item['selectedVariant'] ?? item['variant'])?.toString();
            final String? note = item['notes']?.toString();

            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5, style: pw.BorderStyle.dashed)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 32,
                    child: pw.Text(
                      '[$qty' 'x]',
                      style: pw.TextStyle(font: monoFont, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          name + (variant != null && variant.isNotEmpty ? ' ($variant)' : ''),
                          style: pw.TextStyle(font: monoFont, fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                        ),
                        if (note != null && note.trim().isNotEmpty)
                          pw.Text(
                            'Note: $note',
                            style: pw.TextStyle(font: monoRegular, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.SizedBox(height: 4),

          // Footer
          pw.Center(
            child: pw.Text(
              '*** FASTKIRANA KITCHEN SYSTEM ***',
              style: pw.TextStyle(font: monoFont, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'Prompt & Hot Preparation Verified',
              style: pw.TextStyle(font: monoRegular, fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
    );

    return doc;
  }
}
