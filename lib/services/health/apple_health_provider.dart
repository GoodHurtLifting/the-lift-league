import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'health_data_provider.dart';

class AppleHealthProvider implements HealthDataProvider {
  final HealthFactory _health = HealthFactory();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const connectedKey = 'appleHealthConnected';

  Future<bool> requestAuthorization() async {
    final types = <HealthDataType>[HealthDataType.STEPS, HealthDataType.ACTIVE_ENERGY_BURNED];
    final granted = await _health.requestAuthorization(types);
    if (granted) {
      await _storage.write(key: connectedKey, value: 'true');
    }
    return granted;
  }

  Future<bool> isConnected() async => (await _storage.read(key: connectedKey)) == 'true';

  Future<void> disconnect() async {
    await _storage.delete(key: connectedKey);
  }

  @override
  Future<List<HealthSample>> fetch(DateTimeRange range) async {
    // TODO: fetch data from Apple Health
    return [];
  }

  @override
  Stream<HealthSample> watchChanges() {
    // TODO: implement change stream via HealthFactory
    return const Stream.empty();
  }
}
