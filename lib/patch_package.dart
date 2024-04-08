// lib/patch_package.dart

import 'dart:io';

import 'package:patch_package/app_log.dart';
import 'package:patch_package/logger.dart';
import 'package:path/path.dart' as path;

class FlutterPatcher {
  final String packageName;
  final LoggerInterface logger;
  String? packagePath;

  FlutterPatcher(this.packageName, this.logger) {
    packagePath = findPackagePath(packageName, logger);
  }

  void start() async {
    try {
      final packagePath = findPackagePath(packageName, logger);
      if (packagePath == null) {
        appLog('Package $packageName not found.');
        return;
      }

      final packageDir = Directory(packagePath);
      final tempDirPath = path.join(Directory.systemTemp.path, packageName);
      final tempDir = Directory(tempDirPath);

      if (await tempDir.exists()) {
        appLog('Deleting existing temp directory at $tempDirPath');
        await tempDir.delete(recursive: true);
      }
      appLog('Creating new temp directory at $tempDirPath');
      await tempDir.create();

      appLog('Saving current state of $packageName...');
      await copyDirectory(packageDir, tempDir, logger);
      appLog('Snapshot saved in $tempDirPath');
    } catch (e) {
      appLog('Error saving snapshot of $packageName: $e');
    }
  }

  void done() async {
    logger.log('Finalizing patch for $packageName...');
    try {
      final tempDirPath = path.join(Directory.systemTemp.path, packageName);
      logger.log('Looking for temporary directory at $tempDirPath');
      final tempDir = Directory(tempDirPath);
      if (!await tempDir.exists()) {
        logger.log(
            'Snapshot for $packageName does not exist. Did you forget to run start?');
        return;
      }

      logger.log('Finding current package path for $packageName...');
      final currentPackagePath = findPackagePath(packageName, logger);
      if (currentPackagePath == null) {
        logger.log('Current state of $packageName not found.');
        return;
      }

      final patchFilePath = path.join('patches', '$packageName.patch');
      logger.log('Preparing to create patch file at $patchFilePath');
      final patchFile = File(patchFilePath);

      // Ensure the patches directory exists
      if (!await patchFile.parent.exists()) {
        logger.log('Creating patches directory...');
        await patchFile.parent.create(recursive: true);
      }

      // Running diff command to generate the patch
      logger.log('Generating patch file using diff...');
      final result =
          await Process.run('diff', ['-ruN', tempDirPath, currentPackagePath]);
      if (result.stdout.toString().isNotEmpty) {
        await patchFile.writeAsString(result.stdout);
        logger.log('Patch created at $patchFilePath');
      } else {
        logger.log('No changes detected for $packageName, no patch created.');
      }

      // Cleanup: remove the snapshot directory
      logger.log('Cleaning up temporary directory...');
      await tempDir.delete(recursive: true);
      logger.log('Patch finalization for $packageName completed.');
    } catch (e) {
      logger.log('Error finalizing patch for $packageName: $e');
    }
  }
}

String? findPackagePath(String packageName, LoggerInterface logger) {
  final pubCacheDir = getPubCacheDir(logger);
  if (pubCacheDir == null) {
    logger.log('Unable to locate the .pub-cache directory.');
    return null;
  }

  final hostedDirPath = path.join(pubCacheDir, 'hosted');
  if (!Directory(hostedDirPath).existsSync()) {
    logger.log('Hosted directory does not exist at $hostedDirPath');
    return null;
  }

  final packageDirPattern = RegExp('^${RegExp.escape(packageName)}-');

  // Iterate through all source subdirectories under the hosted directory
  final sourceDirs = Directory(hostedDirPath).listSync().whereType<Directory>();
  for (var sourceDir in sourceDirs) {
    try {
      final packages = sourceDir.listSync().whereType<Directory>();
      for (var packageDir in packages) {
        if (packageDirPattern.hasMatch(path.basename(packageDir.path))) {
          logger.log('Found package directory: ${packageDir.path}');
          return packageDir.path;
        }
      }
    } catch (e) {
      logger.log('Error searching in source directory ${sourceDir.path}: $e');
    }
  }

  logger.log('Package $packageName not found in any hosted source directory.');
  return null;
}

