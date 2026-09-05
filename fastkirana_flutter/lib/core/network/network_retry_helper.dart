import 'dart:async';
import 'dart:math';
import '../services/logger_service.dart';

/// Helper to execute network tasks with exponential backoff and jitter.
/// Ideal for flaky restaurant and kitchen network conditions.
class NetworkRetryHelper {
  /// Retries [action] up to [maxAttempts] times when an exception occurs.
  /// Delays exponentially: [initialDelay] * ([factor] ^ attempt) + random jitter.
  static Future<T> retry<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double factor = 2.0,
    Duration maxDelay = const Duration(seconds: 4),
    bool Function(dynamic error)? shouldRetry,
    String operationName = 'network_operation',
  }) async {
    int attempt = 0;
    Duration currentDelay = initialDelay;
    final random = Random();

    while (true) {
      attempt++;
      try {
        return await action();
      } catch (error) {
        if (attempt >= maxAttempts) {
          LoggerService.error('[$operationName] Exhausted all $maxAttempts retry attempts: $error');
          rethrow;
        }

        if (shouldRetry != null && !shouldRetry(error)) {
          LoggerService.warning('[$operationName] Error not retryable on attempt $attempt: $error');
          rethrow;
        }

        // Calculate jittered exponential backoff
        final jitterMs = random.nextInt(150);
        final delayWithJitter = currentDelay + Duration(milliseconds: jitterMs);

        LoggerService.warning(
          '[$operationName] Attempt $attempt failed ($error). Retrying in ${delayWithJitter.inMilliseconds}ms...',
        );

        await Future.delayed(delayWithJitter);

        // Exponential increase capped at maxDelay
        final nextDelayMs = (currentDelay.inMilliseconds * factor).toInt();
        currentDelay = Duration(
          milliseconds: min(nextDelayMs, maxDelay.inMilliseconds),
        );
      }
    }
  }
}
