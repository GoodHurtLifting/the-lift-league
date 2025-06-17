import 'package:flutter/material.dart';
import 'package:health/health.dart';

abstract class HealthDataProvider {
  Future<List<HealthDataPoint>> fetch(DateTimeRange range);
  Stream<HealthDataPoint> watchChanges();
}
