import 'package:flutter/material.dart';

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
