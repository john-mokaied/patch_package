// lib/logger.dart

import 'dart:io';

import 'package:patch_package/app_log.dart';

abstract class LoggerInterface {
  void log(String message);
}

class Logger implements LoggerInterface {
  final File logFile;

  Logger(String logFilePath) : logFile = File(logFilePath);

  @override
  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    appLog(logMessage);
    logFile.writeAsStringSync('$logMessage\n', mode: FileMode.append);
  }
}

class MockLogger implements LoggerInterface {
  final List<String> messages = [];

  @override
  void log(String message) {
    messages.add(message);
  }
}
