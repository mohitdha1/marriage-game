import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sends every uncaught error to Crashlytics: errors inside Flutter, such
/// as a widget failing to build, and errors anywhere else in the app's
/// Dart code.
void reportCrashes(FirebaseCrashlytics crashlytics) {
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Crashes the app on purpose, to check reports reach Crashlytics. `null`
/// where there's nothing to report to; offered only in debug builds.
final testCrashProvider = Provider<VoidCallback?>((ref) => null);
