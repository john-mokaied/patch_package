// test/patch_package_test.dart

import 'package:patch_package/patch_package.dart';
import 'package:patch_package/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('findPackagePath returns a valid path for existing package', () {
    final logger = MockLogger();

    final path = findPackagePath('patch_package', logger);

    expect(path, isNotNull);
  });
}
