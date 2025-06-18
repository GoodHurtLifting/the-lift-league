import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:background_fetch/background_fetch.dart';

import 'apple_health_provider_stub.dart'
    if (dart.library.io) 'apple_health_provider.dart';
import 'fitbit_provider.dart';
import 'google_fit_provider_stub.dart'
    if (dart.library.io) 'google_fit_provider.dart';
import 'health_data_provider.dart';

/// Top-level background sync task for Workmanager (Android)
void healthSyncWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await HealthService.runBackgroundSync();
    return Future.value(true);
  });
}

/// Top-level background fetch callback (iOS)
void healthSyncBackgroundFetch(String taskId) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HealthService.runBackgroundSync();
  BackgroundFetch.finish(taskId);
}

class HealthService {
  final List<HealthDataProvider> _providers = [];

  /// Registers only the appropriate providers for the current platform.
  void registerAvailableProviders() {
    _providers.clear();
    if (Platform.isIOS) _providers.add(AppleHealthProvider());
    if (Platform.isAndroid) _providers.add(GoogleFitProvider());
    _providers.add(FitbitProvider()); // Fitbit can be available on both
  }

  /// Sets up background sync for health data.
  ///
  /// Call **once in main()** after app and Firebase init.
  static void registerBackgroundSync() {
    if (Platform.isAndroid) {
      Workmanager().initialize(
        healthSyncWorkmanagerDispatcher,
        isInDebugMode: false,
      );
      Workmanager().registerPeriodicTask(
        'healthSync',
        'healthSync',
        frequency: const Duration(hours: 6),
      );
    } else if (Platform.isIOS) {
      BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 360, // minutes (6 hours)
          enableHeadless: true,
          startOnBoot: true,
        ),
        healthSyncBackgroundFetch,
      );
    }
  }

  /// Call this to trigger background sync logic in both bg fetch and workmanager.
  /// Should be called only from top-level background functions.
  static Future<void> runBackgroundSync() async {
    try {
      final service = HealthService();
      service.registerAvailableProviders();
      await service.sync(DateTimeRange(
        start: DateTime.now().subtract(const Duration(hours: 24)),
        end: DateTime.now(),
      ));
      // You could add custom logs or analytics here
    } catch (e, stack) {
      // Print/log errors, you could also use Crashlytics here if desired
      print('[HealthService] Background sync failed: $e\n$stack');
    }
  }

  /// Runs sync for the given time range for all providers.
  Future<void> sync(DateTimeRange range) async {
    for (final provider in _providers) {
      try {
        final samples = await provider.fetch(range);
        // TODO: Persist [samples] into your database (SQLite, etc)
        // Example: await DBService().saveHealthDataPoints(samples);
      } catch (e, stack) {
        print('[HealthService] Error syncing ${provider.runtimeType}: $e\n$stack');
      }
    }
  }
}
