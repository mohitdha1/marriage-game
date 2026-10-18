import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/economy_config.dart';

/// Reads the economy's amounts from the app's data file.
Future<EconomyConfig> loadEconomyConfig([AssetBundle? bundle]) async =>
    EconomyConfig.fromJson(
      await (bundle ?? rootBundle).loadString(EconomyConfig.asset),
    );

/// The economy's amounts, read from the app's data file the first time
/// they're needed, and kept.
final economyConfigProvider = FutureProvider<EconomyConfig>(
  (ref) => loadEconomyConfig(),
);
