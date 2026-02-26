import 'package:flutter/foundation.dart';

/// Log level for DebugLogger.
enum LogLevel { verbose, debug, info, warning, error, critical }

/// Single log entry (for optional buffer/export).
class LogEntry {
  final String tag;
  final String message;
  final LogLevel level;
  final Object? data;
  final Object? error;
  final DateTime timestamp;

  const LogEntry({
    required this.tag,
    required this.message,
    required this.level,
    this.data,
    this.error,
    required this.timestamp,
  });
}

/// Debug logger with tags. Active only in debug; buffer optional for export.
class DebugLogger {
  DebugLogger._();

  static const bool _enabled = !kReleaseMode;
  static final List<LogEntry> _buffer = [];

  static void log(
    String tag,
    String message, {
    LogLevel level = LogLevel.debug,
    Object? data,
    Object? error,
  }) {
    if (!_enabled) return;
    final entry = LogEntry(
      tag: tag,
      message: message,
      level: level,
      data: data,
      error: error,
      timestamp: DateTime.now(),
    );
    _buffer.add(entry);
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[${level.name.toUpperCase()}][$tag] $message ${data ?? ''}');
    }
  }

  static void gps(String msg, {Object? data}) => log('GPS', msg, data: data);
  static void health(String msg, {Object? data}) => log('HEALTH', msg, data: data);
  static void collar(String msg, {Object? data}) => log('COLLAR', msg, data: data);
  static void auth(String msg, {Object? data}) => log('AUTH', msg, data: data);
  static void notif(String msg, {Object? data}) => log('NOTIF', msg, data: data);
  static void sync(String msg, {Object? data}) => log('SYNC', msg, data: data);
  static void ui(String msg, {Object? data}) =>
      log('UI', msg, data: data, level: LogLevel.verbose);
}
