import 'package:flutter/material.dart';
import 'health_stub.dart'
    if (dart.library.io) 'package:health/health.dart' as health;

abstract class HealthDataProvider {
  Future<List<health.HealthDataPoint>> fetch(DateTimeRange range);
  Stream<health.HealthDataPoint> watchChanges();
}
