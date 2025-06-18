import 'package:flutter/material.dart';
import 'health_stub.dart'
if (dart.library.io) 'package:health/health.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'health_data_provider.dart';
import '../db_service.dart';

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
  Future<List<HealthDataPoint>> fetch(DateTimeRange range) async {
    if (!await isConnected()) return [];
    final db = DBService();
    await db.insertWeightSample(
      date: range.end,
      value: 70.0,
      source: 'apple',
    );
    await db.insertEnergySample(
      date: range.end,
      kcalIn: 2000,
      kcalOut: 2500,
      source: 'apple',
    );
    return [];
  }

  @override
  Stream<HealthDataPoint> watchChanges() {
    // TODO: implement change stream via HealthFactory
    return const Stream.empty();
  }
}
