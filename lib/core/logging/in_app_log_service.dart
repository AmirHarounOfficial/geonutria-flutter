import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum LogLevel { info, warning, error, network }

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.details,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? details;
  final String? stackTrace;

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toFullString() {
    final sb = StringBuffer();
    sb.writeln('[$timeFormatted] [${level.name.toUpperCase()}] [$tag] $message');
    if (details != null && details!.isNotEmpty) {
      sb.writeln('Details:\n$details');
    }
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      sb.writeln('StackTrace:\n$stackTrace');
    }
    return sb.toString();
  }
}

class InAppLogService extends ChangeNotifier {
  InAppLogService._();
  static final InAppLogService instance = InAppLogService._();

  final List<LogEntry> _logs = [];
  final int maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  int get errorCount =>
      _logs.where((l) => l.level == LogLevel.error).length;

  void log({
    required String tag,
    required String message,
    LogLevel level = LogLevel.info,
    String? details,
    String? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      details: details,
      stackTrace: stackTrace,
    );

    _logs.insert(0, entry); // latest at top
    if (_logs.length > maxLogs) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  void info(String tag, String message, {String? details}) {
    log(tag: tag, message: message, level: LogLevel.info, details: details);
  }

  void warning(String tag, String message, {String? details}) {
    log(tag: tag, message: message, level: LogLevel.warning, details: details);
  }

  void error(
    String tag,
    String message, {
    String? details,
    String? stackTrace,
  }) {
    log(
      tag: tag,
      message: message,
      level: LogLevel.error,
      details: details,
      stackTrace: stackTrace,
    );
  }

  void network({
    required String method,
    required String url,
    required int? statusCode,
    String? message,
    String? details,
    bool isError = false,
  }) {
    final statusStr = statusCode != null ? '($statusCode)' : '';
    final msg = '$method $url $statusStr ${message ?? ''}'.trim();
    log(
      tag: 'NETWORK',
      message: msg,
      level: isError ? LogLevel.error : LogLevel.network,
      details: details,
    );
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String exportLogs() {
    return _logs.map((e) => e.toFullString()).join('\n----------------------------------------\n');
  }
}
