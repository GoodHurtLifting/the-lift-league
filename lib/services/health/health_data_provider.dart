import 'package:flutter/material.dart';
import 'health_samples.dart';

abstract class HealthDataProvider {
  Future<List<HealthSample>> fetch(DateTimeRange range);
  Stream<HealthSample> watchChanges();
}
