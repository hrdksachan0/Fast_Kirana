import 'package:flutter_test/flutter_test.dart';
import 'package:fastminute_flutter/data/models/order.dart';

void main() {
  group('Order.parseStatus regression guard', () {
    test('maps kitchen/preparing/ready aliases cleanly instead of falling back to pending', () {
      expect(Order.parseStatus('ADMIN_PENDING'), OrderStatus.adminPending);
      expect(Order.parseStatus('PENDING'), OrderStatus.pending);
      expect(Order.parseStatus('CONFIRMED'), OrderStatus.confirmed);
      expect(Order.parseStatus('PREPARING'), OrderStatus.confirmed);
      expect(Order.parseStatus('COOKING'), OrderStatus.confirmed);
      expect(Order.parseStatus('PROCESSING'), OrderStatus.confirmed);
      expect(Order.parseStatus('ACCEPTED'), OrderStatus.confirmed);
      expect(Order.parseStatus('PACKED'), OrderStatus.packed);
      expect(Order.parseStatus('READY'), OrderStatus.packed);
      expect(Order.parseStatus('READY_FOR_PICKUP'), OrderStatus.packed);
      expect(Order.parseStatus('SHIPPED'), OrderStatus.shipped);
      expect(Order.parseStatus('OUT_FOR_DELIVERY'), OrderStatus.shipped);
      expect(Order.parseStatus('DELIVERED'), OrderStatus.delivered);
      expect(Order.parseStatus('COMPLETED'), OrderStatus.delivered);
      expect(Order.parseStatus('CANCELLED'), OrderStatus.cancelled);
    });
  });

  group('Combined order channel alias normalization', () {
    Set<String> buildChannelKeys(List<String> rawInputs) {
      final keys = <String>{};
      for (final raw in rawInputs) {
        final clean = raw.trim().replaceAll('#', '');
        if (clean.isNotEmpty) {
          keys.add(clean);
          final strippedSuffix = clean.replaceFirst(RegExp(r'-[GR\d]+$'), '');
          if (strippedSuffix.isNotEmpty && strippedSuffix != clean) {
            keys.add(strippedSuffix);
            if (RegExp(r'^\d+$').hasMatch(strippedSuffix)) {
              keys.add('FK-$strippedSuffix');
            }
          }
          if (clean.startsWith('FK-')) {
            final numOnly = clean.substring(3);
            if (numOnly.isNotEmpty) keys.add(numOnly);
          } else if (RegExp(r'^\d+$').hasMatch(clean)) {
            keys.add('FK-$clean');
          }
        }
      }
      return keys;
    }

    test('matches -G / -R combined order readableId across rider and customer', () {
      final riderKeys = buildChannelKeys(['ord_123', '4636-G']);
      final customerKeys = buildChannelKeys(['#FK-4636']);
      expect(riderKeys.intersection(customerKeys), containsAll(['4636', 'FK-4636']));
    });
  });
}
