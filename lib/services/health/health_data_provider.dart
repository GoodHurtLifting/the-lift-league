import 'package:flutter/material.dart';
import 'package:health/health.dart';

abstract class HealthDataProvider {
  Future<List<HealthSample>> fetch(DateTimeRange range);
  Stream<HealthSample> watchChanges();
}
