import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stake_tables.dart';

/// Reads the stake tables from the app's data file.
Future<StakeTables> loadStakeTables([AssetBundle? bundle]) async =>
    StakeTables.fromJson(
      await (bundle ?? rootBundle).loadString(StakeTables.asset),
    );

/// The stake tables, read from the app's data file the first time they're
/// needed, and kept.
final stakeTablesProvider = FutureProvider<StakeTables>(
  (ref) => loadStakeTables(),
);
