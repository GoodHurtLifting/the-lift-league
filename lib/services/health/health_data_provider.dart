import 'package:flutter/material.dart';
import 'health_stub.dart'
    if (dart.library.io) 'package:health/health.dart';

abstract class HealthDataProvider {
  Future<List<HealthDataPoint>> fetch(DateTimeRange range);
  Stream<HealthDataPoint> watchChanges();
}