String? getPubCacheDir(LoggerInterface logger) {
  // Check if PUB_CACHE environment variable is set
  var pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null) {
    logger.log('PUB_CACHE environment variable is set to: $pubCache');
    if (Directory(pubCache).existsSync()) {
      logger.log(
          'Found .pub-cache directory at $pubCache (from PUB_CACHE environment variable).');
      return pubCache;
    } else {
      logger.log(
          'Directory specified in PUB_CACHE environment variable does not exist: $pubCache');
    }
  } else {
    logger.log('PUB_CACHE environment variable is not set.');
  }

  // Default .pub-cache locations
  if (Platform.isWindows) {
    var appData = Platform.environment['APPDATA'];
    if (appData != null) {
      logger.log('APPDATA environment variable is set to: $appData');
      var pubCachePath = path.join(appData, 'Pub', 'Cache');
      if (Directory(pubCachePath).existsSync()) {
        logger.log(
            'Found .pub-cache directory at $pubCachePath (Windows default location).');
        return pubCachePath;
      } else {
        logger.log(
            'Default .pub-cache directory does not exist at $pubCachePath');
      }
    } else {
      logger.log('APPDATA environment variable is not set.');
    }
  } else {
    // Linux and MacOS
    var home = Platform.environment['HOME'];
    if (home != null) {
      logger.log('HOME environment variable is set to: $home');
      var pubCachePath = path.join(home, '.pub-cache');
      if (Directory(pubCachePath).existsSync()) {
        logger.log(
            'Found .pub-cache directory at $pubCachePath (Linux/MacOS default location).');
        return pubCachePath;
      } else {
        logger.log(
            'Default .pub-cache directory does not exist at $pubCachePath');
      }
    } else {
      logger.log('HOME environment variable is not set.');
    }
  }

  logger.log('Could not determine the .pub-cache directory location.');
  return null;
}

Future<void> copyDirectory(
    Directory source, Directory destination, LoggerInterface logger) async {
  logger.log('Starting to copy from ${source.path} to ${destination.path}');
  try {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectoryPath =
            path.join(destination.absolute.path, path.basename(entity.path));
        logger.log(
            'Found directory: ${entity.path}, preparing to copy to $newDirectoryPath');
        var newDirectory = Directory(newDirectoryPath);
        await newDirectory.create();
        logger.log('Created directory at $newDirectoryPath');
        await copyDirectory(entity, newDirectory, logger);
      } else if (entity is File) {
        var newFilePath =
            path.join(destination.path, path.basename(entity.path));
        logger.log(
            'Found file: ${entity.path}, preparing to copy to $newFilePath');
        try {
          await entity.copy(newFilePath);
          logger.log('Copied file to $newFilePath');
        } catch (e) {
          logger.log('Failed to copy file ${entity.path} to $newFilePath: $e');
        }
      }
    }
    logger
        .log('Successfully copied from ${source.path} to ${destination.path}');
  } catch (e) {
    logger.log(
        'Error copying directory ${source.path} to ${destination.path}: $e');
  }
}

void applyPatches(LoggerInterface logger) async {
  logger.log('Starting to apply patches...');
  final patchesDir = Directory('patches');
  if (!patchesDir.existsSync()) {
    logger.log('No patches directory found. No patches to apply.');
    return;
  }

  logger.log('Patches directory found. Scanning for patch files...');
  await for (var entity in patchesDir.list()) {
    if (entity is File && entity.path.endsWith('.patch')) {
      final packageName = path.basenameWithoutExtension(entity.path);
      logger.log(
          'Found patch file for $packageName. Attempting to find package path...');
      final packagePath = findPackagePath(packageName, logger);
      if (packagePath == null) {
        logger.log('Package path for $packageName not found. Skipping patch.');
        continue;
      }

      logger.log(
          'Applying patch for $packageName located at ${entity.path} to $packagePath');
      final patchResult = await Process.run(
          'patch', ['-d', packagePath, '-p1', '-i', entity.path]);
      if (patchResult.exitCode == 0) {
        logger.log('Patch applied successfully for $packageName.');
      } else {
        logger.log(
            'Failed to apply patch for $packageName. Error: ${patchResult.stderr}');
      }
    } else {
      logger.log('No valid patch files found in patches directory.');
    }
  }
  logger.log('Finished applying patches.');
}
