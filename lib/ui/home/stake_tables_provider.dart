import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/stake_tables.dart';

/// Reads the stake tables from the app's data file.
Future<StakeTables> loadStakeTables([AssetBundle? bundle]) async =>
    StakeTables.fromJson(
      await (bundle ?? rootBundle).loadString(StakeTables.asset),
    );

/// The stake tables, loaded once at start-up, where the app overrides this
/// with what [loadStakeTables] read.
final stakeTablesProvider = Provider<StakeTables>(
  (ref) => throw StateError('The stake tables are loaded at start-up'),
);
