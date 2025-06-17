import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:fitbitter/fitbitter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'health_data_provider.dart';

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
