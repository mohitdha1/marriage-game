import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Loads Roboto, the default Android font, from the Flutter SDK into the
/// test environment.
///
/// Widget tests normally draw text in a placeholder font whose letters are
/// all one square wide and whose lines are shorter than real fonts'. That's
/// fine for most tests, but layout tests that check what fits on a phone
/// need real text sizes.
Future<void> loadRealFonts() async {
  final fontsDir = p.join(
    _flutterRoot(),
    'bin',
    'cache',
    'artifacts',
    'material_fonts',
  );
  final roboto = FontLoader('Roboto');
  for (final style in ['Regular', 'Medium', 'Bold']) {
    final bytes = File(p.join(fontsDir, 'Roboto-$style.ttf')).readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
}

/// Loads the Material icon font from the Flutter SDK, so icons draw as
/// themselves rather than as empty boxes, for rendered screenshots.
Future<void> loadMaterialIcons() async {
  final bytes = File(
    p.join(
      _flutterRoot(),
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

/// The Flutter SDK folder: from FLUTTER_ROOT if the test runner set it,
/// otherwise found from the test runner's own location inside the SDK.
String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null) return fromEnv;
  var dir = File(Platform.resolvedExecutable).parent;
  while (!File(p.join(dir.path, 'bin', 'flutter')).existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('Could not find the Flutter SDK for real fonts');
    }
    dir = dir.parent;
  }
  return dir.path;
}
