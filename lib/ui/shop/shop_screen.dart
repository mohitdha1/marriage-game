import 'package:flutter/material.dart';

/// Opens the shop, finishing once the player leaves it.
Future<void> openShop(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'shop'),
    builder: (_) => const ShopScreen(),
  ),
);

/// The shop, where coin and gem packs will be sold. Until the packs are in,
/// it says they're on the way.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('shop'),
    appBar: AppBar(title: const Text('Shop')),
    body: const Center(child: Text('Coin and gem packs are on the way.')),
  );
}
