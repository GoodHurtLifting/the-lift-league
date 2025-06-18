import 'package:flutter/material.dart';
import 'health_stub.dart'
    if (dart.library.io) 'package:health/health.dart' as health;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'health_data_provider.dart';
import '../db_service.dart';

class GoogleFitProvider implements HealthDataProvider {
  final health.HealthFactory _health = health.HealthFactory(useHealthConnectIfAvailable: true);
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const connectedKey = 'googleFitConnected';

  Future<bool> requestAuthorization() async {
    final types = <health.HealthDataType>[health.HealthDataType.STEPS, health.HealthDataType.ACTIVE_ENERGY_BURNED];
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
  Future<List<health.HealthDataPoint>> fetch(DateTimeRange range) async {
    if (!await isConnected()) return [];
    final db = DBService();
    await db.insertWeightSample(
      date: range.end,
      value: 75.0,
      source: 'google',
    );
    await db.insertEnergySample(
      date: range.end,
      kcalIn: 2200,
      kcalOut: 2600,
      source: 'google',
    );
    return [];
  }

  @override
  Stream<health.HealthDataPoint> watchChanges() {
    // TODO: implement change stream via HealthFactory
    return const Stream.empty();
  }
}
