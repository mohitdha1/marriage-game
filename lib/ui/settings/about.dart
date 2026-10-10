import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version, as "1.0.0 (1)".
Future<String> appVersion() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}

/// Shows the app's name, version and credits, with a button to the
/// licences of everything it's built from.
Future<void> showAbout(BuildContext context) async {
  final version = await appVersion();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'Marriage',
    applicationVersion: version,
    applicationLegalese: '© 2026 Mohit Dhamala',
    children: const [
      SizedBox(height: 12),
      Text(
        'The Nepali card game, against bots or with friends.\n\n'
        'Court card figures: Vector Playing Cards by Byron Knoll, in the '
        'public domain.',
        key: Key('about-credits'),
      ),
    ],
  );
}

/// Adds the court card art's licence to the app's licence page, beside the
/// packages the app is built from.
void registerArtLicence() {
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['Vector Playing Cards (court card figures)'],
        'The court card figures are from Vector Playing Cards, originally '
        'drawn by Byron Knoll (https://github.com/notpeter/'
        'Vector-Playing-Cards). They are released into the public domain, '
        'or under the WTFPL where public domain is not recognised: "do as '
        'you see fit: relicense, embed in commercial, non-commercial or '
        'open-source software, etc."',
      ),
    ),
  );
}
