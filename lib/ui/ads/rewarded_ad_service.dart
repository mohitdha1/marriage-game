import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows rewarded ads: the player watches one to the end to earn a reward.
/// An interface so a real ad network can replace [FakeRewardedAdService]
/// later without touching the screens that offer ads.
///
/// Ads are only ever offered away from the table (the home screen, the
/// shop), never during a hand.
abstract interface class RewardedAdService {
  /// Shows an ad over [context], and completes with whether it was watched
  /// to the end, so the reward is earned.
  Future<bool> show(BuildContext context);
}

/// Stands in for a real ad network: a test screen that runs for [length]
/// and then rewards the player. Closing it early earns nothing.
class FakeRewardedAdService implements RewardedAdService {
  const FakeRewardedAdService({this.length = const Duration(seconds: 3)});

  final Duration length;

  @override
  Future<bool> show(BuildContext context) async =>
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => FakeAdScreen(length: length),
        ),
      ) ??
      false;
}

/// The test ad: a countdown, then it closes with the reward earned.
class FakeAdScreen extends StatefulWidget {
  const FakeAdScreen({super.key, required this.length});

  final Duration length;

  @override
  State<FakeAdScreen> createState() => _FakeAdScreenState();
}

class _FakeAdScreenState extends State<FakeAdScreen> {
  late final Timer _ticker;
  late int _secondsLeft = widget.length.inSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _ticker.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving early, Back included, earns nothing.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF263238),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Test ad',
                      style: TextStyle(color: Colors.white, fontSize: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reward in $_secondsLeft',
                      key: const Key('ad-countdown'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const Key('ad-close'),
                  tooltip: 'Close without the reward',
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's rewarded ads: the test ad until a real network is added.
final rewardedAdServiceProvider = Provider<RewardedAdService>(
  (ref) => const FakeRewardedAdService(),
);
