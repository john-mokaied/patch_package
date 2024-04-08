// bin/main.dart
import 'dart:io';

import 'package:patch_package/patch_package.dart';
import 'package:patch_package/logger.dart';

void main(List<String> arguments) {
  final logger = Logger('patch_package.log');

  if (arguments.isEmpty) {
    printUsage(logger);
    return;
  }

  final command = arguments.first;
  final packageName = arguments.length > 1 ? arguments[1] : null;

  if (packageName == null || packageName.isEmpty) {
    printUsage(logger);
    return;
  }
  final patcher = FlutterPatcher(packageName, logger);

  switch (command) {
    case 'start':
      patcher.start();
      break;
    case 'done':
      patcher.done();
      break;
    case 'apply':
      applyPatches(logger);
      break;
    default:
      printUsage(logger);
      break;
  }
}

void printUsage(Logger logger) {
  logger.log('Usage: dart run patch_package <command> [<package_name>]');
  logger.log('Commands: start <package_name>, done <package_name>, apply');
  exit(1);
}
