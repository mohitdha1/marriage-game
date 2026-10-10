import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/preferences.dart';

/// The player's play-money coins, saved between launches. Each round's
/// result moves the balance one coin per point; it never goes below zero.
final coinsProvider = NotifierProvider<CoinsController, int>(
  CoinsController.new,
);

class CoinsController extends Notifier<int> {
  /// What a new player starts with.
  static const startingBalance = 1000;

  static const _key = 'coins.balance';

  @override
  int build() => ref.watch(preferencesProvider).getInt(_key) ?? startingBalance;

  /// Adds [points] coins, or takes them away when [points] is negative.
  void addRoundResult(int points) {
    state = (state + points).clamp(0, 1 << 31);
    ref.read(preferencesProvider).setInt(_key, state);
  }
}
