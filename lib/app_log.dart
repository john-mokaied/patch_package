// lib/app_log.dart

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void appLog(dynamic data, {bool isImportant = false}) {
  if (kDebugMode) {
    if (isImportant) {
      developer.log('\x1B[33m$data\x1B[0m');
    } else {
      developer.log('$data');
    }
  }
}
