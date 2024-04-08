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
        await tempDir.delete(recursive: true);
      }
      await tempDir.create();

      appLog('Saving current state of $packageName...');
      await copyDirectory(packageDir, tempDir, logger);
      appLog('Snapshot saved in $tempDirPath');
    } catch (e) {
      appLog('Error saving snapshot of $packageName: $e');
    }
  }

  void done() async {
    try {
      final tempDirPath = path.join(Directory.systemTemp.path, packageName);
      final tempDir = Directory(tempDirPath);
      if (!await tempDir.exists()) {
        appLog(
            'Snapshot for $packageName does not exist. Did you forget to run start?');
        return;
      }

      final currentPackagePath = findPackagePath(packageName, logger);
      if (currentPackagePath == null) {
        appLog('Current state of $packageName not found.');
        return;
      }

      final patchFilePath = path.join('patches', '$packageName.patch');
      final patchFile = File(patchFilePath);

      // Ensure the patches directory exists
      if (!await patchFile.parent.exists()) {
        await patchFile.parent.create(recursive: true);
      }

      // Running diff command to generate the patch
      final result =
          await Process.run('diff', ['-ruN', tempDirPath, currentPackagePath]);
      if (result.stdout.toString().isNotEmpty) {
        await patchFile.writeAsString(result.stdout);
        appLog('Patch created at $patchFilePath');
      } else {
        appLog('No changes detected for $packageName.');
      }

      // Cleanup: remove the snapshot directory
      await tempDir.delete(recursive: true);
    } catch (e) {
      appLog('Error finalizing patch for $packageName: $e');
    }
  }
}

String? findPackagePath(String packageName, LoggerInterface logger) {
  final pubCacheDir = getPubCacheDir(logger);
  if (pubCacheDir == null) {
    logger.log('Unable to locate the .pub-cache directory.');
    return null;
  }

  // Constructing the expected package directory path pattern
  final packageDirPattern = RegExp(r'^' + RegExp.escape(packageName) + r'-\d');

  try {
    final entries = Directory(pubCacheDir).listSync();
    for (var entry in entries) {
      if (entry is Directory &&
          packageDirPattern.hasMatch(path.basename(entry.path))) {
        return entry.path;
      }
    }
  } catch (e) {
    logger.log('Error searching for $packageName in .pub-cache: $e');
  }

  logger.log('Package $packageName not found in .pub-cache.');
  return null;
}

String? getPubCacheDir(LoggerInterface logger) {
  // Check if PUB_CACHE environment variable is set
  var pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null && Directory(pubCache).existsSync()) {
    return pubCache;
  }

  // Default .pub-cache locations
  if (Platform.isWindows) {
    var appData = Platform.environment['APPDATA'];
    if (appData != null) {
      var pubCachePath = path.join(appData, 'Pub', 'Cache');
      if (Directory(pubCachePath).existsSync()) {
        return pubCachePath;
      }
    }
  } else {
    // Linux and MacOS
    var home = Platform.environment['HOME'];
    if (home != null) {
      var pubCachePath = path.join(home, '.pub-cache');
      if (Directory(pubCachePath).existsSync()) {
        return pubCachePath;
      }
    }
  }

  logger.log('Could not determine the .pub-cache directory location.');
  return null;
}

Future<void> copyDirectory(
    Directory source, Directory destination, LoggerInterface logger) async {
  try {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(
            path.join(destination.absolute.path, path.basename(entity.path)));
        await newDirectory.create();
        await copyDirectory(entity, newDirectory, logger);
      } else if (entity is File) {
        try {
          await entity
              .copy(path.join(destination.path, path.basename(entity.path)));
        } catch (e) {
          logger.log('Failed to copy file ${entity.path}: $e');
        }
      }
    }
  } catch (e) {
    logger.log(
        'Error copying directory ${source.path} to ${destination.path}: $e');
  }
}

void applyPatches(LoggerInterface logger) async {
  final patchesDir = Directory('patches');
  if (!patchesDir.existsSync()) {
    logger.log('No patches directory found. No patches to apply.');
    return;
  }

  await for (var entity in patchesDir.list()) {
    if (entity is File && entity.path.endsWith('.patch')) {
      final packageName = path.basenameWithoutExtension(entity.path);
      final packagePath = findPackagePath(packageName, logger);
      if (packagePath == null) {
        logger.log('Package path for $packageName not found. Skipping patch.');
        continue;
      }

      logger.log('Applying patch for $packageName...');
      final patchResult = await Process.run(
          'patch', ['-d', packagePath, '-p1', '-i', entity.path]);
      if (patchResult.exitCode == 0) {
        logger.log('Patch applied successfully for $packageName.');
      } else {
        logger.log(
            'Failed to apply patch for $packageName: ${patchResult.stderr}');
      }
    }
  }
}
