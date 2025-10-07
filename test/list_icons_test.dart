import 'package:flutter_test/flutter_test.dart';
import 'package:hypr_flutter/services/app_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('list available desktop icons', () async {
    final catalog = AppCatalogService();
    await catalog.initialize();

    final apps = catalog.applications;
    final List<String> resolved = <String>[];
    final List<String> missing = <String>[];

    for (final app in apps) {
      final icon = await catalog.iconPathFor(app);
      if (icon != null) {
        resolved.add('${app.name} -> $icon');
      } else {
        missing.add('${app.name} (icon key: ${app.iconKey ?? 'n/a'})');
      }
    }

    resolved.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    missing.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    print('Total applications: ${apps.length}');
    print('Icons resolved   : ${resolved.length}');
    print('Icons missing    : ${missing.length}');
    print('');

    const sampleSize = 20;
    print('Resolved icon sample (first ${resolved.length < sampleSize ? resolved.length : sampleSize}):');
    for (final entry in resolved.take(sampleSize)) {
      print('  $entry');
    }

    print('');
    print('Missing icon sample (first ${missing.length < sampleSize ? missing.length : sampleSize}):');
    for (final entry in missing.take(sampleSize)) {
      print('  $entry');
    }

    expect(apps, isNotEmpty);
  });
}
