import 'package:flutter/material.dart';
import 'health_stub.dart'
    if (dart.library.io) 'package:health/health.dart' as health;

import 'health_data_provider.dart';

/// Stub implementation for platforms without Health integration.
class AppleHealthProvider implements HealthDataProvider {
  static const connectedKey = 'appleHealthConnected';

  Future<bool> requestAuthorization() async => false;

  Future<bool> isConnected() async => false;

  Future<void> disconnect() async {}

  @override
  Future<List<health.HealthDataPoint>> fetch(DateTimeRange range) async => [];

  @override
  Stream<health.HealthDataPoint> watchChanges() => const Stream.empty();
}
