import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'health_data_provider.dart';

/// Stub implementation for platforms without Google Fit.
class GoogleFitProvider implements HealthDataProvider {
  static const connectedKey = 'googleFitConnected';

  Future<bool> requestAuthorization() async => false;

  Future<bool> isConnected() async => false;

  Future<void> disconnect() async {}

  @override
  Future<List<HealthDataPoint>> fetch(DateTimeRange range) async => [];

  @override
  Stream<HealthDataPoint> watchChanges() => const Stream.empty();
}
