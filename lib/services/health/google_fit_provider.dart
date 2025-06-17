import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'health_data_provider.dart';

class GoogleFitProvider implements HealthDataProvider {
  final HealthFactory _health = HealthFactory(useHealthConnectIfAvailable: true);

  Future<bool> requestAuthorization() async {
    final types = <HealthDataType>[]; // TODO: specify data types
    return _health.requestAuthorization(types);
  }

  @override
  Future<List<HealthSample>> fetch(DateTimeRange range) async {
    // TODO: fetch data from Google Fit
    return [];
  }

  @override
  Stream<HealthSample> watchChanges() {
    // TODO: implement change stream via HealthFactory
    return const Stream.empty();
  }
}
