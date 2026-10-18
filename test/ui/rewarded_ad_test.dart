import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marriage_game/data/economy_config.dart';
import 'package:marriage_game/ui/ads/rewarded_ad_service.dart';
import 'package:marriage_game/ui/ads/watch_ad.dart';

final noon = DateTime(2026, 10, 17, 12);

/// A screen with a button that shows the test ad and keeps the result.
class _AdLauncher extends StatelessWidget {
  const _AdLauncher(this.onResult);

  final void Function(AdResult) onResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () async =>
          onResult(await const FakeRewardedAdService().show(context)),
      child: const Text('Show ad'),
    ),
  );
}

void main() {
  group('The test ad', () {
    testWidgets('pays out after 3 seconds', (tester) async {
      AdResult? watched;
      await tester.pumpWidget(
        MaterialApp(home: _AdLauncher((result) => watched = result)),
      );
      await tester.tap(find.text('Show ad'));
      await tester.pumpAndSettle();
      expect(find.text('Test ad'), findsOneWidget);
      expect(find.text('Reward in 3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(watched, isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(watched, AdResult.watched);
      expect(find.text('Test ad'), findsNothing);
    });

    testWidgets('closed early, it pays nothing', (tester) async {
      AdResult? watched;
      await tester.pumpWidget(
        MaterialApp(home: _AdLauncher((result) => watched = result)),
      );
      await tester.tap(find.text('Show ad'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ad-close')));
      await tester.pumpAndSettle();

      expect(watched, AdResult.skipped);
    });
  });

  test('the offer names the reward, and the ads left', () {
    expect(
      adOfferText(const Reward(coins: 2500)),
      'Watch an ad for 2,500 coins',
    );
    expect(adOfferText(const Reward(gems: 1)), 'Watch an ad for 1 gem');
    expect(adsLeftText(3), '3 left today');
  });

  test('no ads or shop during a hand: nothing at the table can reach them', () {
    // The table screen and the game state never import the ads or the
    // shop, so no hand can be interrupted by either.
    final atTheTable = [
      ...Directory('lib/ui/table').listSync(recursive: true),
      ...Directory('lib/ui/state').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final file in atTheTable) {
      final source = file.readAsStringSync();
      for (final banned in ['ads/', 'shop/', 'entry_fee.dart']) {
        expect(
          source,
          isNot(contains(banned)),
          reason: '${file.path} must not reach $banned',
        );
      }
    }
  });
}
