// lib/app_log.dart
import 'dart:developer' as developer;

void appLog(dynamic data) {
  final String logMessage = data.toString();
  developer.log(logMessage);
}
