import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about.dart';

/// Opens [link] outside the app, in the browser. Tests swap it.
final openLinkProvider = Provider<Future<bool> Function(Uri link)>(
  (ref) =>
      (link) => launchUrl(link, mode: LaunchMode.externalApplication),
);

/// Where feedback goes: a new issue on the game's GitHub page, started
/// with a short template and the app's [version].
Uri feedbackLink(String version) =>
    Uri.https('github.com', '/mohitdha1/marriage-game/issues/new', {
      'title': 'Feedback: ',
      'body':
          'What happened:\n\n\nWhat I expected:\n\n\n'
          '---\nMarriage $version',
    });

/// Opens the feedback page with [open], or says so if it can't be opened.
Future<void> sendFeedback(
  BuildContext context,
  Future<bool> Function(Uri link) open,
) async {
  final link = feedbackLink(await appVersion());
  final opened = await open(link);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t open the browser. Feedback is welcome at '
            'github.com/mohitdha1/marriage-game.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
