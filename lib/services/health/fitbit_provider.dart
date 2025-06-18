import 'package:flutter/material.dart';
import 'health_stub.dart'
    if (dart.library.io) 'package:health/health.dart' as health;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import 'fitbit_credentials.dart';
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
        fitbitClientId,
        fitbitRedirectUri,
        clientSecret: fitbitClientSecret.isEmpty ? null : fitbitClientSecret,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://www.fitbit.com/oauth2/authorize',
          tokenEndpoint: 'https://api.fitbit.com/oauth2/token',
        ),
        scopes: ['weight', 'profile'],
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
  Future<List<health.HealthDataPoint>> fetch(DateTimeRange range) async {
    if (!await isConnected()) return [];
    final token = accessToken ?? await _storage.read(key: tokenKey);
    if (token == null) return [];

    final dio = Dio();
    final headers = {'Authorization': 'Bearer $token'};
    final dateStr = range.end.toIso8601String().split('T').first;
    final db = DBService();

    try {
      final weightRes = await dio.get(
        'https://api.fitbit.com/1/user/-/body/log/weight/date/$dateStr/1d.json',
        options: Options(headers: headers),
      );
      final List<dynamic> logs = weightRes.data['weight'] ?? [];
      for (final l in logs) {
        final date = DateTime.parse('${l['date']} ${l['time']}');
        await db.insertWeightSample(
          date: date,
          value: (l['weight'] as num).toDouble(),
          bmi: (l['bmi'] as num?)?.toDouble(),
          source: 'fitbit',
        );
      }
    } on DioException catch (_) {
      // Ignore errors in this simple implementation
    }

    try {
      final fatRes = await dio.get(
        'https://api.fitbit.com/1/user/-/body/log/fat/date/$dateStr/1d.json',
        options: Options(headers: headers),
      );
      final List<dynamic> logs = fatRes.data['fat'] ?? [];
      for (final l in logs) {
        final date = DateTime.parse('${l['date']} ${l['time']}');
        await db.insertWeightSample(
          date: date,
          bodyFat: (l['fat'] as num).toDouble(),
          source: 'fitbit',
        );
      }
    } on DioException catch (_) {}

    return [];
  }

  @override
  Stream<health.HealthDataPoint> watchChanges() {
    // Fitbit does not support realtime updates in this stub
    return const Stream.empty();
  }
}
