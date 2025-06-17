import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fitbitter/fitbitter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'health_data_provider.dart';
import '../db_service.dart';

class FitbitProvider implements HealthDataProvider {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  static const connectedKey = 'fitbitConnected';
  static const tokenKey = 'fitbitAccessToken';
  static const refreshKey = 'fitbitRefreshToken';

  String? accessToken;

  FitbitProvider({this.accessToken});

  Future<bool> authorize() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        '<your_client_id>',
        '<your_redirect_uri>',
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://www.fitbit.com/oauth2/authorize',
          tokenEndpoint: 'https://api.fitbit.com/oauth2/token',
        ),
        scopes: ['activity', 'heartrate', 'sleep', 'nutrition', 'profile'],
      ),
    );

    if (result != null) {
      accessToken = result.accessToken;
      await _storage.write(key: tokenKey, value: result.accessToken);
      if (result.refreshToken != null) {
        await _storage.write(key: refreshKey, value: result.refreshToken);
      }
      await _storage.write(key: connectedKey, value: 'true');
      return true;
    }
    return false;
  }

  Future<bool> isConnected() async => (await _storage.read(key: connectedKey)) == 'true';

  Future<void> disconnect() async {
    accessToken = null;
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: refreshKey);
    await _storage.delete(key: connectedKey);
  }

  @override
  Future<List<HealthDataPoint>> fetch(DateTimeRange range) async {
    if (!await isConnected()) return [];
    final db = DBService();
    await db.insertWeightSample(
      date: range.end,
      value: 72.0,
      source: 'fitbit',
    );
    await db.insertEnergySample(
      date: range.end,
      kcalIn: 2100,
      kcalOut: 2400,
      source: 'fitbit',
    );
    return [];
  }

  @override
  Stream<HealthDataPoint> watchChanges() {
    // Fitbit does not support realtime updates in this stub
    return const Stream.empty();
  }
}
