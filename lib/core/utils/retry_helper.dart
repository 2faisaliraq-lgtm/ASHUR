import 'dart:async';

typedef ShouldRetryPredicate = bool Function(Object error);

Future<T> retryAsync<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  Duration maxDelay = const Duration(seconds: 5),
  double backoffFactor = 2,
  ShouldRetryPredicate? shouldRetry,
}) async {
  int attempt = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;

      if (attempt >= maxRetries) {
        rethrow;
      }

      final isRetryable = shouldRetry?.call(e) ?? _isNetworkError(e);
      if (!isRetryable) {
        rethrow;
      }

      await Future.delayed(delay);
      final nextDelayMs = (delay.inMilliseconds * backoffFactor).clamp(
        initialDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      );
      delay = Duration(milliseconds: nextDelayMs.toInt());
    }
  }
}

bool _isNetworkError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('network') ||
      message.contains('timeout') ||
      message.contains('connection') ||
      message.contains('socket') ||
      message.contains('http') ||
      message.contains('failed host lookup') ||
      message.contains('nodename nor servname provided') ||
      message.contains('connection reset by peer') ||
      message.contains('handshake error') ||
      message.contains('remote');
}
