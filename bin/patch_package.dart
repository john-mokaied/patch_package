// bin/patch_package.dart
import 'dart:io';

import 'package:patch_package/app_log.dart';
import 'package:patch_package/logger.dart';
import 'package:patch_package/patch_package.dart';

void main(List<String> arguments) {
  final logger = Logger('patch_package.log');

  logger.log('Starting patch_package with arguments: ${arguments.join(" ")}');

  if (arguments.isEmpty) {
    logger.log('No arguments provided. Displaying usage information.');
    printUsage(logger);
    return;
  }

  final command = arguments.first;
  final packageName = arguments.length > 1 ? arguments[1] : null;

  if (packageName == null || packageName.isEmpty) {
    if (command != 'apply') {
      // Apply command does not require package name
      logger.log('Package name is missing for command $command');
      printUsage(logger);
      return;
    }
  }

  logger.log('Command: $command');
  if (packageName != null) {
    logger.log('Package Name: $packageName');
  }

  final patcher = FlutterPatcher(
      packageName ?? '', logger); // Adjusted to pass empty string if null

  switch (command) {
    case 'start':
      logger.log('Starting patching process for package: $packageName');
      patcher.start();
      break;
    case 'done':
      logger.log('Finalizing patching process for package: $packageName');
      patcher.done();
      break;
    case 'apply':
      logger.log('Applying all patches');
      applyPatches(logger);
      break;
    default:
      logger.log('Unknown command: $command');
      printUsage(logger);
      break;
  }
}

void printUsage(Logger logger) {
  const usage = 'Usage: dart run patch_package <command> [<package_name>]';
  const commands = 'Commands: start <package_name>, done <package_name>, apply';
  logger.log(usage);
  logger.log(commands);
  appLog(usage);
  appLog(commands);
  exit(1);
}
