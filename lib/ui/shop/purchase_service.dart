import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';

/// How a purchase went.
enum PurchaseResult {
  /// Paid for: the pack is the player's.
  purchased,

  /// The player backed out: nothing paid, nothing given.
  cancelled,

  /// The store couldn't take the payment: nothing paid, nothing given.
  unavailable,
}

/// Sells the shop's packs for real money. An interface so Google Play
/// Billing can replace [FakePurchaseService] later without touching the
/// shop.
abstract interface class PurchaseService {
  /// Whether packs can be bought at all. When not, the shop shows them as
  /// coming soon.
  bool get canPurchase;

  /// Asks the store to sell [pack], and completes with how it went. Only a
  /// pack [PurchaseResult.purchased] is given to the player.
  Future<PurchaseResult> buy(ShopPack pack);
}

/// Stands in for the store until billing is added: every purchase goes
/// through, free, in debug builds, and none can be made in release builds,
/// where the packs show as coming soon.
class FakePurchaseService implements PurchaseService {
  const FakePurchaseService({this.canPurchase = kDebugMode});

  @override
  final bool canPurchase;

  @override
  Future<PurchaseResult> buy(ShopPack pack) async =>
      canPurchase ? PurchaseResult.purchased : PurchaseResult.unavailable;
}

/// The app's store: the stand-in until Google Play Billing is added.
final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => const FakePurchaseService(),
);
