import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

typedef CrashlyticsRecordError = Future<void> Function(
  Object error,
  StackTrace? stackTrace, {
  String? reason,
});

class LoggerService {
  static bool _isDebugMode = kDebugMode;
  static CrashlyticsRecordError? _recordError;

  static void initialize({
    bool? debugMode,
    CrashlyticsRecordError? recordError,
  }) {
    _isDebugMode = debugMode ?? kDebugMode;
    _recordError = recordError;
  }

  static void info(String message, {String? tag}) {
    final logMessage = _formatMessage('INFO', message, tag: tag);
    if (_isDebugMode) {
      developer.log(logMessage);
    }
  }

  static void warning(String message, {String? tag, Object? error}) {
    final logMessage = _formatMessage('WARN', message, tag: tag);
    if (_isDebugMode) {
      developer.log(logMessage, error: error);
    }
  }

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logMessage = _formatMessage('ERROR', message, tag: tag);
    developer.log(logMessage, error: error, stackTrace: stackTrace);
    if (_recordError != null) {
      try {
        _recordError!(error ?? message, stackTrace);
      } on Exception catch (_) {
      }
    }
  }

  static void debug(String message, {String? tag}) {
    final logMessage = _formatMessage('DEBUG', message, tag: tag);
    if (_isDebugMode) {
      developer.log(logMessage);
    }
  }

  static String _formatMessage(String level, String message, {String? tag}) {
    final buffer = StringBuffer();
    buffer.write('[$level]');
    if (tag != null && tag.isNotEmpty) {
      buffer.write('[$tag]');
    }
    buffer.write(' $message');
    return buffer.toString();
  }
}
