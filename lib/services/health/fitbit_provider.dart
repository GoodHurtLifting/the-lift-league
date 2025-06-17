import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fitbitter/fitbitter.dart';

import 'health_data_provider.dart';

class FitbitProvider implements HealthDataProvider {
  final String? accessToken;

  FitbitProvider({this.accessToken});

  @override
  Future<List<HealthSample>> fetch(DateTimeRange range) async {
    // TODO: use Fitbitter to fetch data with [accessToken]
    return [];
  }

  @override
  Stream<HealthSample> watchChanges() {
    // Fitbit does not support realtime updates in this stub
    return const Stream.empty();
  }
}
