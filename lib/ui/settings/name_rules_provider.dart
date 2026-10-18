import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/name_rules.dart';

/// Reads the name rules' blocked words from [bundle], the app's own assets
/// unless given.
Future<NameRules> loadNameRules([AssetBundle? bundle]) async =>
    NameRules.fromList(
      await (bundle ?? rootBundle).loadString(NameRules.asset),
    );

/// The rules display names are checked against.
final nameRulesProvider = FutureProvider<NameRules>((ref) => loadNameRules());
