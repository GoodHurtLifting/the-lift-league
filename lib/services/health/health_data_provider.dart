import 'package:flutter/material.dart';
import 'health_stub.dart' as health;

abstract class HealthDataProvider {
  Future<List<health.HealthDataPoint>> fetch(DateTimeRange range);
  Stream<health.HealthDataPoint> watchChanges();
}
