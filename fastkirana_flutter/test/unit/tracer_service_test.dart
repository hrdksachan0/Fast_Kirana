import 'package:flutter_test/flutter_test.dart';
import 'package:fastkirana_flutter/core/services/tracer_service.dart';

void main() {
  group('TracerService Distributed Tracing Tests', () {
    test('generateTraceId produces a valid 32-character hex trace ID', () {
      final traceId = TracerService.generateTraceId();
      expect(traceId.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(traceId), isTrue);
    });

    test('generateSpanId produces a valid 16-character hex span ID', () {
      final spanId = TracerService.generateSpanId();
      expect(spanId.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(spanId), isTrue);
    });

    test('startTrace creates an active span and sets active IDs', () {
      final span = TracerService.startTrace('checkout_tap_test', attributes: {'step': 1});
      expect(span.name, 'checkout_tap_test');
      expect(span.traceId, TracerService.activeTraceId);
      expect(span.spanId, TracerService.activeSpanId);
      expect(span.headers.containsKey('X-Trace-Id'), isTrue);
      expect(span.headers.containsKey('traceparent'), isTrue);
      expect(span.traceparentHeader, startsWith('00-${span.traceId}-${span.spanId}-01'));

      span.end(extraAttributes: {'success': true});
      expect(TracerService.activeTraceId, isNull);
    });

    test('traceHeaders returns correct W3C TraceContext format', () {
      final headers = TracerService.traceHeaders(explicitTraceId: '1234567890abcdef1234567890abcdef');
      expect(headers['X-Trace-Id'], '1234567890abcdef1234567890abcdef');
      expect(headers['traceparent'], startsWith('00-1234567890abcdef1234567890abcdef-'));
      expect(headers['traceparent']!.endsWith('-01'), isTrue);
    });

    test('recordSpan logs observed span without throwing', () {
      expect(
        () => TracerService.recordSpan(
          'rider_device_receipt',
          traceId: '1234567890abcdef1234567890abcdef',
          attributes: {'status': 'OUT_FOR_DELIVERY'},
        ),
        returnsNormally,
      );
    });
  });
}
