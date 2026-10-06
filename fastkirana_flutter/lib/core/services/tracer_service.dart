import 'dart:math';
import 'logger_service.dart';

/// Distributed W3C Trace Context & OpenTelemetry Tracer
/// Connects Customer Checkout Tap -> FastAPI Order Engine -> Supabase Realtime -> Rider Console Receipt
class TracerService {
  TracerService._();
  static final TracerService instance = TracerService._();

  static final Random _rng = Random.secure();
  static String? _activeTraceId;
  static String? _activeSpanId;

  static String? get activeTraceId => _activeTraceId;
  static String? get activeSpanId => _activeSpanId;

  /// Generates a compliant 32-character hex trace ID (128-bit)
  static String generateTraceId() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a compliant 16-character hex span ID (64-bit)
  static String generateSpanId() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Starts a root or child distributed trace span
  static TraceSpan startTrace(String spanName, {Map<String, dynamic>? attributes}) {
    final traceId = generateTraceId();
    final spanId = generateSpanId();
    _activeTraceId = traceId;
    _activeSpanId = spanId;

    final span = TraceSpan(
      name: spanName,
      traceId: traceId,
      spanId: spanId,
      attributes: attributes ?? {},
      startTime: DateTime.now(),
    );

    LoggerService.info(
      '📡 [Tracer] [SPAN_START] name=$spanName trace_id=$traceId span_id=$spanId attributes=$attributes',
    );
    return span;
  }

  /// Records an observed span (e.g., rider device receipt from Realtime payload)
  static void recordSpan(
    String spanName, {
    required String traceId,
    String? parentSpanId,
    Map<String, dynamic>? attributes,
  }) {
    final spanId = generateSpanId();
    LoggerService.info(
      '🚀 [Tracer] [SPAN_CAPTURED] name=$spanName trace_id=$traceId span_id=$spanId parent_span_id=$parentSpanId attributes=$attributes',
    );
  }

  /// Returns outgoing W3C TraceContext headers
  static Map<String, String> traceHeaders({String? explicitTraceId}) {
    final traceId = explicitTraceId ?? _activeTraceId ?? generateTraceId();
    final spanId = generateSpanId();
    return {
      'X-Trace-Id': traceId,
      'traceparent': '00-$traceId-$spanId-01',
    };
  }

  static void clearActiveTrace() {
    _activeTraceId = null;
    _activeSpanId = null;
  }
}

/// Active Span representation
class TraceSpan {
  final String name;
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final Map<String, dynamic> attributes;
  final DateTime startTime;

  TraceSpan({
    required this.name,
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.attributes,
    required this.startTime,
  });

  String get traceparentHeader => '00-$traceId-$spanId-01';

  Map<String, String> get headers => {
        'X-Trace-Id': traceId,
        'traceparent': traceparentHeader,
      };

  void end({Map<String, dynamic>? extraAttributes, Object? error}) {
    final durationMs = DateTime.now().difference(startTime).inMilliseconds;
    final mergedAttrs = {...attributes, ...?extraAttributes};
    if (error != null) {
      LoggerService.error(
        '💥 [Tracer] [SPAN_ERROR] name=$name trace_id=$traceId duration=${durationMs}ms error=$error attrs=$mergedAttrs',
      );
    } else {
      LoggerService.info(
        '✅ [Tracer] [SPAN_END] name=$name trace_id=$traceId duration=${durationMs}ms attrs=$mergedAttrs',
      );
    }
    if (TracerService.activeTraceId == traceId) {
      TracerService.clearActiveTrace();
    }
  }
}
