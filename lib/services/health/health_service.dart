import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:background_fetch/background_fetch.dart';

void _workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final service = HealthService();
    service.registerAvailableProviders();
    await service.sync(DateTimeRange(
      start: DateTime.now().subtract(const Duration(hours: 24)),
      end: DateTime.now(),
    ));
    return Future.value(true);
  });
}

void _backgroundFetchTask(String taskId) async {
  final service = HealthService();
  service.registerAvailableProviders();
  await service.sync(DateTimeRange(
    start: DateTime.now().subtract(const Duration(hours: 24)),
    end: DateTime.now(),
  ));
  BackgroundFetch.finish(taskId);
}

import 'apple_health_provider.dart';
import 'fitbit_provider.dart';
import 'google_fit_provider.dart';
import 'health_data_provider.dart';

class HealthService {
  final List<HealthDataProvider> _providers = [];

  void registerAvailableProviders() {
    // In a real implementation you would check platform/permissions
    _providers.clear();
    // These are stubs, but we register them so callers can use the facade
    _providers.add(AppleHealthProvider());
    _providers.add(GoogleFitProvider());
    _providers.add(FitbitProvider());
  }

  void registerBackgroundSync() {
    if (Platform.isAndroid) {
      Workmanager().initialize(_workmanagerCallbackDispatcher);
      Workmanager().registerPeriodicTask(
        'healthSync',
        'healthSync',
        frequency: const Duration(hours: 6),
      );
    } else if (Platform.isIOS) {
      BackgroundFetch.configure(
        const BackgroundFetchConfig(
          minimumFetchInterval: 360,
          enableHeadless: true,
          startOnBoot: true,
        ),
        _backgroundFetchTask,
      );
    }
  }

  Future<void> sync(DateTimeRange range) async {
    for (final provider in _providers) {
      try {
        await provider.fetch(range);
      } catch (_) {
        // ignore individual provider errors
      }
    }
  }
}
