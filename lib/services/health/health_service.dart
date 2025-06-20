import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'fitbit_provider.dart';

import 'health_data_provider.dart';

/// Top-level background sync task for Workmanager
void healthSyncWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await HealthService.runBackgroundSync();
    return Future.value(true);
  });
}


class HealthService {
  final List<HealthDataProvider> _providers = [];

  /// Registers only the appropriate providers for the current platform.
  void registerAvailableProviders() {
    _providers.clear();
    _providers.add(FitbitProvider());
  }

  /// Sets up background sync for health data.
  ///
  /// Call **once in main()** after app and Firebase init.
  static void registerBackgroundSync() {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      Workmanager().initialize(
        healthSyncWorkmanagerDispatcher,
        isInDebugMode: false,
      );
      Workmanager().registerPeriodicTask(
        'healthSync',
        'healthSync',
        frequency: const Duration(hours: 6),
      );
    }
  }

  /// Call this to trigger background sync logic in Workmanager.
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
